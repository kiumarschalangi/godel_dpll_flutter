import 'package:flutter/material.dart';

import 'godel_dpll.dart';
import 'ui/equal_height_row.dart';
import 'ui/formula_card.dart';
import 'ui/search_tree_view.dart';
import 'ui/strategy_comparison.dart';
import 'ui/tokens.dart';
import 'ui/verdict_panel.dart';

void main() => runApp(const GodelDpllApp());

class GodelDpllApp extends StatelessWidget {
  const GodelDpllApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gödel-DPLL',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ctrl = TextEditingController(text: 'p -> (q -> (p & q))');
  bool _pinning = false;
  bool _refining = false;
  DpllResult? _result;
  List<StrategyRun>? _comparison;
  // flags of the run shown in the verdict, for the comparison's "This run" highlight
  bool _ranPinning = false;
  bool _ranRefining = false;
  String? _error;

  final _focus = FocusNode();

  /// Connective buttons: (button label, tooltip, text inserted at the cursor).
  static const _connectives = <(String, String, String)>[
    ('¬', 'negation', '¬'),
    ('∧', 'and', ' ∧ '),
    ('∨', 'or', ' ∨ '),
    ('→', 'implication', ' → '),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Inserts [s] at the cursor, replacing the selection if there is one.
  void _insert(String s) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(start, end, s),
      selection: TextSelection.collapsed(offset: start + s.length),
    );
    _focus.requestFocus();
  }

  static const _examples = <String, String>{
    'Prelinearity': '(p -> q) | (q -> p)',
    'Excluded middle': 'p | ~p',
    'Double negation': '~~p -> p',
    '∧-introduction': 'p -> (q -> (p & q))',
    'Peirce': '((p -> q) -> p) -> p',
    'Distributivity': '(p & (q | r)) -> ((p & q) | (p & r))',
  };

  void _run() {
    setState(() {
      _error = null;
      _result = null;
      _comparison = null;
    });
    Formula? phi;
    try {
      phi = Parser.parse(_ctrl.text);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final res =
        godelDpll(phi, pinningRules: _pinning, refiningRules: _refining);
    final List<StrategyRun> cmp = [
      (
        label: 'Var-Trichotomy only',
        pinning: false,
        refining: false,
        result: godelDpll(phi)
      ),
      (
        label: '+ pinning rules',
        pinning: true,
        refining: false,
        result: godelDpll(phi, pinningRules: true)
      ),
      (
        label: '+ pinning + refining',
        pinning: true,
        refining: true,
        result: godelDpll(phi, pinningRules: true, refiningRules: true)
      ),
    ];
    setState(() {
      _result = res;
      _comparison = cmp;
      _ranPinning = _pinning;
      _ranRefining = _refining;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 1000; // two columns
        final compact = width < 640; // phone: tighter padding, stacked controls
        final gap = compact ? 16.0 : 28.0;

        final formula = FormulaCard(
          controller: _ctrl,
          focusNode: _focus,
          error: _error,
          compact: compact,
          connectives: _connectives,
          examples: _examples,
          pinning: _pinning,
          refining: _refining,
          onPinning: (v) => setState(() => _pinning = v),
          onRefining: (v) => setState(() => _refining = v),
          onInsert: _insert,
          onExample: (v) => setState(() => _ctrl.text = v),
          onDecide: _run,
        );
        final verdict = VerdictPanel(result: _result, compact: compact);
        final tree = SearchTreeCard(tree: _result?.tree, compact: compact);
        final strategies = StrategyComparisonCard(
          runs: _comparison,
          ranPinning: _ranPinning,
          ranRefining: _ranRefining,
          compact: compact,
        );

        return SingleChildScrollView(
          child: Column(
            children: [
              _Header(compact: compact),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Padding(
                    padding: compact
                        ? const EdgeInsets.fromLTRB(16, 16, 16, 32)
                        : const EdgeInsets.fromLTRB(40, 32, 40, 56),
                    child: wide
                        ? Column(
                            spacing: gap,
                            children: [
                              EqualHeightRow(
                                  flex: const [2, 1],
                                  spacing: gap,
                                  children: [formula, verdict]),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: gap,
                                children: [
                                  Expanded(flex: 2, child: tree),
                                  Expanded(child: strategies),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: gap,
                            children: [formula, verdict, tree, strategies],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  final bool compact;
  const _Header({required this.compact});

  @override
  Widget build(BuildContext context) {
    final muted = AppText.sans(size: 14, color: AppColors.muted);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      // Background runs under the status bar; content stays below it.
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 40, vertical: 18),
              child: Row(
                spacing: 24,
                children: [
                  Expanded(
                      child: Row(
                    spacing: 14,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('⊨',
                            style: AppText.math(size: 26, color: Colors.white)
                                .copyWith(height: 1)),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text('Gödel-DPLL',
                                style: AppText.sans(
                                        size: 20, weight: FontWeight.w700)
                                    .copyWith(letterSpacing: -0.2)),
                            Text(
                                'Validity checking in propositional Gödel logic',
                                style: muted),
                          ],
                        ),
                      ),
                    ],
                  )),
                  if (!compact)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          Text('MSc thesis', style: muted),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                                color: AppColors.faint, shape: BoxShape.circle),
                          ),
                          Flexible(
                            child: Text('Università degli Studi di Milano',
                                style: muted, textAlign: TextAlign.end),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
