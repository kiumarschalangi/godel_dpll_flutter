import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:godel_dpll/godel_dpll.dart';

/// Checks the procedure against the brute-force oracle (Theorem 2.13) under all
/// three strategies, and verifies every extracted countermodel semantically.
void check(Formula f, {bool? expectValid}) {
  final oracle = bruteForceCountermodel(f) == null;
  if (expectValid != null) expect(oracle, expectValid, reason: 'oracle disagrees with expectation for $f');
  for (final (pin, ref) in [(false, false), (true, false), (true, true)]) {
    final res = godelDpll(f, pinningRules: pin, refiningRules: ref);
    expect(res.valid, oracle, reason: 'procedure disagrees with oracle on $f (pinning=$pin, refining=$ref)');
    if (res.countermodel != null) {
      expect(f.evaluate(res.countermodel!) < 1.0, isTrue, reason: 'bad countermodel for $f');
    }
  }
}

Formula randomFormula(Random rng, int depth, List<String> vars) {
  if (depth == 0 || rng.nextDouble() < 0.25) {
    if (rng.nextDouble() < 0.1) return rng.nextBool() ? Formula.bot : Formula.top;
    return Formula.v(vars[rng.nextInt(vars.length)]);
  }
  switch (rng.nextInt(5)) {
    case 0:
      return Formula.and(randomFormula(rng, depth - 1, vars), randomFormula(rng, depth - 1, vars));
    case 1:
      return Formula.or(randomFormula(rng, depth - 1, vars), randomFormula(rng, depth - 1, vars));
    case 2:
      return Formula.not(randomFormula(rng, depth - 1, vars));
    default:
      return Formula.imp(randomFormula(rng, depth - 1, vars), randomFormula(rng, depth - 1, vars));
  }
}

void main() {
  group('parser', () {
    test('precedence and synonyms', () {
      expect(Parser.parse('p -> q | r & ~s').toString(), '(p → (q ∨ (r ∧ ¬s)))');
      expect(Parser.parse('p → q ∨ r ∧ ¬s'), Parser.parse('p -> q | r & ~s'));
      expect(Parser.parse('a -> b -> c').toString(), '(a → (b → c))'); // right-associative
      expect(Parser.parse('T & F').toString(), '(⊤ ∧ ⊥)');
    });
  });

  group('named formulas (worked examples of Chapter 4)', () {
    final cases = <String, bool>{
      '(p -> q) | (q -> p)': true, // prelinearity, Example 4.33
      'p | ~p': false, // excluded middle, Example 4.34
      '~~p -> p': false,
      'p -> (q -> (p & q))': true, // Example 4.35
      '~(p & q) -> ~p': false,
      '(p -> q) -> (~q -> ~p)': true,
      '~p | ~~p': true, // weak excluded middle
      '(p -> q) | (q -> r) | (r -> p)': true,
      '((p -> q) -> p) -> p': false, // Peirce
      '(p & (q | r)) -> ((p & q) | (p & r))': true,
    };
    for (final e in cases.entries) {
      test(e.key, () => check(Parser.parse(e.key), expectValid: e.value));
    }
  });

  test('Example 4.35 uses exactly one branching step with three children', () {
    final res = godelDpll(Parser.parse('p -> (q -> (p & q))'));
    expect(res.valid, isTrue);
    expect(res.stats.nodes, 4);
    expect(res.tree.children.length, 3);
    expect(res.tree.children.every((c) => c.status == NodeStatus.closed), isTrue);
  });

  test('excluded middle: open at the root with v(p) = 1/2', () {
    final res = godelDpll(Parser.parse('p | ~p'));
    expect(res.valid, isFalse);
    expect(res.stats.nodes, 1);
    expect(res.countermodel, {'p': 0.5});
  });

  test('randomized cross-check against the brute-force oracle', () {
    final rng = Random(1);
    const allVars = ['p', 'q', 'r'];
    for (var t = 0; t < 1500; t++) {
      final vars = allVars.sublist(0, 1 + rng.nextInt(3));
      check(randomFormula(rng, 2 + rng.nextInt(4), vars));
    }
  });

  test('tree height respects the bound of Corollary 5.18', () {
    final rng = Random(7);
    for (var t = 0; t < 300; t++) {
      final f = randomFormula(rng, 2 + rng.nextInt(4), const ['p', 'q', 'r']);
      final res = godelDpll(f);
      final k = res.sub.vars.length;
      final c = res.sub.connectiveCount;
      final pairs = (k + 2) * (k + 1) ~/ 2;
      expect(res.stats.maxDepth <= min(c, pairs), isTrue, reason: 'height bound violated on $f');
    }
  });
}
