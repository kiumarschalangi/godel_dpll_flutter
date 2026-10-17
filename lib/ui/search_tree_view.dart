import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../godel_dpll.dart';
import 'math_text.dart';
import 'tokens.dart';

/// 03 · Search tree: the recorded [SearchNode] tree drawn top-down, with the
/// branching rule between a node and its children. Scrolls horizontally and can
/// be zoomed (zooming changes the laid-out size, so the card shrinks with it).
class SearchTreeCard extends StatefulWidget {
  final SearchNode? tree;
  final bool compact;
  const SearchTreeCard({super.key, required this.tree, required this.compact});

  @override
  State<SearchTreeCard> createState() => _SearchTreeCardState();
}

class _SearchTreeCardState extends State<SearchTreeCard> {
  final _scroll = ScrollController();
  final _treeKey = GlobalKey();
  double _zoom = 1;
  double _viewportWidth = 0;

  static const _levels = [0.25, 0.33, 0.5, 0.67, 0.8, 1.0, 1.25, 1.5];

  @override
  void didUpdateWidget(SearchTreeCard old) {
    super.didUpdateWidget(old);
    if (old.tree != widget.tree) _zoom = 1; // each new run starts at 100%
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setZoom(double z) => setState(() => _zoom = z.clamp(_levels.first, _levels.last));

  void _zoomOut() => _setZoom(_levels.lastWhere((l) => l < _zoom - 1e-6, orElse: () => _levels.first));

  void _zoomIn() => _setZoom(_levels.firstWhere((l) => l > _zoom + 1e-6, orElse: () => _levels.last));

  /// Largest zoom (at most 100%) at which the whole tree fits the card's width.
  void _fit() {
    final box = _treeKey.currentContext?.findRenderObject() as _RenderZoom?;
    final natural = box?.child?.size.width;
    if (natural == null || natural == 0 || _viewportWidth == 0) return;
    _setZoom((_viewportWidth / natural).clamp(_levels.first, 1.0));
  }

  Widget _zoomControls() {
    Widget icon(IconData i, String tip, VoidCallback? onPressed) => IconButton(
          onPressed: onPressed,
          tooltip: tip,
          icon: Icon(i, size: 18),
          color: AppColors.ink,
          disabledColor: AppColors.faint,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        );
    Widget text(String label, String tip, VoidCallback onTap) => Tooltip(
          message: tip,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Text(label, style: AppText.sans(size: 13, weight: FontWeight.w600)),
            ),
          ),
        );
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.control),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(Icons.remove_rounded, 'Zoom out', _zoom > _levels.first + 1e-6 ? _zoomOut : null),
          SizedBox(width: 52, child: text('${(_zoom * 100).round()}%', 'Reset to 100%', () => _setZoom(1))),
          icon(Icons.add_rounded, 'Zoom in', _zoom < _levels.last - 1e-6 ? _zoomIn : null),
          Container(width: 1, height: 20, color: AppColors.control),
          text('Fit', 'Fit the tree to the card width', _fit),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final legend = AppText.sans(size: 13, color: AppColors.muted);
    final tree = widget.tree;
    return SurfaceCard(
      padding: EdgeInsets.all(widget.compact ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 28,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('03 · SEARCH TREE', style: AppText.sectionLabel()),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                    Text('⊥', style: AppText.math(size: 16, color: AppColors.accent)),
                    Flexible(child: Text('closed branch', style: legend)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                    const _OpenRing(),
                    Flexible(child: Text('open branch · countermodel', style: legend)),
                  ]),
                  if (tree != null) _zoomControls(),
                ],
              ),
            ],
          ),
          if (tree == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('The search tree appears here after Decide.',
                  textAlign: TextAlign.center, style: AppText.sans(size: 15, color: AppColors.muted)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                _viewportWidth = constraints.maxWidth;
                return Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: Column(children: [
                        _Zoom(key: _treeKey, zoom: _zoom, child: _Subtree(tree, isRoot: true)),
                      ]),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Subtree extends StatelessWidget {
  final SearchNode node;
  final bool isRoot;
  const _Subtree(this.node, {this.isRoot = false});

  @override
  Widget build(BuildContext context) {
    final rule = node.rule;
    final kids = node.children;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeCard(node, isRoot: isRoot),
        if (rule != null) ...[
          const _Stem(),
          _RulePill(rule),
          if (kids.isNotEmpty) ...[
            const _Stem(),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < kids.length; i++)
                  IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 20,
                          child: CustomPaint(painter: _BracketPainter(first: i == 0, last: i == kids.length - 1)),
                        ),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: _Subtree(kids[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Draws one child's share of the connector: the horizontal bar (left half,
/// right half or full width, depending on position) and the stem down to it.
class _BracketPainter extends CustomPainter {
  final bool first;
  final bool last;
  const _BracketPainter({required this.first, required this.last});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.faint
      ..strokeWidth = 1.5;
    final cx = size.width / 2;
    const y = 0.75;
    if (!(first && last)) {
      canvas.drawLine(Offset(first ? cx : 0, y), Offset(last ? cx : size.width, y), paint);
    }
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.first != first || old.last != last;
}

class _Stem extends StatelessWidget {
  const _Stem();
  @override
  Widget build(BuildContext context) => Container(width: 1.5, height: 18, color: AppColors.faint);
}

class _RulePill extends StatelessWidget {
  final String rule;
  const _RulePill(this.rule);

  @override
  Widget build(BuildContext context) {
    // "Var-Trichotomy on (p, q) for (p ∧ q)" → bold rule name + typeset instance
    final cut = rule.indexOf(' ');
    final name = cut < 0 ? rule : rule.substring(0, cut);
    final rest = cut < 0 ? '' : rule.substring(cut + 1);
    final math = AppText.math(size: 16, color: AppColors.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: name, style: AppText.sans(size: 14, weight: FontWeight.w600)),
        if (rest.isNotEmpty) ...[
          const TextSpan(text: '  '),
          ...mathSpans(rest, math, ascii: false),
        ],
      ])),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final SearchNode node;
  final bool isRoot;
  const _NodeCard(this.node, {required this.isRoot});

  @override
  Widget build(BuildContext context) {
    final status = node.status;
    final firings = '${node.ruleFirings} firing${node.ruleFirings == 1 ? '' : 's'}';
    final small = AppText.sans(size: 13, color: AppColors.muted);
    final constraints = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in node.added) MathText(tidyConstraint(c), size: isRoot ? 26 : 20, ascii: false),
      ],
    );

    final Widget body;
    if (isRoot) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [Expanded(child: constraints), _StatusBadge(status)],
          ),
          Text('Root · ${node.ruleFirings} propagation ${node.ruleFirings == 1 ? 'firing' : 'firings'}', style: small),
        ],
      );
    } else {
      final (Widget mark, String text) = switch (status) {
        NodeStatus.closed => (
            Text('⊥', style: AppText.math(size: 16, weight: FontWeight.w600, color: AppColors.accent)),
            'closed · $firings',
          ),
        NodeStatus.open => (const _OpenRing(), 'open · countermodel · $firings'),
        NodeStatus.active => (
            Text('–', style: AppText.sans(size: 14, color: AppColors.faint)),
            'not explored',
          ),
      };
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          constraints,
          Row(spacing: 8, children: [mark, Flexible(child: Text(text, style: small))]),
        ],
      );
    }

    final side = switch (status) {
      NodeStatus.open => const BorderSide(color: AppColors.open, width: 1.5),
      _ when isRoot => const BorderSide(color: AppColors.ink, width: 1.5),
      _ => const BorderSide(color: AppColors.control),
    };
    return Opacity(
      opacity: status == NodeStatus.active ? 0.55 : 1,
      child: Container(
        width: isRoot ? 340 : 220,
        padding: isRoot ? const EdgeInsets.symmetric(horizontal: 20, vertical: 18) : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.fromBorderSide(side),
          borderRadius: BorderRadius.circular(isRoot ? 16 : AppRadii.tile),
        ),
        child: body,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final NodeStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final open = status == NodeStatus.open;
    final color = open ? AppColors.open : AppColors.accent;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (open) const _OpenRing() else Text('⊥', style: AppText.math(size: 15, color: color)),
          Text(open ? 'open' : 'closed', style: AppText.sans(size: 13, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _OpenRing extends StatelessWidget {
  const _OpenRing();
  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.open, width: 2),
        ),
      );
}

/// Scales its child by [zoom] *including* its layout size, unlike [Transform].
class _Zoom extends SingleChildRenderObjectWidget {
  final double zoom;
  const _Zoom({super.key, required this.zoom, required Widget super.child});

  @override
  _RenderZoom createRenderObject(BuildContext context) => _RenderZoom(zoom);

  @override
  void updateRenderObject(BuildContext context, _RenderZoom renderObject) => renderObject.zoom = zoom;
}

class _RenderZoom extends RenderProxyBox {
  _RenderZoom(this._zoom);

  double _zoom;
  set zoom(double v) {
    if (v == _zoom) return;
    _zoom = v;
    markNeedsLayout();
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_zoom, _zoom, 1);

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(const BoxConstraints(), parentUsesSize: true); // the tree at its natural size
    size = constraints.constrain(c.size * _zoom);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    return c == null ? constraints.smallest : constraints.constrain(c.getDryLayout(const BoxConstraints()) * _zoom);
  }

  @override
  double computeMinIntrinsicWidth(double height) => (child?.getMinIntrinsicWidth(double.infinity) ?? 0) * _zoom;
  @override
  double computeMaxIntrinsicWidth(double height) => (child?.getMaxIntrinsicWidth(double.infinity) ?? 0) * _zoom;
  @override
  double computeMinIntrinsicHeight(double width) => (child?.getMinIntrinsicHeight(double.infinity) ?? 0) * _zoom;
  @override
  double computeMaxIntrinsicHeight(double width) => (child?.getMaxIntrinsicHeight(double.infinity) ?? 0) * _zoom;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    layer =
        context.pushTransform(needsCompositing, offset, _transform, super.paint, oldLayer: layer as TransformLayer?);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => c.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_transform);
}
