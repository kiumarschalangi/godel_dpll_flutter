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