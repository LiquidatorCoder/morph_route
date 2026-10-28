// Internal (not exported). Lets `OpenContainer` measure a tile's rect while
// ignoring the paint-only transforms that `MorphRecede` applies.
//
// `MorphRecede` wraps its `Transform`s in an outer marker and puts an inner
// marker just inside them. Both markers occupy the same untransformed box
// (the transforms are paint-only), so mapping a rect into the inner marker's
// space and then out through the outer marker's transform skips exactly the
// recede transforms and keeps every other ancestor transform.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks one side of a `MorphRecede` transform pair.
class MorphRecedeMarker extends SingleChildRenderObjectWidget {
  const MorphRecedeMarker({super.key, required this.isInner, super.child});

  /// True for the marker inside the transforms, false for the one outside.
  final bool isInner;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMorphRecedeMarker(isInner: isInner);

  @override
  void updateRenderObject(BuildContext context, RenderMorphRecedeMarker renderObject) {
    renderObject.isInner = isInner;
  }
}

class RenderMorphRecedeMarker extends RenderProxyBox {
  RenderMorphRecedeMarker({required this.isInner});

  bool isInner;
}

/// The transform from [source] to [ancestor], like `source.getTransformTo(ancestor)`
/// but skipping the transforms of every `MorphRecede` between them.
Matrix4 morphTransformTo(RenderBox source, RenderBox ancestor) {
  var transform = Matrix4.identity();
  RenderObject current = source;
  while (true) {
    final RenderMorphRecedeMarker? inner = _findMarker(current, ancestor, isInner: true);
    final RenderMorphRecedeMarker? outer = inner == null ? null : _findMarker(inner, ancestor, isInner: false);
    if (inner == null || outer == null) break;
    // source -> inner; inner and outer share a box, so continue from outer.
    transform = current.getTransformTo(inner) * transform;
    current = outer;
  }
  return current.getTransformTo(ancestor) * transform;
}

RenderMorphRecedeMarker? _findMarker(RenderObject from, RenderObject stopAt, {required bool isInner}) {
  RenderObject? node = from.parent;
  while (node != null && node != stopAt) {
    if (node is RenderMorphRecedeMarker && node.isInner == isInner) return node;
    node = node.parent;
  }
  return null;
}
