import 'package:flutter/material.dart';

import 'equal_height_row.dart';
import 'math_text.dart';
import 'tokens.dart';

/// 01 · Formula: rendered formula, ASCII input with connective keys, examples,
/// rule-set toggles and the Decide button. Holds no state of its own.
class FormulaCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool compact;

  /// (button label, tooltip, text inserted at the cursor)
  final List<(String, String, String)> connectives;
  final Map<String, String> examples;
  final bool pinning;
  final bool refining;
  final ValueChanged<bool> onPinning;
  final ValueChanged<bool> onRefining;
  final ValueChanged<String> onInsert;
  final ValueChanged<String> onExample;
  final VoidCallback onDecide;

  const FormulaCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.compact,
    required this.connectives,
    required this.examples,
    required this.pinning,
    required this.refining,
    required this.onPinning,
    required this.onRefining,
    required this.onInsert,
    required this.onExample,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    final hint = AppText.sans(size: 13, color: AppColors.muted);
    final mono = AppText.mono(size: 13, color: AppColors.muted);
    final fieldLabel =
        AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.muted);

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      // Keep the cursor where onInsert put it when a connective button returns focus.
      selectAllOnFocus: false,
      style: AppText.mono(size: 17),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: _border(AppColors.control),
        focusedBorder: _border(AppColors.accent),
        errorBorder: _border(AppColors.open),
        focusedErrorBorder: _border(AppColors.open),
        errorText: error,
        errorMaxLines: 3,
        errorStyle: AppText.sans(size: 13, color: AppColors.open),
      ),
      onSubmitted: (_) => onDecide(),
    );

    final keys = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final (label, tip, ins) in connectives)
          Tooltip(
            message: tip,
            child: SizedBox.square(
              dimension: 52,
              child: OutlinedButton(
                onPressed: () => onInsert(ins),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.ink,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.control, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control)),
                ),
                child: Text(label, style: AppText.math(size: 22)),
              ),
            ),
          ),
      ],
    );

    final toggles = [
      RuleToggleCard(
        title: 'Pinning rules',
        rules: 'Conj-Bot · Conj-Min · Disj-Top · Disj-Max',
        value: pinning,
        onChanged: onPinning,
      ),
      RuleToggleCard(
        title: 'Refining rules',
        rules: 'Conj-NonTop · Impl-Top-Sharp · Impl-Eq-Branch',
        value: refining,
        onChanged: onRefining,
      ),
    ];

    return SurfaceCard(
      padding: EdgeInsets.all(compact ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 28,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('01 · FORMULA', style: AppText.sectionLabel()),
              Text.rich(TextSpan(style: hint, children: [
                const TextSpan(text: 'ASCII: '),
                TextSpan(text: '~ & | ->', style: mono),
                const TextSpan(text: ' · constants '),
                TextSpan(text: 'T F', style: mono),
              ])),
            ],
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final text = controller.text.trim();
              return text.isEmpty
                  ? MathText('φ',
                      size: compact ? 34 : 52, color: AppColors.faint)
                  : MathText(text, size: compact ? 34 : 52);
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text('Type a formula', style: fieldLabel),
              if (compact) ...[field, keys] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [Expanded(child: field), keys],
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text('Examples', style: fieldLabel),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in examples.entries)
                      _ExamplePill(
                        label: e.key,
                        selected: controller.text == e.value,
                        onTap: () => onExample(e.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border))),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [...toggles, _DecideButton(onDecide)],
                  )
                : EqualHeightRow(
                    flex: const [1, 1, 0],
                    spacing: 12,
                    children: [
                      ...toggles,
                      SizedBox(width: 180, child: _DecideButton(onDecide))
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

class RuleToggleCard extends StatelessWidget {
  final String title;
  final String rules;
  final bool value;
  final ValueChanged<bool> onChanged;
  const RuleToggleCard(
      {super.key,
      required this.title,
      required this.rules,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? AppColors.accentSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        side: value
            ? const BorderSide(color: AppColors.accent, width: 1.5)
            : const BorderSide(color: AppColors.control),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              spacing: 10,
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 3,
                    children: [
                      Text(title,
                          style:
                              AppText.sans(size: 15, weight: FontWeight.w600)),
                      Text(rules,
                          style:
                              AppText.sans(size: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecideButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DecideButton(this.onPressed);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: const Text('Decide'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 64),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          textStyle: AppText.sans(size: 17, weight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile)),
        ),
      ),
    );
  }
}

class _ExamplePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ExamplePill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.ink;
    final style = AppText.sans(
        size: 15,
        weight: selected ? FontWeight.w600 : FontWeight.w500,
        color: color);
    final math = AppText.math(size: 15, color: color);
    return Material(
      color: selected ? AppColors.accentSoft : AppColors.surface,
      shape: StadiumBorder(
          side: BorderSide(
              color: selected ? AppColors.accent : AppColors.control)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text.rich(TextSpan(children: [
            // connective symbols in example names (e.g. "∧-introduction") use the math font
            for (final ch in label.characters)
              TextSpan(text: ch, style: '¬∧∨→⊤⊥'.contains(ch) ? math : style),
          ])),
        ),
      ),
    );
  }
}
