/// Formulas of propositional Gödel logic (thesis Chapter 2).
///
/// Values are only ever compared and selected by the semantic clauses, never
/// computed arithmetically, so `double` is adequate for truth values.
library;

enum Kind { variable, bot, top, and, or, imp, not }

class Formula {
  final Kind kind;
  final String? name; // for variables
  final Formula? a; // left / only child
  final Formula? b; // right child

  const Formula._(this.kind, {this.name, this.a, this.b});

  factory Formula.v(String name) => Formula._(Kind.variable, name: name);
  static const bot = Formula._(Kind.bot);
  static const top = Formula._(Kind.top);
  factory Formula.and(Formula a, Formula b) => Formula._(Kind.and, a: a, b: b);
  factory Formula.or(Formula a, Formula b) => Formula._(Kind.or, a: a, b: b);
  factory Formula.imp(Formula a, Formula b) => Formula._(Kind.imp, a: a, b: b);
  factory Formula.not(Formula a) => Formula._(Kind.not, a: a);

  bool get isAtom => kind == Kind.variable || kind == Kind.bot || kind == Kind.top;
  bool get isBinary => kind == Kind.and || kind == Kind.or || kind == Kind.imp;

  // Structural equality, so that identical subformulas share one id (Sub(φ) is a set).
  @override
  bool operator ==(Object other) =>
      other is Formula && other.kind == kind && other.name == name && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(kind, name, a, b);

  @override
  String toString() {
    switch (kind) {
      case Kind.variable:
        return name!;
      case Kind.bot:
        return '⊥';
      case Kind.top:
        return '⊤';
      case Kind.not:
        final inner = a!;
        return (inner.isAtom || inner.kind == Kind.not) ? '¬$inner' : '¬($inner)';
      case Kind.and:
        return '($a ∧ $b)';
      case Kind.or:
        return '($a ∨ $b)';
      case Kind.imp:
        return '($a → $b)';
    }
  }

  /// Gödel semantics, Definition 2.4.
  double evaluate(Map<String, double> v) {
    switch (kind) {
      case Kind.variable:
        return v[name!]!;
      case Kind.bot:
        return 0.0;
      case Kind.top:
        return 1.0;
      case Kind.and:
        final x = a!.evaluate(v), y = b!.evaluate(v);
        return x < y ? x : y;
      case Kind.or:
        final x = a!.evaluate(v), y = b!.evaluate(v);
        return x > y ? x : y;
      case Kind.imp:
        final x = a!.evaluate(v), y = b!.evaluate(v);
        return x <= y ? 1.0 : y;
      case Kind.not:
        return a!.evaluate(v) == 0.0 ? 1.0 : 0.0;
    }
  }

  /// Var(φ), sorted.
  List<String> variables() {
    final out = <String>{};
    void walk(Formula f) {
      switch (f.kind) {
        case Kind.variable:
          out.add(f.name!);
        case Kind.not:
          walk(f.a!);
        case Kind.and:
        case Kind.or:
        case Kind.imp:
          walk(f.a!);
          walk(f.b!);
        default:
          break;
      }
    }

    walk(this);
    return out.toList()..sort();
  }
}

/// Brute-force oracle (Theorem 2.13): φ is valid iff it evaluates to 1 under
/// every evaluation into the finite chain V_k = {0, 1/(k+1), …, 1}.
/// Returns `null` if valid, otherwise a countermodel.
Map<String, double>? bruteForceCountermodel(Formula f) {
  final vars = f.variables();
  final k = vars.length;
  final chain = List<double>.generate(k + 2, (j) => j / (k + 1));
  final idx = List<int>.filled(k, 0);
  while (true) {
    final v = {for (var i = 0; i < k; i++) vars[i]: chain[idx[i]]};
    if (f.evaluate(v) < 1.0) return v;
    // next tuple in V_k^k
    var i = 0;
    while (i < k && ++idx[i] == chain.length) {
      idx[i] = 0;
      i++;
    }
    if (i == k) return null;
  }
}

/// Parser for the concrete syntax used by the UI and the tests.
///
///   formula := impl
///   impl    := or ('->' impl)?            right-associative
///   or      := and ('|' and)*
///   and     := not ('&' not)*
///   not     := '~' not | atom
///   atom    := identifier | 'T' | 'F' | '(' formula ')'
///
/// Accepted synonyms: ¬ ! for ~ ; ∧ for & ; ∨ for | ; → for -> ; ⊤ 1 for T ; ⊥ 0 for F.
class Parser {
  final String src;
  int pos = 0;
  Parser(this.src);

  static Formula parse(String s) {
    final p = Parser(s);
    final f = p._impl();
    p._skipWs();
    if (p.pos != s.length) p._fail('unexpected input');
    return f;
  }

  Never _fail(String msg) => throw FormatException('$msg at position $pos in "$src"');

  void _skipWs() {
    while (pos < src.length && src[pos].trim().isEmpty) {
      pos++;
    }
  }

  bool _eat(String tok) {
    _skipWs();
    if (src.startsWith(tok, pos)) {
      pos += tok.length;
      return true;
    }
    return false;
  }

  Formula _impl() {
    final left = _or();
    if (_eat('->') || _eat('→')) return Formula.imp(left, _impl());
    return left;
  }

  Formula _or() {
    var f = _and();
    while (_eat('|') || _eat('∨')) {
      f = Formula.or(f, _and());
    }
    return f;
  }

  Formula _and() {
    var f = _not();
    while (_eat('&') || _eat('∧')) {
      f = Formula.and(f, _not());
    }
    return f;
  }

  Formula _not() {
    if (_eat('~') || _eat('¬') || _eat('!')) return Formula.not(_not());
    return _atom();
  }

  Formula _atom() {
    _skipWs();
    if (pos >= src.length) _fail('unexpected end of input');
    if (_eat('(')) {
      final f = _impl();
      if (!_eat(')')) _fail("expected ')'");
      return f;
    }
    final start = pos;
    final re = RegExp(r'[A-Za-z_][A-Za-z0-9_]*|[⊤⊥01]');
    final m = re.matchAsPrefix(src, pos);
    if (m == null) _fail('expected a variable, constant or "("');
    pos = m.end;
    final tok = src.substring(start, pos);
    if (tok == 'T' || tok == '⊤' || tok == '1') return Formula.top;
    if (tok == 'F' || tok == '⊥' || tok == '0') return Formula.bot;
    return Formula.v(tok);
  }
}
