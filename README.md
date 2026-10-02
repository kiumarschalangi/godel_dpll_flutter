# Gödel-DPLL — Flutter implementation

Implementation of the decision procedure of the thesis *Development and Implementation of a
DPLL-Style Calculus for Propositional Gödel Logic* (Chapters 4–5), with a small UI that shows
the search tree.

## Layout

| file | contents | thesis reference |
|---|---|---|
| `lib/src/formula.dart` | formula AST, parser, Gödel semantics, brute-force oracle | Def. 2.4, Thm. 2.13 |
| `lib/src/engine.dart` | subformula table, constraint store + closure, 25 propagation rules, connective-driven branching, optional binary rules, extraction, the procedure | Ch. 4 (see comments) |
| `lib/main.dart` | Flutter UI: input, strategy toggles, result, strategy comparison, search tree | Rem. 5.20 experiment |
| `test/godel_dpll_test.dart` | named formulas, randomized oracle cross-check, height-bound check | |
| `reference/godel_dpll.py` | the Python reference implementation the Dart code was ported from (validated on 3000 random formulas) | |

## Running

```
flutter pub get
flutter test            # ~20 s: 1500 random formulas × 3 strategies against the oracle
flutter run -d chrome   # or macos / windows / linux
```

Formula syntax: variables are identifiers; `~` negation, `&` conjunction, `|` disjunction,
`->` implication (right-associative), `T` / `F` for ⊤ / ⊥. Unicode `¬ ∧ ∨ → ⊤ ⊥` also accepted.
Precedence: `~` > `&` > `|` > `->`.

## Design notes for Chapter 6

* **Closure.** `Store._closure` computes Γ̄ as reachability-with-strictness on the constraint
  graph (Floyd–Warshall relaxation). This is the O(n³) alternative of Remark 4.15; the O(n²)
  SCC test of Proposition 4.13 is used in the *extraction* (`extract`) and would be a
  drop-in replacement here if n ever mattered.
* **Pins / ready compounds.** `Store.pin`, `pinPair`, `readyCompound`, `connectiveDecided`
  implement Definition 4.27 literally; `readyCompound` returns the innermost ready compound
  because subformula ids are assigned in post-order.
* **Strategies.** `godelDpll(phi)` is the connective-driven strategy of Remark 4.32;
  `pinningRules: true` interleaves Conj-Bot/Conj-Min/Disj-Top/Disj-Max,
  `refiningRules: true` additionally Conj-NonTop/Impl-Top-Sharp/Impl-Eq-Branch. The UI's
  comparison table reports nodes / branchings / depth / firings for all three, which is the
  experiment promised in Remark 5.20.
* **Testing oracle.** `bruteForceCountermodel` enumerates all evaluations into the finite
  chain V_k (Theorem 2.13). The randomized test asserts agreement under all three
  strategies and that every extracted countermodel semantically refutes the formula.
