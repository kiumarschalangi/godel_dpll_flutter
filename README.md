# Gödel-DPLL — Flutter implementation

Implementation of the decision procedure of the thesis *Development and Implementation of a
DPLL-Style Calculus for Propositional Gödel Logic* (Chapters 4–5), with a small UI that shows
the search tree.

## Layout

| file | contents | thesis reference |
|---|---|---|
| `lib/src/formula.dart` | formula AST, parser, Gödel semantics, brute-force oracle | Def. 2.4, Thm. 2.13 |
| `lib/src/engine.dart` | subformula table, constraint store + closure, 25 propagation rules, connective-driven branching, optional binary rules, extraction, the procedure | Ch. 4 (see comments) |
| `lib/main.dart` | Flutter app: state, solver calls, responsive two-row layout | Rem. 5.20 experiment |
| `lib/ui/` | UI widgets: design tokens/theme (`tokens.dart`), math typesetting of formulas (`math_text.dart`), formula card, verdict panel, search tree, strategy comparison | |
| `test/godel_dpll_test.dart` | named formulas, randomized oracle cross-check, height-bound check | |
| `reference/godel_dpll.py` | the Python reference implementation the Dart code was ported from (validated on 3000 random formulas) | |

## Running

```
flutter pub get
flutter test            # ~20 s: 1500 random formulas × 3 strategies against the oracle
flutter run -d chrome   # or macos / windows / linux
```

The screen has a formula card (live math rendering of the ASCII input, connective keys, examples,
pinning / refining toggles, Decide), a verdict panel (valid / not valid, countermodel as exact
rationals, nodes, branching steps, propagation firings, |Sub(φ)|, k, and search depth against the
bound h = min(c(φ), (k+2)(k+1)/2)), the search tree drawn top-down (closed branches marked ⊥,
open branches in orange; zoom with − / + / Fit), and a comparison of the three strategies on the same formula. Fonts
(Instrument Sans, STIX Two Text, JetBrains Mono) come from `google_fonts` and are fetched at
runtime; offline the app falls back to system fonts. The visual spec is `design/godel-dpll-design.html`.

Formula syntax: variables are identifiers; `~` negation, `&` conjunction, `|` disjunction,
`->` implication (right-associative), `T` / `F` for ⊤ / ⊥. Unicode `¬ ∧ ∨ → ⊤ ⊥` also accepted.
Precedence: `~` > `&` > `|` > `->`.