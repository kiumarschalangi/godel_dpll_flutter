import 'package:flutter/material.dart';

import '../godel_dpll.dart';
import 'tokens.dart';

/// One row of the comparison: the same formula run under one rule set.
typedef StrategyRun = ({String label, bool pinning, bool refining, DpllResult result});

/// 04 · Strategy comparison (Remark 5.20). The first run is the baseline the
/// firing deltas refer to; the run whose flags match [ranPinning]/[ranRefining]
/// is highlighted as "This run".
class StrategyComparisonCard extends StatelessWidget {
  final List<StrategyRun>? runs;
  final bool ranPinning;
  final bool ranRefining;
  final bool compact;
  const StrategyComparisonCard(
      {super.key, required this.runs, required this.ranPinning, required this.ranRefining, required this.compact});

  @override
  Widget build(BuildContext context) {
    final runs = this.runs;
    return SurfaceCard(
      padding: EdgeInsets.all(compact ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text('04 · STRATEGY COMPARISON', style: AppText.sectionLabel()),
              Text('Remark 5.20 · same formula, three rule sets',
                  style: AppText.sans(size: 14, color: AppColors.muted)),
            ],
          ),
          if (runs == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Press Decide to compare the three strategies.',
                  textAlign: TextAlign.center, style: AppText.sans(size: 15, color: AppColors.muted)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final (i, r) in runs.indexed)
                  _StrategyTile(
                    run: r,
                    baseline: i == 0 ? null : runs.first.result.stats.ruleFirings,
                    maxFirings: runs.map((r) => r.result.stats.ruleFirings).reduce((a, b) => a > b ? a : b),
                    thisRun: r.pinning == ranPinning && r.refining == ranRefining,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StrategyTile extends StatelessWidget {
  final StrategyRun run;
  final int? baseline; // firings of the baseline strategy; null for the baseline itself
  final int maxFirings;
  final bool thisRun;
  const _StrategyTile({required this.run, required this.baseline, required this.maxFirings, required this.thisRun});

  @override
  Widget build(BuildContext context) {
    final s = run.result.stats;
    final delta = _delta(s.ruleFirings);
    final value = AppText.sans(size: 22, weight: FontWeight.w600);
    final caption = AppText.sans(size: 12, color: AppColors.muted);
    Widget metric(int v, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [Text('$v', style: value), Text(label, style: caption)],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: thisRun ? AppColors.accentSoft : AppColors.surface,
        border: thisRun ? Border.all(color: AppColors.accent, width: 1.5) : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(child: Text(run.label, style: AppText.sans(size: 15, weight: FontWeight.w600))),
              if (delta != null) delta,
              if (thisRun)
                Text('THIS RUN',
                    style: AppText.sans(size: 12, weight: FontWeight.w600, color: AppColors.accent)
                        .copyWith(letterSpacing: 0.5)),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              metric(s.nodes, 'nodes'),
              metric(s.branchings, 'branchings'),
              metric(s.maxDepth, 'depth'),
              metric(s.ruleFirings, 'firings'),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: thisRun ? AppColors.accentTrack : AppColors.barTrack,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: maxFirings == 0 ? 0 : s.ruleFirings / maxFirings,
                heightFactor: 1,
                child: ColoredBox(color: thisRun ? AppColors.accent : AppColors.barFill),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "−50% firings" relative to the baseline strategy.
  Widget? _delta(int firings) {
    final base = baseline;
    if (base == null) return null;
    final String text;
    final Color color;
    if (firings == base) {
      (text, color) = ('same firings', AppColors.muted);
    } else if (base == 0) {
      (text, color) = ('+$firings firings', AppColors.open);
    } else {
      final pct = ((firings - base) * 100 / base).round();
      (text, color) = (pct < 0 ? '−${-pct}% firings' : '+$pct% firings', pct < 0 ? AppColors.better : AppColors.open);
    }
    return Text(text, style: AppText.sans(size: 13, weight: FontWeight.w600, color: color));
  }
}
