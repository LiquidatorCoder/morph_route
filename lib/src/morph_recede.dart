// Part of the morph animation system.
//
// `MorphRecede` is the scaffold-level helper — wrap your top-level body with
// it to get the iOS "underlying screen recedes" feel: the content scales down
// as a [MorphTile] / [OpenContainer] route opens, and back up as it closes.
//
// Synced 1:1 to [OpenContainer.activeProgress] by default; pass a custom
// [Listenable<double>] to drive it off any other source.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'morph_recede_marker.dart';
import 'open_container.dart';
import 'reduce_motion.dart';

/// Scales [child] down (and optionally translates) as a morph route opens,
/// driven by a [Listenable<double>] (defaults to [OpenContainer.activeProgress]).
///
/// Wrap your top-level scaffold body in this:
///
/// ```dart
/// Scaffold(
///   body: MorphRecede(
///     child: BottomBar(...),
///   ),
/// )
/// ```
///
/// At rest (progress = 0): identity transform.
/// At full open (progress = 1): `child` is scaled to [scaleFloor] from
/// [alignment], optionally translated by [translateOffset].
///
/// When Reduce Motion is on (iOS: `AccessibilityFeatures.reduceMotion`; Android
/// "Remove animations": `MediaQuery.disableAnimations`), no scale or
/// translation is applied: the child stays at identity at every progress.
class MorphRecede extends StatelessWidget {
  const MorphRecede({
    super.key,
    required this.child,
    this.scaleFloor = 0.94,
    this.curve = Curves.ease,
    this.alignment = Alignment.center,
    this.translateOffset = Offset.zero,
    this.progress,
  });

  final Widget child;

  /// Scale at peak progress. 1.0 disables the scale (identity). 0.94 reads
  /// as "one card back"; 0.90 starts to feel like a stack-of-cards modal.
  final double scaleFloor;

  /// Curve applied to the raw [progress] value before scaling/translating.
  /// `Curves.ease` is symmetric on both directions and feels gentle on close.
  /// Aggressive ease-out (`easeOutCubic`) front-loads the change and makes
  /// the close snap back in the last 25% — usually undesirable.
  final Curve curve;

  /// Pivot for the scale transform. `Alignment.center` matches iOS's app-open
  /// feel; `Alignment.topCenter` would feel like a sheet sliding down.
  final Alignment alignment;

  /// Translation applied at peak progress (lerped from `Offset.zero`).
  /// Defaults to no translation — scale alone is usually enough.
  final Offset translateOffset;

  /// Progress source (0–1). Defaults to [OpenContainer.activeProgress] which
  /// is updated by the active morph route. Pass a custom [Listenable] to
  /// drive the recede off something else (e.g. a drawer's animation).
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    final source = progress ?? OpenContainer.activeProgress;
    return ValueListenableBuilder<double>(
      valueListenable: source,
      builder: (context, raw, child) {
        // Read per tick: the iOS flag is not a MediaQuery field, so it never triggers a rebuild.
        final reduceMotion = reduceMotionOf(context);
        final t = reduceMotion ? 0.0 : curve.transform(raw.clamp(0.0, 1.0));
        final scale = 1.0 - (1.0 - scaleFloor) * t;
        Widget result = Transform.scale(scale: scale, alignment: alignment, child: child);
        if (translateOffset != Offset.zero) {
          result = Transform.translate(offset: translateOffset * t, child: result);
        }
        // The outer marker pairs with the inner one below so [OpenContainer]
        // can measure its tile without this widget's transforms.
        return MorphRecedeMarker(isInner: false, child: result);
      },
      // Built once: the transformed body re-composites instead of repainting
      // each frame.
      child: MorphRecedeMarker(isInner: true, child: RepaintBoundary(child: child)),
    );
  }
}
