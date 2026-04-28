// Part of the morph animation system.
//
// `MorphTile` is the high-level convenience widget — it wraps [OpenContainer]
// with the press-state feedback (scale + optional tinted overlay) that 95% of
// callers want, so you don't have to wire `tappable: false` plumbing yourself.
//
// Use [OpenContainer] directly when you need finer control (e.g. opening
// programmatically via a controller, or skipping press feedback).

import 'package:flutter/material.dart';

import 'open_container.dart';

/// A pressable tile that morphs into a destination route via [OpenContainer].
///
/// Combines the [OpenContainer] morph with idiomatic press feedback (subtle
/// scale + optional color overlay), driven by an internal [GestureDetector].
/// On tap, the tile expands into a full-screen route built by [openBuilder].
///
/// All [OpenContainer] visual parameters are exposed as pass-throughs.
///
/// ### Example
///
/// ```dart
/// MorphTile(
///   transitionDuration: const Duration(milliseconds: 460),
///   reverseTransitionDuration: const Duration(milliseconds: 340),
///   closedColor: Colors.white,
///   openColor: Colors.white,
///   closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
///   closedShadows: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
///   openBlurSigma: 12,
///   peakTiltY: 0.08,
///   pressedOverlayColor: Colors.black12,
///   onTap: HapticFeedback.lightImpact,
///   closedBuilder: (context) => SizedBox(
///     height: 76,
///     child: Center(child: Text('Open')),
///   ),
///   openBuilder: (context, _) => const DetailScreen(),
/// )
/// ```
@optionalTypeArgs
class MorphTile<T extends Object?> extends StatefulWidget {
  const MorphTile({
    super.key,
    required this.closedBuilder,
    required this.openBuilder,
    // OpenContainer pass-through — see [OpenContainer] for docs.
    this.closedColor = const Color(0xFFFFFFFF),
    this.openColor = const Color(0xFFFFFFFF),
    this.middleColor,
    this.closedShape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4.0)),
    ),
    this.openShape = const RoundedRectangleBorder(),
    this.closedShadows,
    this.openShadows,
    this.scrimColor = const Color(0x00000000),
    this.closedBlurSigma = 0.0,
    this.openBlurSigma = 0.0,
    this.peakTiltY = 0.0,
    this.peakTiltX = 0.0,
    this.tiltPerspective = 0.0015,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration,
    this.transitionType = ContainerTransitionType.fade,
    this.useRootNavigator = true,
    this.routeSettings,
    this.onClosed,
    this.clipBehavior = Clip.antiAlias,
    // Press-feedback options.
    this.pressedScale = 0.98,
    this.pressedOverlayColor,
    this.pressedAnimDuration = const Duration(milliseconds: 120),
    this.onTap,
  });

  /// Builds the closed-state content. Sizing is the consumer's responsibility
  /// (typically a `SizedBox(height: ...)` wrapping the content).
  final WidgetBuilder closedBuilder;

  /// Builds the open-state route content. The provided `action` callback can
  /// be invoked to close the route programmatically.
  final OpenContainerBuilder<T> openBuilder;

  // --- OpenContainer pass-through ---
  final Color closedColor;
  final Color openColor;
  final Color? middleColor;
  final ShapeBorder closedShape;
  final ShapeBorder openShape;
  final List<BoxShadow>? closedShadows;
  final List<BoxShadow>? openShadows;
  final Color scrimColor;
  final double closedBlurSigma;
  final double openBlurSigma;
  final double peakTiltY;
  final double peakTiltX;
  final double tiltPerspective;
  final Duration transitionDuration;
  final Duration? reverseTransitionDuration;
  final ContainerTransitionType transitionType;
  final bool useRootNavigator;
  final RouteSettings? routeSettings;
  final ClosedCallback<T?>? onClosed;
  final Clip clipBehavior;

  // --- Press feedback ---

  /// Scale applied to the closed content while pressed. 1.0 disables the
  /// scale animation. Default 0.98 — the smallest scale that reads as
  /// "pressed" without being distracting.
  final double pressedScale;

  /// Color overlaid on the closed content while pressed. `null` disables the
  /// overlay. Useful for a "pressed tint" — e.g. a light gray over a white
  /// surface. Animates between transparent and this color.
  final Color? pressedOverlayColor;

  /// Duration for both scale and overlay animations on press. 100–160ms is
  /// the responsive range for button feedback.
  final Duration pressedAnimDuration;

  /// Fired the instant the user taps and the morph begins to open. Use for
  /// haptics, analytics, or any side effect that should happen alongside the
  /// route push (not after).
  final VoidCallback? onTap;

  @override
  State<MorphTile<T>> createState() => _MorphTileState<T>();
}

class _MorphTileState<T extends Object?> extends State<MorphTile<T>> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return OpenContainer<T>(
      tappable: false, // we handle tap to drive press state
      closedColor: widget.closedColor,
      openColor: widget.openColor,
      middleColor: widget.middleColor,
      closedShape: widget.closedShape,
      openShape: widget.openShape,
      closedShadows: widget.closedShadows,
      openShadows: widget.openShadows,
      scrimColor: widget.scrimColor,
      closedBlurSigma: widget.closedBlurSigma,
      openBlurSigma: widget.openBlurSigma,
      peakTiltY: widget.peakTiltY,
      peakTiltX: widget.peakTiltX,
      tiltPerspective: widget.tiltPerspective,
      transitionDuration: widget.transitionDuration,
      reverseTransitionDuration: widget.reverseTransitionDuration,
      transitionType: widget.transitionType,
      useRootNavigator: widget.useRootNavigator,
      routeSettings: widget.routeSettings,
      onClosed: widget.onClosed,
      clipBehavior: widget.clipBehavior,
      closedBuilder: (context, openContainer) {
        Widget closed = widget.closedBuilder(context);

        // Optional tint overlay on press. Sits on top of [closedColor] so the
        // resting state stays whatever the consumer specified.
        if (widget.pressedOverlayColor != null) {
          closed = AnimatedContainer(
            duration: widget.pressedAnimDuration,
            curve: Curves.easeOutCubic,
            color: _down ? widget.pressedOverlayColor : Colors.transparent,
            child: closed,
          );
        }

        // Scale-on-press. Skipped when scale == 1.0 to avoid an extra Transform.
        if (widget.pressedScale != 1.0) {
          closed = AnimatedScale(
            scale: _down ? widget.pressedScale : 1.0,
            duration: widget.pressedAnimDuration,
            curve: Curves.easeOutCubic,
            child: closed,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: () {
            widget.onTap?.call();
            openContainer();
          },
          child: closed,
        );
      },
      openBuilder: widget.openBuilder,
    );
  }
}
