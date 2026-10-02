"""
Reference implementation of the Gödel-DPLL procedure (thesis Chapters 4-5).

Faithful to the definitions:
  - constraints over Sub(phi) ∪ {⊥,⊤}, normalised to LT / LE / EQ edges  (Def. 4.1, Rem. 4.2)
  - closure = reachability with strictness on the constraint graph         (Def. 4.6 / Prop. 4.13)
  - 17 downward + 8 upward propagation rules                                 (Tables 4.1, 4.2)
  - connective-driven Var-Trichotomy, optional binary rules                  (Def. 4.21, Rem. 4.32)
  - open = saturated + consistent + connective-decided                       (Def. 4.27/4.28)
  - extraction via SCC condensation + topological order                      (Def. 4.26)
"""
from __future__ import annotations
from dataclasses import dataclass, field
from itertools import product
from typing import Optional

# ---------------------------------------------------------------- formulas
class F:
    """Formula AST. Structural equality via (kind, children)."""
    __slots__ = ("kind", "a", "b", "name")
    def __init__(self, kind, a=None, b=None, name=None):
        self.kind, self.a, self.b, self.name = kind, a, b, name
    def key(self):
        if self.kind == "var": return ("var", self.name)
        if self.kind in ("bot", "top"): return (self.kind,)
        if self.kind == "not": return ("not", self.a.key())
        return (self.kind, self.a.key(), self.b.key())
    def __eq__(self, o): return isinstance(o, F) and self.key() == o.key()
    def __hash__(self): return hash(self.key())
    def __repr__(self):
        k = self.kind
        if k == "var": return self.name
        if k == "bot": return "⊥"
        if k == "top": return "⊤"
        if k == "not": return f"¬{self.a!r}" if self.a.kind in ("var","bot","top","not") else f"¬({self.a!r})"
        sym = {"and": "∧", "or": "∨", "imp": "→"}[k]
        return f"({self.a!r} {sym} {self.b!r})"

def V(n): return F("var", name=n)
BOT, TOP = F("bot"), F("top")
def And(a, b): return F("and", a, b)
def Or(a, b): return F("or", a, b)
def Imp(a, b): return F("imp", a, b)
def Not(a): return F("not", a)

def evaluate(f: F, v: dict) -> float:
    """Gödel semantics, Def. 2.4. Values only compared/selected, never computed."""
    k = f.kind
    if k == "var": return v[f.name]
    if k == "bot": return 0.0
    if k == "top": return 1.0
    if k == "and": return min(evaluate(f.a, v), evaluate(f.b, v))
    if k == "or": return max(evaluate(f.a, v), evaluate(f.b, v))
    if k == "imp":
        x, y = evaluate(f.a, v), evaluate(f.b, v)
        return 1.0 if x <= y else y
    if k == "not": return 1.0 if evaluate(f.a, v) == 0.0 else 0.0
    raise ValueError(k)

def variables(f: F) -> list[str]:
    out = []
    def walk(g):
        if g.kind == "var":
            if g.name not in out: out.append(g.name)
        elif g.kind == "not": walk(g.a)
        elif g.kind in ("and", "or", "imp"): walk(g.a); walk(g.b)
    walk(f); return sorted(out)

def brute_force_valid(f: F) -> tuple[bool, Optional[dict]]:
    """Oracle: Theorem 2.13 — check all evaluations into V_k = {0, 1/(k+1), ..., 1}."""
    vs = variables(f); k = len(vs)
    chain = [j / (k + 1) for j in range(k + 2)]
    for vals in product(chain, repeat=k):
        v = dict(zip(vs, vals))
        if evaluate(f, v) < 1.0: return False, v
    return True, None

# ------------------------------------------------------------- subformulas
class SubTable:
    """Sub(phi) ∪ {⊥,⊤} with ids in post-order (children before parents). ⊥ = 0, ⊤ = 1."""
    def __init__(self, phi: F):
        self.forms: list[F] = [BOT, TOP]
        self.ids: dict[F, int] = {BOT: 0, TOP: 1}
        def add(g):
            if g in self.ids: return self.ids[g]
            if g.kind == "not": add(g.a)
            elif g.kind in ("and", "or", "imp"): add(g.a); add(g.b)
            i = len(self.forms); self.forms.append(g); self.ids[g] = i; return i
        self.root = add(phi)
        self.n = len(self.forms)
        self.is_atom = [g.kind in ("var", "bot", "top") for g in self.forms]
        self.vars = [i for i, g in enumerate(self.forms) if g.kind == "var"]
        self.children = [None] * self.n
        for i, g in enumerate(self.forms):
            if g.kind == "not": self.children[i] = (self.ids[g.a],)
            elif g.kind in ("and", "or", "imp"): self.children[i] = (self.ids[g.a], self.ids[g.b])
    @property
    def compounds(self): return [i for i in range(self.n) if not self.is_atom[i]]

# -------------------------------------------------------------- constraints
LT, LE, EQ = "<", "≤", "="

class Store:
    """Constraint set Γ as a set of normalised edges + closure (reachability with strictness).
    Trail-based undo for backtracking."""
    def __init__(self, sub: SubTable):
        self.sub = sub; self.n = sub.n
        self.edges: set[tuple[int, str, int]] = set()
        self.trail: list[tuple[int, str, int]] = []
        self._weak = None; self._strict = None  # closure cache
        self.closure_computations = 0

    def mark(self): return len(self.trail)
    def undo(self, m):
        while len(self.trail) > m:
            self.edges.discard(self.trail.pop())
        self._weak = None

    def _closure(self):
        if self._weak is not None: return
        n = self.n
        weak = [[False] * n for _ in range(n)]
        strict = [[False] * n for _ in range(n)]
        for i in range(n):
            weak[i][i] = True
            weak[0][i] = True; weak[i][1] = True        # bounds: ⊥ ≤ α ≤ ⊤  (closure rule 10)
        strict[0][1] = True; weak[0][1] = True          # ⊥ < ⊤
        for (a, r, b) in self.edges:
            if r == LT: weak[a][b] = True; strict[a][b] = True
            elif r == LE: weak[a][b] = True
            else: weak[a][b] = True; weak[b][a] = True
        # Floyd–Warshall style transitive closure with strictness propagation (rules 4–8)
        for k in range(n):
            for i in range(n):
                if not weak[i][k]: continue
                wik, sik = weak[i], strict[i]
                wk, sk = weak[k], strict[k]
                s_ik = sik[k]
                for j in range(n):
                    if wk[j]:
                        wik[j] = True
                        if s_ik or sk[j]: sik[j] = True
        self._weak, self._strict = weak, strict
        self.closure_computations += 1

    # closure queries  (Γ̄)
    def le(self, a, b): self._closure(); return self._weak[a][b]
    def lt(self, a, b): self._closure(); return self._strict[a][b]
    def eq(self, a, b): self._closure(); return self._weak[a][b] and self._weak[b][a]  # antisymmetry (rule 9)
    def consistent(self): self._closure(); return not any(self._strict[i][i] for i in range(self.n))
    def holds(self, a, r, b):
        return {LT: self.lt, LE: self.le, EQ: self.eq}[r](a, b)
    def add(self, a, r, b) -> bool:
        """Add a constraint unless already in Γ̄. Returns True if something new was added."""
        if self.holds(a, r, b): return False
        e = (a, r, b); self.edges.add(e); self.trail.append(e); self._weak = None
        return True
    def decided(self, x, y): return self.lt(x, y) or self.eq(x, y) or self.lt(y, x)
    def pin(self, i) -> Optional[int]:
        """Some x ∈ Var ∪ {⊥,⊤} with v(i) = v(x) ∈ Γ̄ (Def. 4.27)."""
        if self.sub.is_atom[i]: return i
        for x in (0, 1, *self.sub.vars):
            if self.eq(i, x): return x
        return None

# ---------------------------------------------------------- propagation
def saturate(st: Store, stats) -> bool:
    """Def. 4.22. Returns False if a direct contradiction appears (Closed), True if Saturated."""
    sub = st.sub; n = st.n
    changed = True
    while changed:
        if not st.consistent(): return False
        changed = False
        def put(a, r, b):
            nonlocal changed
            if st.add(a, r, b): changed = True; stats["rule_firings"] += 1
        for psi in sub.compounds:
            g = sub.forms[psi]; ch = sub.children[psi]
            if g.kind == "and":
                a, b = ch
                put(psi, LE, a); put(psi, LE, b)                                   # Conj-Struct
                if st.eq(psi, 1): put(a, EQ, 1); put(b, EQ, 1)                       # Conj-Top
                for c in range(n):
                    if st.eq(psi, c): put(c, LE, a); put(c, LE, b)                   # Conj-Eq
                    if st.lt(c, psi): put(c, LT, a); put(c, LT, b)                   # Conj-Gt
                if st.le(a, b): put(psi, EQ, a)                                      # Conj-Up-L
                if st.le(b, a): put(psi, EQ, b)                                      # Conj-Up-R
            elif g.kind == "or":
                a, b = ch
                put(a, LE, psi); put(b, LE, psi)                                   # Disj-Struct
                if st.eq(psi, 0): put(a, EQ, 0); put(b, EQ, 0)                       # Disj-Bot
                for c in range(n):
                    if st.eq(psi, c): put(a, LE, c); put(b, LE, c)                   # Disj-Eq
                    if st.lt(psi, c): put(a, LT, c); put(b, LT, c)                   # Disj-Lt
                if st.le(a, b): put(psi, EQ, b)                                      # Disj-Up-L
                if st.le(b, a): put(psi, EQ, a)                                      # Disj-Up-R
            elif g.kind == "imp":
                a, b = ch
                if st.eq(psi, 1): put(a, LE, b)                                      # Impl-Top
                if st.eq(psi, 0): put(b, LT, a); put(b, EQ, 0)                       # Impl-Bot
                if st.lt(psi, 1): put(b, LT, a); put(psi, EQ, b)                     # Impl-NonTop
                for c in range(n):
                    if st.eq(psi, c) and st.lt(c, 1): put(b, LT, a); put(b, EQ, c)   # Impl-Eq
                    if st.lt(c, psi) and st.lt(psi, 1): put(c, LT, b)                # Impl-Gt (with side condition)
                if st.le(a, b): put(psi, EQ, 1)                                      # Impl-Up-Top
                if st.lt(b, a): put(psi, EQ, b)                                      # Impl-Up-Val
            elif g.kind == "not":
                (a,) = ch
                if st.eq(psi, 1): put(a, EQ, 0)                                      # Neg-Top
                if st.eq(psi, 0): put(0, LT, a)                                      # Neg-Bot
                if st.lt(psi, 1): put(psi, EQ, 0); put(0, LT, a)                     # Neg-NonTop
                if st.lt(0, psi): put(psi, EQ, 1); put(a, EQ, 0)                     # Neg-Pos
                if st.eq(a, 0): put(psi, EQ, 1)                                      # Neg-Up-Top
                if st.lt(0, a): put(psi, EQ, 0)                                      # Neg-Up-Bot
    return st.consistent()

# ------------------------------------------------------------ branching
def pin_pair(st: Store, psi) -> Optional[tuple[int, int]]:
    """Pins of the immediate subformulas of compound psi, or None if a child is unpinned."""
    g = st.sub.forms[psi]; ch = st.sub.children[psi]
    if g.kind == "not":
        xa = st.pin(ch[0]); return None if xa is None else (xa, 0)
    xa, xb = st.pin(ch[0]), st.pin(ch[1])
    return None if xa is None or xb is None else (xa, xb)

def ready_compound(st: Store) -> Optional[tuple[int, int, int]]:
    """Innermost compound whose children are pinned but whose pin pair is undecided (Rem. 4.32)."""
    for psi in st.sub.compounds:                      # post-order ids ⇒ innermost first
        pp = pin_pair(st, psi)
        if pp is not None and not st.decided(*pp): return (psi, *pp)
    return None

def connective_decided(st: Store) -> bool:
    for psi in st.sub.compounds:
        pp = pin_pair(st, psi)
        if pp is None or not st.decided(*pp): return False
    return True

def binary_rule(st: Store, pinning: bool, refining: bool):
    """An applicable binary connective rule (Sec. 4.4.1) honouring the guard of Def. 4.21.
    Returns (name, [branch constraints...]) or None."""
    sub = st.sub; n = st.n
    def applicable(name, branches):
        if all(any(not st.holds(*c) for c in br) for br in branches): return (name, branches)
        return None
    for psi in sub.compounds:
        g = sub.forms[psi]; ch = sub.children[psi]
        if g.kind == "and":
            a, b = ch
            if pinning and st.eq(psi, 0):
                r = applicable("Conj-Bot", [[(a, EQ, 0)], [(b, EQ, 0)]]);  
                if r: return r
            if pinning:
                for c in range(n):
                    if st.eq(psi, c):
                        r = applicable("Conj-Min", [[(a, EQ, c)], [(b, EQ, c)]])
                        if r: return r
            if refining and st.lt(psi, 1):
                r = applicable("Conj-NonTop", [[(a, LT, 1)], [(b, LT, 1)]])
                if r: return r
        elif g.kind == "or":
            a, b = ch
            if pinning and st.eq(psi, 1):
                r = applicable("Disj-Top", [[(a, EQ, 1)], [(b, EQ, 1)]])
                if r: return r
            if pinning:
                for c in range(n):
                    if st.eq(psi, c):
                        r = applicable("Disj-Max", [[(a, EQ, c)], [(b, EQ, c)]])
                        if r: return r
        elif g.kind == "imp" and refining:
            a, b = ch
            if st.le(a, b):
                r = applicable("Impl-Top-Sharp", [[(a, LT, b)], [(a, EQ, b)]])
                if r: return r
            for c in range(n):
                if st.eq(psi, c):
                    r = applicable("Impl-Eq-Branch", [[(c, EQ, 1)], [(c, LT, 1)]])
                    if r: return r
    return None

# ------------------------------------------------------------- extraction
def extract(st: Store) -> dict:
    """Def. 4.26: SCC classes (= mutual weak reachability), topological order, (j-1)/(m-1)."""
    n = st.n
    classes: list[list[int]] = []; cls_of = [-1] * n
    for i in range(n):
        if cls_of[i] >= 0: continue
        c = [j for j in range(n) if st.eq(i, j)]
        for j in c: cls_of[j] = len(classes)
        classes.append(c)
    m = len(classes)
    # topological order of the condensation (Kahn's algorithm on weak reachability)
    before = [set() for _ in range(m)]
    for i in range(n):
        for j in range(n):
            ci, cj = cls_of[i], cls_of[j]
            if ci != cj and st.le(i, j): before[cj].add(ci)
    order = []; placed = [False] * m
    while len(order) < m:
        for c in range(m):
            if not placed[c] and all(placed[p] for p in before[c]):
                order.append(c); placed[c] = True; break
    rank = {c: j for j, c in enumerate(order)}
    assert rank[cls_of[0]] == 0 and rank[cls_of[1]] == m - 1
    return {st.sub.forms[i].name: rank[cls_of[i]] / (m - 1) for i in st.sub.vars}

# -------------------------------------------------------------- procedure
@dataclass
class Node:
    label: str                      # rule / branch description
    status: str = "active"          # closed | open | active
    added: list = field(default_factory=list)
    children: list = field(default_factory=list)

@dataclass
class Result:
    valid: bool
    countermodel: Optional[dict]
    tree: Node
    nodes: int
    stats: dict

def godel_dpll(phi: F, pinning_rules=False, refining_rules=False) -> Result:
    sub = SubTable(phi); st = Store(sub)
    stats = {"rule_firings": 0, "nodes": 0, "branchings": 0, "max_depth": 0}
    st.add(sub.root, LT, 1)         # Γ0: v(φ) < 1   (v(⊥)=0, v(⊤)=1 are built into the closure)
    root = Node("Γ0 = {v(φ) < 1}")

    def solve(node: Node, depth) -> Optional[dict]:
        stats["nodes"] += 1; stats["max_depth"] = max(stats["max_depth"], depth)
        if not saturate(st, stats):
            node.status = "closed"; return None
        if connective_decided(st):
            node.status = "open"; return extract(st)
        rule = binary_rule(st, pinning_rules, refining_rules)
        if rule is None:
            r = ready_compound(st)
            assert r is not None, "no ready compound on a non-open branch (Rem. 4.30)"
            psi, x, y = r
            rule = (f"Var-Trichotomy on ({sub.forms[x]!r},{sub.forms[y]!r}) for {sub.forms[psi]!r}",
                    [[(x, LT, y)], [(x, EQ, y)], [(y, LT, x)]])
        name, branches = rule
        stats["branchings"] += 1
        node.label += f"  ⟶ {name}"
        for br in branches:
            child = Node(" , ".join(f"v({sub.forms[a]!r}) {r} v({sub.forms[b]!r})" for a, r, b in br))
            node.children.append(child)
            m = st.mark()
            for c in br: st.add(*c)
            cm = solve(child, depth + 1)
            st.undo(m)
            if cm is not None: return cm
        node.status = "closed"
        return None

    cm = solve(root, 0)
    return Result(cm is None, cm, root, stats["nodes"], stats)

# ------------------------------------------------------------------ tests
if __name__ == "__main__":
    import random, sys
    p, q, r, s = V("p"), V("q"), V("r"), V("s")
    named = {
        "prelinearity (p→q)∨(q→p)":            Or(Imp(p, q), Imp(q, p)),
        "excluded middle p∨¬p":                Or(p, Not(p)),
        "double negation ¬¬p→p":              Imp(Not(Not(p)), p),
        "∧-intro p→(q→(p∧q))":                Imp(p, Imp(q, And(p, q))),
        "¬(p∧q)→¬p":                           Imp(Not(And(p, q)), Not(p)),
        "contraposition (p→q)→(¬q→¬p)":       Imp(Imp(p, q), Imp(Not(q), Not(p))),
        "weak EM ¬p∨¬¬p":                      Or(Not(p), Not(Not(p))),
        "(p→q)∨(q→r)∨(r→p)":                   Or(Or(Imp(p, q), Imp(q, r)), Imp(r, p)),
        "Peirce ((p→q)→p)→p":                  Imp(Imp(Imp(p, q), p), p),
        "distributivity":                       Imp(And(p, Or(q, r)), Or(And(p, q), And(p, r))),
    }
    print(f"{'formula':38} {'oracle':8} {'DPLL':8} nodes  nodes(+pin)  nodes(+pin+ref)")
    for name, f in named.items():
        ov, _ = brute_force_valid(f)
        res = godel_dpll(f); res2 = godel_dpll(f, True); res3 = godel_dpll(f, True, True)
        assert res.valid == ov == res2.valid == res3.valid, name
        for rr in (res, res2, res3):
            if rr.countermodel is not None:
                assert evaluate(f, rr.countermodel) < 1.0, (name, rr.countermodel)
        print(f"{name:38} {str(ov):8} {str(res.valid):8} {res.nodes:5}  {res2.nodes:9}  {res3.nodes:9}"
              + (f"   cm={res.countermodel}" if res.countermodel else ""))

    # randomized cross-check against the oracle
    random.seed(1)
    def rand_formula(depth, vs):
        if depth == 0 or random.random() < 0.25:
            return random.choice([V(x) for x in vs] + [BOT, TOP]) if random.random() < 0.15 else V(random.choice(vs))
        k = random.choice(["and", "or", "imp", "imp", "not"])
        if k == "not": return Not(rand_formula(depth - 1, vs))
        return F(k, rand_formula(depth - 1, vs), rand_formula(depth - 1, vs))
    N = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    valid_count = 0
    for t in range(N):
        vs = ["p", "q", "r"][: random.randint(1, 3)]
        f = rand_formula(random.randint(2, 5), vs)
        ov, ocm = brute_force_valid(f)
        for flags in ((False, False), (True, False), (True, True)):
            res = godel_dpll(f, *flags)
            assert res.valid == ov, f"MISMATCH on {f!r}: oracle={ov} dpll={res.valid} flags={flags}"
            if res.countermodel is not None:
                assert evaluate(f, res.countermodel) < 1.0, f"BAD COUNTERMODEL {f!r} {res.countermodel}"
        valid_count += ov
    print(f"\nrandomized cross-check: {N} formulas, {valid_count} valid, all three strategies agree with the oracle ✓")
