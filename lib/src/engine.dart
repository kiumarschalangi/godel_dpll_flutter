/// The Gödel-DPLL decision procedure (thesis Chapters 4–5).
///
/// Every construct is annotated with the definition it implements:
///   SubTable                 Sub(φ) ∪ {⊥,⊤}, ids in post-order
///   Store                    constraint set Γ and its closure Γ̄     (Def. 4.1, 4.6; Prop. 4.13)
///   saturate                 17 downward + 8 upward rules            (Tables 4.1, 4.2; Def. 4.22)
///   readyCompound, pinPair   connective-driven branching             (Def. 4.27, Rem. 4.32)
///   binaryRule               optional binary connective rules        (Sec. 4.4.1, Rem. 5.20)
///   extract                  countermodel extraction                 (Def. 4.26)
///   godelDpll                the procedure Solve                     (Def. 4.25)
library;

import 'formula.dart';

// ----------------------------------------------------------------------------
// Subformula table
// ----------------------------------------------------------------------------

class SubTable {
  /// forms[0] = ⊥, forms[1] = ⊤; children always precede parents (post-order).
  final List<Formula> forms = [Formula.bot, Formula.top];
  final Map<Formula, int> ids = {Formula.bot: 0, Formula.top: 1};
  late final int root;
  late final List<int> vars; // ids of propositional variables
  late final List<List<int>> children; // immediate subformulas by id (empty for atoms)

  static const int bot = 0;
  static const int top = 1;

  SubTable(Formula phi) {
    int add(Formula g) {
      final existing = ids[g];
      if (existing != null) return existing;
      if (g.kind == Kind.not) add(g.a!);
      if (g.isBinary) {
        add(g.a!);
        add(g.b!);
      }
      final i = forms.length;
      forms.add(g);
      ids[g] = i;
      return i;
    }

    root = add(phi);
    vars = [for (var i = 0; i < forms.length; i++) if (forms[i].kind == Kind.variable) i];
    children = [
      for (final g in forms)
        if (g.kind == Kind.not)
          [ids[g.a!]!]
        else if (g.isBinary)
          [ids[g.a!]!, ids[g.b!]!]
        else
          const <int>[]
    ];
  }

  int get n => forms.length;
  bool isAtom(int i) => forms[i].isAtom;
  Iterable<int> get compounds sync* {
    for (var i = 0; i < n; i++) {
      if (!isAtom(i)) yield i;
    }
  }

  /// c(φ): number of compound subformulas (Def. 4.27).
  int get connectiveCount => compounds.length;
}

// ----------------------------------------------------------------------------
// Constraints and the store
// ----------------------------------------------------------------------------

enum Rel { lt, le, eq }

extension RelSymbol on Rel {
  String get symbol => switch (this) { Rel.lt => '<', Rel.le => '≤', Rel.eq => '=' };
}

/// A normalised constraint v(a) R v(b) (Remark 4.2: Gt is flipped Lt; absolute
/// constraints are relations against ⊥ = 0 and ⊤ = 1).
typedef Constraint = (int a, Rel r, int b);

class Store {
  final SubTable sub;
  final int n;
  final Set<Constraint> edges = {};
  final List<Constraint> _trail = [];

  List<List<bool>>? _weak; // closure cache: v(i) ≤ v(j) ∈ Γ̄
  List<List<bool>>? _strict; // v(i) < v(j) ∈ Γ̄
  int closureComputations = 0;

  Store(this.sub) : n = sub.n;

  int mark() => _trail.length;

  void undo(int m) {
    while (_trail.length > m) {
      edges.remove(_trail.removeLast());
    }
    _weak = null;
  }

  /// Closure Γ̄ (Def. 4.6) as reachability with strictness on the constraint
  /// graph (Def. 4.12). Floyd–Warshall relaxation; n is small in practice.
  /// (Remark 4.15 notes the O(n²) SCC alternative.)
  void _closure() {
    if (_weak != null) return;
    final weak = List.generate(n, (_) => List<bool>.filled(n, false));
    final strict = List.generate(n, (_) => List<bool>.filled(n, false));
    for (var i = 0; i < n; i++) {
      weak[i][i] = true;
      weak[SubTable.bot][i] = true; // bounds  ⊥ ≤ α ≤ ⊤   (closure rule 10)
      weak[i][SubTable.top] = true;
    }
    strict[SubTable.bot][SubTable.top] = true; // ⊥ < ⊤
    for (final (a, r, b) in edges) {
      switch (r) {
        case Rel.lt:
          weak[a][b] = true;
          strict[a][b] = true;
        case Rel.le:
          weak[a][b] = true;
        case Rel.eq:
          weak[a][b] = true;
          weak[b][a] = true;
      }
    }
    // transitivity in all mixtures of <, ≤, = (closure rules 4–8)
    for (var k = 0; k < n; k++) {
      for (var i = 0; i < n; i++) {
        if (!weak[i][k]) continue;
        final sik = strict[i][k];
        for (var j = 0; j < n; j++) {
          if (weak[k][j]) {
            weak[i][j] = true;
            if (sik || strict[k][j]) strict[i][j] = true;
          }
        }
      }
    }
    _weak = weak;
    _strict = strict;
    closureComputations++;
  }

  bool le(int a, int b) {
    _closure();
    return _weak![a][b];
  }

  bool lt(int a, int b) {
    _closure();
    return _strict![a][b];
  }

  /// Antisymmetry (closure rule 9): mutual ≤ is equality.
  bool eq(int a, int b) {
    _closure();
    return _weak![a][b] && _weak![b][a];
  }

  bool holds(Constraint c) {
    final (a, r, b) = c;
    return switch (r) { Rel.lt => lt(a, b), Rel.le => le(a, b), Rel.eq => eq(a, b) };
  }

  /// Consistency (Prop. 4.13): no direct contradiction v(α) < v(α).
  bool get consistent {
    _closure();
    for (var i = 0; i < n; i++) {
      if (_strict![i][i]) return false;
    }
    return true;
  }

  /// Adds a constraint unless already in Γ̄. Returns true if something new entered.
  bool add(Constraint c) {
    if (holds(c)) return false;
    edges.add(c);
    _trail.add(c);
    _weak = null;
    return true;
  }

  bool decided(int x, int y) => lt(x, y) || eq(x, y) || lt(y, x);

  /// A pin of i: some x ∈ Var ∪ {⊥,⊤} with v(i) = v(x) ∈ Γ̄ (Def. 4.27), or null.
  int? pin(int i) {
    if (sub.isAtom(i)) return i;
    if (eq(i, SubTable.bot)) return SubTable.bot;
    if (eq(i, SubTable.top)) return SubTable.top;
    for (final x in sub.vars) {
      if (eq(i, x)) return x;
    }
    return null;
  }

  String describe(Constraint c) {
    final (a, r, b) = c;
    return 'v(${sub.forms[a]}) ${r.symbol} v(${sub.forms[b]})';
  }
}

// ----------------------------------------------------------------------------
// Saturation: the 25 propagation rules
// ----------------------------------------------------------------------------

class Stats {
  int ruleFirings = 0;
  int nodes = 0;
  int branchings = 0;
  int maxDepth = 0;
}

/// Def. 4.22. Returns false if a direct contradiction appears (Closed).
bool saturate(Store st, Stats stats) {
  final sub = st.sub;
  final n = st.n;
  const bot = SubTable.bot, top = SubTable.top;
  var changed = true;
  while (changed) {
    if (!st.consistent) return false;
    changed = false;
    void put(int a, Rel r, int b) {
      if (st.add((a, r, b))) {
        changed = true;
        stats.ruleFirings++;
      }
    }

    for (final psi in sub.compounds) {
      final g = sub.forms[psi];
      final ch = sub.children[psi];
      switch (g.kind) {
        case Kind.and:
          final a = ch[0], b = ch[1];
          put(psi, Rel.le, a); put(psi, Rel.le, b); //                          Conj-Struct
          if (st.eq(psi, top)) { put(a, Rel.eq, top); put(b, Rel.eq, top); } // Conj-Top
          for (var c = 0; c < n; c++) {
            if (st.eq(psi, c)) { put(c, Rel.le, a); put(c, Rel.le, b); } //     Conj-Eq
            if (st.lt(c, psi)) { put(c, Rel.lt, a); put(c, Rel.lt, b); } //     Conj-Gt
          }
          if (st.le(a, b)) put(psi, Rel.eq, a); //                              Conj-Up-L
          if (st.le(b, a)) put(psi, Rel.eq, b); //                              Conj-Up-R
        case Kind.or:
          final a = ch[0], b = ch[1];
          put(a, Rel.le, psi); put(b, Rel.le, psi); //                          Disj-Struct
          if (st.eq(psi, bot)) { put(a, Rel.eq, bot); put(b, Rel.eq, bot); } // Disj-Bot
          for (var c = 0; c < n; c++) {
            if (st.eq(psi, c)) { put(a, Rel.le, c); put(b, Rel.le, c); } //     Disj-Eq
            if (st.lt(psi, c)) { put(a, Rel.lt, c); put(b, Rel.lt, c); } //     Disj-Lt
          }
          if (st.le(a, b)) put(psi, Rel.eq, b); //                              Disj-Up-L
          if (st.le(b, a)) put(psi, Rel.eq, a); //                              Disj-Up-R
        case Kind.imp:
          final a = ch[0], b = ch[1];
          if (st.eq(psi, top)) put(a, Rel.le, b); //                            Impl-Top
          if (st.eq(psi, bot)) { put(b, Rel.lt, a); put(b, Rel.eq, bot); } //   Impl-Bot
          if (st.lt(psi, top)) { put(b, Rel.lt, a); put(psi, Rel.eq, b); } //   Impl-NonTop
          for (var c = 0; c < n; c++) {
            if (st.eq(psi, c) && st.lt(c, top)) { put(b, Rel.lt, a); put(b, Rel.eq, c); } // Impl-Eq
            if (st.lt(c, psi) && st.lt(psi, top)) put(c, Rel.lt, b); //         Impl-Gt (side condition!)
          }
          if (st.le(a, b)) put(psi, Rel.eq, top); //                            Impl-Up-Top
          if (st.lt(b, a)) put(psi, Rel.eq, b); //                              Impl-Up-Val
        case Kind.not:
          final a = ch[0];
          if (st.eq(psi, top)) put(a, Rel.eq, bot); //                          Neg-Top
          if (st.eq(psi, bot)) put(bot, Rel.lt, a); //                          Neg-Bot
          if (st.lt(psi, top)) { put(psi, Rel.eq, bot); put(bot, Rel.lt, a); } // Neg-NonTop
          if (st.lt(bot, psi)) { put(psi, Rel.eq, top); put(a, Rel.eq, bot); } // Neg-Pos
          if (st.eq(a, bot)) put(psi, Rel.eq, top); //                          Neg-Up-Top
          if (st.lt(bot, a)) put(psi, Rel.eq, bot); //                          Neg-Up-Bot
        default:
          break;
      }
    }
  }
  return st.consistent;
}

// ----------------------------------------------------------------------------
// Branching
// ----------------------------------------------------------------------------

/// Pins of the immediate subformulas of compound psi (Def. 4.27), or null if
/// some child is not yet pinned. For ¬α the pair is (x_α, ⊥).
(int, int)? pinPair(Store st, int psi) {
  final ch = st.sub.children[psi];
  if (st.sub.forms[psi].kind == Kind.not) {
    final xa = st.pin(ch[0]);
    return xa == null ? null : (xa, SubTable.bot);
  }
  final xa = st.pin(ch[0]), xb = st.pin(ch[1]);
  return (xa == null || xb == null) ? null : (xa, xb);
}

/// Innermost ready compound: children pinned, pin pair undecided (Rem. 4.32).
(int psi, int x, int y)? readyCompound(Store st) {
  for (final psi in st.sub.compounds) {
    final pp = pinPair(st, psi);
    if (pp != null && !st.decided(pp.$1, pp.$2)) return (psi, pp.$1, pp.$2);
  }
  return null;
}

/// Every connective resolved (Def. 4.27) — the open-branch criterion (Def. 4.28).
bool connectiveDecided(Store st) {
  for (final psi in st.sub.compounds) {
    final pp = pinPair(st, psi);
    if (pp == null || !st.decided(pp.$1, pp.$2)) return false;
  }
  return true;
}

/// A branching rule instance: a name and the constraint sets of its branches.
typedef BranchRule = (String name, List<List<Constraint>> branches);

/// Binary connective rules of Sec. 4.4.1, subject to the applicability guard of
/// Def. 4.21 (every branch must add something not already in Γ̄).
/// `pinning`  = Conj-Bot, Conj-Min, Disj-Top, Disj-Max  (resolve a connective)
/// `refining` = Conj-NonTop, Impl-Top-Sharp, Impl-Eq-Branch (refine a comparison)
BranchRule? binaryRule(Store st, {required bool pinning, required bool refining}) {
  final sub = st.sub;
  final n = st.n;
  const bot = SubTable.bot, top = SubTable.top;
  BranchRule? applicable(String name, List<List<Constraint>> branches) {
    for (final br in branches) {
      if (!br.any((c) => !st.holds(c))) return null; // a vacuous branch ⇒ not applicable
    }
    return (name, branches);
  }

  for (final psi in sub.compounds) {
    final g = sub.forms[psi];
    final ch = sub.children[psi];
    BranchRule? r;
    switch (g.kind) {
      case Kind.and:
        final a = ch[0], b = ch[1];
        if (pinning && st.eq(psi, bot)) {
          r = applicable('Conj-Bot', [[(a, Rel.eq, bot)], [(b, Rel.eq, bot)]]);
          if (r != null) return r;
        }
        if (pinning) {
          for (var c = 0; c < n; c++) {
            if (st.eq(psi, c)) {
              r = applicable('Conj-Min', [[(a, Rel.eq, c)], [(b, Rel.eq, c)]]);
              if (r != null) return r;
            }
          }
        }
        if (refining && st.lt(psi, top)) {
          r = applicable('Conj-NonTop', [[(a, Rel.lt, top)], [(b, Rel.lt, top)]]);
          if (r != null) return r;
        }
      case Kind.or:
        final a = ch[0], b = ch[1];
        if (pinning && st.eq(psi, top)) {
          r = applicable('Disj-Top', [[(a, Rel.eq, top)], [(b, Rel.eq, top)]]);
          if (r != null) return r;
        }
        if (pinning) {
          for (var c = 0; c < n; c++) {
            if (st.eq(psi, c)) {
              r = applicable('Disj-Max', [[(a, Rel.eq, c)], [(b, Rel.eq, c)]]);
              if (r != null) return r;
            }
          }
        }
      case Kind.imp:
        if (!refining) break;
        final a = ch[0], b = ch[1];
        if (st.le(a, b)) {
          r = applicable('Impl-Top-Sharp', [[(a, Rel.lt, b)], [(a, Rel.eq, b)]]);
          if (r != null) return r;
        }
        for (var c = 0; c < n; c++) {
          if (st.eq(psi, c)) {
            r = applicable('Impl-Eq-Branch', [[(c, Rel.eq, top)], [(c, Rel.lt, top)]]);
            if (r != null) return r;
          }
        }
      default:
        break;
    }
  }
  return null;
}

// ----------------------------------------------------------------------------
// Countermodel extraction
// ----------------------------------------------------------------------------

/// Def. 4.26: equality classes (mutual ≤ in Γ̄), a topological order of the
/// condensation, and evenly spaced values with ⊥ ↦ 0, ⊤ ↦ 1.
Map<String, double> extract(Store st) {
  final n = st.n;
  final classOf = List<int>.filled(n, -1);
  var m = 0;
  for (var i = 0; i < n; i++) {
    if (classOf[i] >= 0) continue;
    for (var j = 0; j < n; j++) {
      if (st.eq(i, j)) classOf[j] = m;
    }
    m++;
  }
  // Kahn's algorithm on the condensation.
  final before = List.generate(m, (_) => <int>{});
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      if (classOf[i] != classOf[j] && st.le(i, j)) before[classOf[j]].add(classOf[i]);
    }
  }
  final rank = List<int>.filled(m, -1);
  for (var placed = 0; placed < m; placed++) {
    for (var c = 0; c < m; c++) {
      if (rank[c] < 0 && before[c].every((p) => rank[p] >= 0)) {
        rank[c] = placed;
        break;
      }
    }
  }
  assert(rank[classOf[SubTable.bot]] == 0 && rank[classOf[SubTable.top]] == m - 1);
  return {
    for (final x in st.sub.vars) st.sub.forms[x].name!: rank[classOf[x]] / (m - 1),
  };
}

// ----------------------------------------------------------------------------
// The procedure, recording the search tree for display
// ----------------------------------------------------------------------------

enum NodeStatus { active, closed, open }

class SearchNode {
  /// Constraints this branch added to its parent's set (empty at the root).
  final List<String> added;
  String? rule; // branching rule applied at this node, if any
  NodeStatus status = NodeStatus.active;
  final List<SearchNode> children = [];
  int ruleFirings = 0; // propagation firings during this node's saturation
  SearchNode(this.added);
}

class DpllResult {
  final bool valid;
  final Map<String, double>? countermodel;
  final SearchNode tree;
  final Stats stats;
  final SubTable sub;
  DpllResult(this.valid, this.countermodel, this.tree, this.stats, this.sub);
}

/// GödelDPLL(φ), Definition 4.25, with the connective-driven strategy of
/// Remark 4.32 and optional interleaving of the binary rules (Remark 5.20).
DpllResult godelDpll(Formula phi, {bool pinningRules = false, bool refiningRules = false}) {
  final sub = SubTable(phi);
  final st = Store(sub);
  final stats = Stats();
  st.add((sub.root, Rel.lt, SubTable.top)); // Γ0 = { v(φ) < 1 }; v(⊥)=0, v(⊤)=1 live in the closure
  final root = SearchNode(['v(φ) < 1']);

  Map<String, double>? solve(SearchNode node, int depth) {
    stats.nodes++;
    if (depth > stats.maxDepth) stats.maxDepth = depth;
    final before = stats.ruleFirings;
    final sat = saturate(st, stats);
    node.ruleFirings = stats.ruleFirings - before;
    if (!sat) {
      node.status = NodeStatus.closed;
      return null;
    }
    if (connectiveDecided(st)) {
      node.status = NodeStatus.open;
      return extract(st);
    }
    var rule = binaryRule(st, pinning: pinningRules, refining: refiningRules);
    if (rule == null) {
      final r = readyCompound(st);
      if (r == null) throw StateError('no ready compound on a non-open branch (Remark 4.30)');
      final (psi, x, y) = r;
      rule = (
        'Var-Trichotomy on (${sub.forms[x]}, ${sub.forms[y]}) for ${sub.forms[psi]}',
        [[(x, Rel.lt, y)], [(x, Rel.eq, y)], [(y, Rel.lt, x)]],
      );
    }
    final (name, branches) = rule!;
    node.rule = name;
    stats.branchings++;
    for (final br in branches) {
      final child = SearchNode(br.map(st.describe).toList());
      node.children.add(child);
      final m = st.mark();
      for (final c in br) {
        st.add(c);
      }
      final cm = solve(child, depth + 1);
      st.undo(m);
      if (cm != null) return cm;
    }
    node.status = NodeStatus.closed;
    return null;
  }

  final cm = solve(root, 0);
  return DpllResult(cm == null, cm, root, stats, sub);
}
