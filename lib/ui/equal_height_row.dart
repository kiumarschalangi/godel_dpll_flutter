import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A row whose children share the full width by [flex] weights and all get the
/// height of the tallest child.
///
/// Unlike `IntrinsicHeight` + `Row(crossAxisAlignment: stretch)`, the shared
/// height comes from real layouts rather than intrinsic-size estimates, so a
/// child whose estimate is a few pixels short cannot overflow.
class EqualHeightRow extends MultiChildRenderObjectWidget {
  final List<int> flex; // one weight per child; 0 = use the child's natural width
  final double spacing;
  const EqualHeightRow({super.key, required this.flex, this.spacing = 0, required super.children})
      : assert(flex.length == children.length);

  @override
  RenderEqualHeightRow createRenderObject(BuildContext context) => RenderEqualHeightRow(flex: flex, spacing: spacing);

  @override
  void updateRenderObject(BuildContext context, RenderEqualHeightRow renderObject) => renderObject
    ..flex = flex
    ..spacing = spacing;
}

class _ParentData extends ContainerBoxParentData<RenderBox> {}

class RenderEqualHeightRow extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _ParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _ParentData> {
  RenderEqualHeightRow({required List<int> flex, required double spacing})
      : _flex = flex,
        _spacing = spacing;

  List<int> _flex;
  set flex(List<int> v) {
    if (listEquals(v, _flex)) return;
    _flex = v;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double v) {
    if (v == _spacing) return;
    _spacing = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ParentData) child.parentData = _ParentData();
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  /// Widths for the children at total width [w]: fixed (flex 0) children take
  /// their max intrinsic width, the rest is shared by flex weight.
  List<double> _widths(List<RenderBox> kids, double w) {
    final widths = List<double>.filled(kids.length, 0);
    var free = w - _spacing * math.max(0, kids.length - 1);
    var total = 0;
    for (var i = 0; i < kids.length; i++) {
      if (_flex[i] == 0) {
        widths[i] = kids[i].getMaxIntrinsicWidth(double.infinity);
        free -= widths[i];
      } else {
        total += _flex[i];
      }
    }
    for (var i = 0; i < kids.length; i++) {
      if (_flex[i] != 0) widths[i] = math.max(0, free) * _flex[i] / total;
    }
    return widths;
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, 'EqualHeightRow needs a bounded width');
    final kids = _children;
    final widths = _widths(kids, constraints.maxWidth);
    var height = 0.0;
    for (var i = 0; i < kids.length; i++) {
      kids[i].layout(BoxConstraints.tightFor(width: widths[i]), parentUsesSize: true);
      height = math.max(height, kids[i].size.height);
    }
    height = constraints.constrainHeight(height);
    var x = 0.0;
    for (var i = 0; i < kids.length; i++) {
      // A minimum (not tight) height keeps the child from becoming a relayout
      // boundary, so late size changes (e.g. web fonts loading) re-run this
      // layout instead of overflowing inside a stale height.
      kids[i].layout(BoxConstraints(minWidth: widths[i], maxWidth: widths[i], minHeight: height),
          parentUsesSize: true);
      (kids[i].parentData! as _ParentData).offset = Offset(x, 0);
      x += widths[i] + _spacing;
    }
    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final kids = _children;
    final widths = _widths(kids, constraints.maxWidth);
    var height = 0.0;
    for (var i = 0; i < kids.length; i++) {
      height = math.max(height, kids[i].getDryLayout(BoxConstraints.tightFor(width: widths[i])).height);
    }
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
