import 'package:flutter/material.dart';

import '../godel_dpll.dart';
import 'equal_height_row.dart';
import 'math_text.dart';
import 'tokens.dart';

/// 02 · Verdict: dark panel with the result of the last run, its statistics and
/// the search depth against the height bound h = min(c(φ), (k+2)(k+1)/2).
class VerdictPanel extends StatelessWidget {
  final DpllResult? result;
  final bool compact;
  const VerdictPanel({super.key, required this.result, required this.compact});

  @override
  Widget build(BuildContext context) {
    final res = result;
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 32),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          Text('02 · VERDICT', style: AppText.sectionLabel(color: AppColors.panelMuted)),
          if (res == null) ..._placeholder() else ..._verdict(res),
        ],
      ),
    );
  }

  List<Widget> _placeholder() => [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text('—', style: AppText.sans(size: 56, weight: FontWeight.w700, color: AppColors.panelTrack)),
            Text('Type a formula and press Decide to check its validity.',
                style: AppText.sans(size: 16, color: AppColors.panelBody).copyWith(height: 1.5)),
          ],
        ),
        const _StatsGrid(values: ['–', '–', '–', '–', '–', '–']),
      ];

  List<Widget> _verdict(DpllResult res) {
    final s = res.stats;
    final k = res.sub.vars.length;
    final c = res.sub.connectiveCount;
    final pairs = (k + 2) * (k + 1) ~/ 2;
    final h = c < pairs ? c : pairs;
    final cm = res.countermodel;
    final tone = res.valid ? AppColors.valid : AppColors.notValid;
    final body = AppText.sans(size: 16, color: AppColors.panelBody).copyWith(height: 1.5);
    final bodyMath = AppText.math(size: 17, color: AppColors.panelBody);
    final math = AppText.math(size: 22, color: AppColors.panelMath);

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 14,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                child: Icon(res.valid ? Icons.check_rounded : Icons.close_rounded,
                    size: 26, color: res.valid ? AppColors.validInk : AppColors.notValidInk),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    res.valid ? 'Valid' : 'Not valid',
                    style: AppText.sans(size: 56, weight: FontWeight.w700, color: tone)
                        .copyWith(letterSpacing: -1.7, height: 1),
                  ),
                ),
              ),
            ],
          ),
          Text.rich(TextSpan(style: math, children: [
            TextSpan(text: res.valid ? '⊨' : '⊭'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.translate(
                offset: const Offset(1, 5),
                child: Text('G', style: AppText.math(size: 14, color: AppColors.panelMath)),
              ),
            ),
            const TextSpan(text: '  '),
            TextSpan(text: 'φ', style: math.copyWith(fontStyle: FontStyle.italic)),
          ])),
          Text.rich(TextSpan(style: body, children: [
            TextSpan(text: res.valid ? 'Every branch from ' : 'An open branch from '),
            ...mathSpans('v(φ) < 1', bodyMath, ascii: false),
            TextSpan(
                text: res.valid
                    ? ' closes, so no Gödel valuation falsifies the formula.'
                    : ' survives; its countermodel falsifies the formula:'),
          ])),
          if (cm != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in cm.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.panelCell,
                      border: Border.all(color: AppColors.panelLine),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: MathText('${e.key} = ${formatRational(e.value)}',
                        size: 18, color: AppColors.notValid, ascii: false),
                  ),
              ],
            ),
        ],
      ),
      _StatsGrid(values: [
        '${s.nodes}',
        '${s.branchings}',
        '${s.ruleFirings}',
        '${res.sub.n - 2}',
        '$k',
        '$pairs',
      ]),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Depth ${s.maxDepth} of bound $h',
                  style: AppText.sans(size: 14, weight: FontWeight.w600, color: Colors.white)),
              MathText('h = min(c(φ) = $c, pairs = $pairs) = $h', size: 15, color: AppColors.panelMuted, ascii: false),
            ],
          ),
          _DepthMeter(depth: s.maxDepth, bound: h, fill: tone),
        ],
      ),
    ];
  }
}

class _StatsGrid extends StatelessWidget {
  /// nodes, branching steps, firings, |Sub(φ)|, k, variable pairs
  final List<String> values;
  const _StatsGrid({required this.values});

  @override
  Widget build(BuildContext context) {
    final label = AppText.sans(size: 13, color: AppColors.panelMuted);
    final mathLabel = AppText.math(size: 15, color: AppColors.panelMuted);
    final big = AppText.sans(size: 32, weight: FontWeight.w600, color: Colors.white).copyWith(letterSpacing: -0.6);
    final bigMath = AppText.math(size: 30, color: Colors.white);
    Widget cell(String value, TextStyle valueStyle, Widget caption) => Container(
          color: AppColors.panelCell,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [Text(value, style: valueStyle), caption],
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: Container(
        color: AppColors.panelLine,
        padding: const EdgeInsets.all(1),
        child: Column(
          spacing: 1,
          children: [
            EqualHeightRow(
              flex: const [1, 1, 1],
              spacing: 1,
              children: [
                cell(values[0], big, Text('Nodes', style: label)),
                cell(values[1], big, Text('Branching steps', style: label)),
                cell(values[2], big, Text('Propagation firings', style: label)),
              ],
            ),
            EqualHeightRow(
              flex: const [1, 1, 1],
              spacing: 1,
              children: [
                cell(values[3], bigMath, Text.rich(TextSpan(children: mathSpans('|Sub(φ)|', mathLabel, ascii: false)))),
                cell(
                  values[4],
                  bigMath,
                  Text.rich(TextSpan(style: mathLabel, children: [
                    TextSpan(text: 'k', style: mathLabel.copyWith(fontStyle: FontStyle.italic)),
                    const TextSpan(text: ' · variables'),
                  ])),
                ),
                cell(values[5], bigMath, Text('Variable pairs', style: label)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One segment per unit of the bound h, filled up to the search depth; a plain
/// bar when h is too large for segments to stay readable.
class _DepthMeter extends StatelessWidget {
  final int depth;
  final int bound;
  final Color fill;
  const _DepthMeter({required this.depth, required this.bound, required this.fill});

  static const _maxSegments = 20;

  @override
  Widget build(BuildContext context) {
    Widget bar(Color c) =>
        Container(height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
    if (bound > 0 && bound <= _maxSegments) {
      return Row(
        spacing: 6,
        children: [for (var i = 0; i < bound; i++) Expanded(child: bar(i < depth ? fill : AppColors.panelTrack))],
      );
    }
    final frac = bound == 0 ? 0.0 : (depth / bound).clamp(0.0, 1.0);
    return Stack(children: [
      bar(AppColors.panelTrack),
      FractionallySizedBox(widthFactor: frac, child: bar(fill)),
    ]);
  }
}

/// Exact rational labels for the values produced by extraction.
String formatRational(double x) {
  for (var d = 1; d <= 12; d++) {
    for (var num = 0; num <= d; num++) {
      if ((x - num / d).abs() < 1e-9) return d == 1 ? '$num' : '$num/$d';
    }
  }
  return x.toStringAsFixed(3);
}
