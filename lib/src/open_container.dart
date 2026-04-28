// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// ----------------------------------------------------------------------------
// Vendored from `package:animations/src/open_container.dart`
// (https://github.com/flutter/packages/blob/main/packages/animations/lib/src/open_container.dart)
// with the following modifications:
//
//   1. Removed `Material` widgets — replaced with `Container` + `ShapeDecoration`
//      so we don't inherit Material's ink splash, default elevation paint, or
//      `animationDuration` for color changes. The brand has its own shadow
//      tokens; Material elevation was always a fight.
//   2. Dropped `closedElevation` / `openElevation` and the elevation tween.
//      Use `closedShadows` / `openShadows` exclusively.
//   3. Made the scrim color tunable via `scrimColor` (was hard-coded to
//      `Colors.black54`). Default is transparent — depth comes from the home
//      shell receding via Transform.scale, not a heavy black wash. Also
//      added `closedBlurSigma` / `openBlurSigma` — a `BackdropFilter` with a
//      Gaussian blur that lerps with the morph curve, so the underlying
//      screen progressively goes out of focus during the transition.
//   4. Added `activeProgress` — a static `ValueNotifier<double>` published
//      every animation tick so widgets outside the route (e.g. the home shell)
//      can react in lock-step (used to drive the scale-down recede).
//   5. Added `reverseTransitionDuration` — defaults to `transitionDuration`
//      to match upstream behavior, but can be overridden so the close runs
//      faster than the open ("exits should be snappier than entrances").
//   6. Added `peakTiltY` / `peakTiltX` / `tiltPerspective` — iOS 26-style
//      3D tilt on the morphing card via `Matrix4.setEntry(3, 2, ...)` +
//      rotateY/rotateX, driven by `sin(π·t)` so the tilt peaks at midpoint
//      and is 0 at both endpoints (closed tile and full-screen).
//   7. `_takeMeasurements` no longer re-reads the source rect on pop (the
//      `remeasureSource: false` path). Upstream re-measures via
//      `getTransformTo(navigator)`, which walks through every transform in
//      the underlying screen — including the home shell's recede scale —
//      and lands the close at a transformed (wrong) rect. The push-time
//      measurement is reused. The placeholder *is* still re-established so
//      `_HideableState.isInTree` flips back to false and `buildPage` renders
//      the closed copy during the close morph.
// ----------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Signature for `action` callback function provided to [OpenContainer.openBuilder].
typedef CloseContainerActionCallback<S> = void Function({S? returnValue});

/// Signature for a function that creates a [Widget] in open state within an
/// [OpenContainer].
typedef OpenContainerBuilder<S> = Widget Function(BuildContext context, CloseContainerActionCallback<S> action);

/// Signature for a function that creates a [Widget] in closed state within an
/// [OpenContainer].
typedef CloseContainerBuilder = Widget Function(BuildContext context, VoidCallback action);

/// The [OpenContainer] widget's fade transition type.
enum ContainerTransitionType {
  /// Fades the incoming element in over the outgoing element.
  fade,

  /// Fades the outgoing element out, then fades the incoming element in once
  /// the outgoing element has completely faded out.
  fadeThrough,
}

/// Callback function which is called when the [OpenContainer] is closed.
typedef ClosedCallback<S> = void Function(S data);

/// A container that grows to fill the screen to reveal new content when tapped.
@optionalTypeArgs
class OpenContainer<T extends Object?> extends StatefulWidget {
  const OpenContainer({
    super.key,
    this.closedColor = Colors.white,
    this.openColor = Colors.white,
    this.middleColor,
    this.closedShape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4.0))),
    this.openShape = const RoundedRectangleBorder(),
    this.onClosed,
    required this.closedBuilder,
    required this.openBuilder,
    this.tappable = true,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration,
    this.transitionType = ContainerTransitionType.fade,
    this.useRootNavigator = false,
    this.routeSettings,
    this.clipBehavior = Clip.antiAlias,
    this.closedShadows,
    this.openShadows,
    this.scrimColor = Colors.transparent,
    this.closedBlurSigma = 0.0,
    this.openBlurSigma = 0.0,
    this.peakTiltY = 0.0,
    this.peakTiltX = 0.0,
    this.tiltPerspective = 0.0015,
  });

  /// Live progress (0–1) of the currently open container, published every
  /// animation tick. Stays at 0 when no container is open. Assumes at most
  /// one open container on screen at a time.
  static final ValueNotifier<double> activeProgress = ValueNotifier<double>(0.0);

  final Color closedColor;
  final Color openColor;

  /// Background color during the transition when [transitionType] is
  /// [ContainerTransitionType.fadeThrough]. Defaults to [ThemeData.canvasColor].
  final Color? middleColor;

  final ShapeBorder closedShape;
  final ShapeBorder openShape;
  final ClosedCallback<T?>? onClosed;
  final CloseContainerBuilder closedBuilder;
  final OpenContainerBuilder<T> openBuilder;
  final bool tappable;
  final Duration transitionDuration;

  /// Duration for the closing morph. Defaults to [transitionDuration] when
  /// null. Per Emil's principle "exits should be snappier than entrances",
  /// callers typically pass ~70-80% of [transitionDuration].
  final Duration? reverseTransitionDuration;

  /// Type of fade transition between closed and open content.
  final ContainerTransitionType transitionType;

  final bool useRootNavigator;
  final RouteSettings? routeSettings;
  final Clip clipBehavior;
  final List<BoxShadow>? closedShadows;
  final List<BoxShadow>? openShadows;

  /// Color washed over the screen during the transition. Defaults to
  /// transparent — the brand uses scale-down recede on the underlying screen
  /// to provide depth, not a black scrim.
  final Color scrimColor;

  /// Gaussian blur sigma applied to the underlying screen at the start of the
  /// transition. Default 0 (no blur).
  final double closedBlurSigma;

  /// Gaussian blur sigma applied to the underlying screen when the container
  /// is fully open. Lerped from [closedBlurSigma] using the morph curve.
  /// Default 0 (no blur). Values around 8–12 read as "the background is now
  /// out of focus" without becoming a frosted-glass effect.
  final double openBlurSigma;

  /// Peak Y-axis rotation (radians) applied to the morphing card mid-flight,
  /// for an iOS 26-style 3D tilt. Tilt follows a `sin(π·t)` curve — 0 at both
  /// endpoints, peak at the midpoint. Default 0 (flat morph).
  ///
  /// Values that read as "lifting": 0.05–0.10 rad (≈3°–6°). More than that
  /// crosses into "flipping."
  final double peakTiltY;

  /// Peak X-axis rotation (radians). Same `sin(π·t)` curve as [peakTiltY].
  /// Subtle values (0.01–0.03 rad / ≈1°–2°) add a touch of "leaning back"
  /// without becoming a card-flip. Default 0.
  final double peakTiltX;

  /// Perspective applied via `Matrix4.setEntry(3, 2, value)` when either tilt
  /// is non-zero. ≈ `1 / focal-length`. 0.0015 ≈ a 660-unit focal length —
  /// pronounced enough to feel 3D, subtle enough to avoid distortion.
  final double tiltPerspective;

  @override
  State<OpenContainer<T?>> createState() => OpenContainerState<T>();
}

@optionalTypeArgs
class OpenContainerState<T> extends State<OpenContainer<T?>> {
  // Hides the closed widget in the source route while the container is open
  // (a copy of it is included inside [_OpenContainerRoute] where it fades out).
  // Hiding here avoids double-shadows / double-paint.
  final GlobalKey<_HideableState> _hideableKey = GlobalKey<_HideableState>();

  // Lets us hand the closed builder's State across from the source route
  // into the route's own copy.
  final GlobalKey _closedBuilderKey = GlobalKey();

  Future<void> openContainer() async {
    final Color middleColor = widget.middleColor ?? Theme.of(context).canvasColor;
    final T? data = await Navigator.of(context, rootNavigator: widget.useRootNavigator).push(
      _OpenContainerRoute<T>(
        closedColor: widget.closedColor,
        openColor: widget.openColor,
        middleColor: middleColor,
        closedShape: widget.closedShape,
        openShape: widget.openShape,
        closedBuilder: widget.closedBuilder,
        openBuilder: widget.openBuilder,
        hideableKey: _hideableKey,
        closedBuilderKey: _closedBuilderKey,
        transitionDuration: widget.transitionDuration,
        reverseTransitionDuration: widget.reverseTransitionDuration ?? widget.transitionDuration,
        transitionType: widget.transitionType,
        useRootNavigator: widget.useRootNavigator,
        routeSettings: widget.routeSettings,
        closedShadows: widget.closedShadows,
        openShadows: widget.openShadows,
        scrimColor: widget.scrimColor,
        closedBlurSigma: widget.closedBlurSigma,
        openBlurSigma: widget.openBlurSigma,
        peakTiltY: widget.peakTiltY,
        peakTiltX: widget.peakTiltX,
        tiltPerspective: widget.tiltPerspective,
      ),
    );
    if (widget.onClosed != null) {
      widget.onClosed!(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget closed = Container(
      clipBehavior: widget.clipBehavior,
      decoration: ShapeDecoration(color: widget.closedColor, shape: widget.closedShape, shadows: widget.closedShadows),
      child: Builder(
        key: _closedBuilderKey,
        builder: (BuildContext context) {
          return widget.closedBuilder(context, openContainer);
        },
      ),
    );

    return _Hideable(
      key: _hideableKey,
      child: GestureDetector(onTap: widget.tappable ? openContainer : null, child: closed),
    );
  }
}

class _Hideable extends StatefulWidget {
  const _Hideable({super.key, required this.child});

  final Widget child;

  @override
  State<_Hideable> createState() => _HideableState();
}

class _HideableState extends State<_Hideable> {
  Size? get placeholderSize => _placeholderSize;
  Size? _placeholderSize;
  set placeholderSize(Size? value) {
    if (_placeholderSize == value) return;
    setState(() => _placeholderSize = value);
  }

  bool get isVisible => _visible;
  bool _visible = true;
  set isVisible(bool value) {
    if (_visible == value) return;
    setState(() => _visible = value);
  }

  bool get isInTree => _placeholderSize == null;

  @override
  Widget build(BuildContext context) {
    if (_placeholderSize != null) {
      return SizedBox.fromSize(size: _placeholderSize);
    }
    return Visibility(
      visible: _visible,
      maintainSize: true,
      maintainState: true,
      maintainAnimation: true,
      child: widget.child,
    );
  }
}

class _OpenContainerRoute<T> extends ModalRoute<T> {
  _OpenContainerRoute({
    required this.closedColor,
    required this.openColor,
    required this.middleColor,
    required ShapeBorder closedShape,
    required this.openShape,
    required this.closedBuilder,
    required this.openBuilder,
    required this.hideableKey,
    required this.closedBuilderKey,
    required this.transitionDuration,
    required Duration reverseTransitionDuration,
    required this.transitionType,
    required this.useRootNavigator,
    required RouteSettings? routeSettings,
    required this.closedShadows,
    required this.openShadows,
    required this.scrimColor,
    required double closedBlurSigma,
    required double openBlurSigma,
    required this.peakTiltY,
    required this.peakTiltX,
    required this.tiltPerspective,
  }) : _shadowsTween = _getShadowsTween(closedShadows, openShadows),
       _shapeTween = ShapeBorderTween(begin: closedShape, end: openShape),
       _colorTween = _getColorTween(
         transitionType: transitionType,
         closedColor: closedColor,
         openColor: openColor,
         middleColor: middleColor,
       ),
       _closedOpacityTween = _getClosedOpacityTween(transitionType),
       _openOpacityTween = _getOpenOpacityTween(transitionType),
       _scrimTween = ColorTween(begin: Colors.transparent, end: scrimColor),
       _blurTween = Tween<double>(begin: closedBlurSigma, end: openBlurSigma),
       _reverseTransitionDuration = reverseTransitionDuration,
       super(settings: routeSettings);

  static _FlippableTweenSequence<Color?> _getColorTween({
    required ContainerTransitionType transitionType,
    required Color closedColor,
    required Color openColor,
    required Color middleColor,
  }) {
    switch (transitionType) {
      case ContainerTransitionType.fade:
        // closed held → lerp closed→open → open held.
        return _FlippableTweenSequence<Color?>(<TweenSequenceItem<Color?>>[
          TweenSequenceItem<Color>(tween: ConstantTween<Color>(closedColor), weight: 1 / 5),
          TweenSequenceItem<Color?>(
            tween: ColorTween(begin: closedColor, end: openColor),
            weight: 1 / 5,
          ),
          TweenSequenceItem<Color>(tween: ConstantTween<Color>(openColor), weight: 3 / 5),
        ]);
      case ContainerTransitionType.fadeThrough:
        // closed → middle → open.
        return _FlippableTweenSequence<Color?>(<TweenSequenceItem<Color?>>[
          TweenSequenceItem<Color?>(
            tween: ColorTween(begin: closedColor, end: middleColor),
            weight: 1 / 5,
          ),
          TweenSequenceItem<Color?>(
            tween: ColorTween(begin: middleColor, end: openColor),
            weight: 4 / 5,
          ),
        ]);
    }
  }

  static _FlippableTweenSequence<double> _getClosedOpacityTween(ContainerTransitionType transitionType) {
    switch (transitionType) {
      case ContainerTransitionType.fade:
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(tween: ConstantTween<double>(1.0), weight: 1),
        ]);
      case ContainerTransitionType.fadeThrough:
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 1 / 5),
          TweenSequenceItem<double>(tween: ConstantTween<double>(0.0), weight: 4 / 5),
        ]);
    }
  }

  static _FlippableTweenSequence<double> _getOpenOpacityTween(ContainerTransitionType transitionType) {
    switch (transitionType) {
      case ContainerTransitionType.fade:
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(tween: ConstantTween<double>(0.0), weight: 1 / 5),
          TweenSequenceItem<double>(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 1 / 5),
          TweenSequenceItem<double>(tween: ConstantTween<double>(1.0), weight: 3 / 5),
        ]);
      case ContainerTransitionType.fadeThrough:
        return _FlippableTweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(tween: ConstantTween<double>(0.0), weight: 1 / 5),
          TweenSequenceItem<double>(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 4 / 5),
        ]);
    }
  }

  final Color closedColor;
  final Color openColor;
  final Color middleColor;
  final ShapeBorder openShape;
  final CloseContainerBuilder closedBuilder;
  final OpenContainerBuilder<T> openBuilder;
  final List<BoxShadow>? closedShadows;
  final List<BoxShadow>? openShadows;
  final Color scrimColor;

  // See [OpenContainerState._hideableKey].
  final GlobalKey<_HideableState> hideableKey;

  // See [OpenContainerState._closedBuilderKey].
  final GlobalKey closedBuilderKey;

  @override
  final Duration transitionDuration;
  final Duration _reverseTransitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  final ContainerTransitionType transitionType;

  final bool useRootNavigator;

  final Animatable<List<BoxShadow>?> _shadowsTween;
  final ShapeBorderTween _shapeTween;
  final _FlippableTweenSequence<double> _closedOpacityTween;
  final _FlippableTweenSequence<double> _openOpacityTween;
  final _FlippableTweenSequence<Color?> _colorTween;
  final Animatable<Color?> _scrimTween;
  final Animatable<double> _blurTween;
  final double peakTiltY;
  final double peakTiltX;
  final double tiltPerspective;

  // Key for the open-state widget — keeps its State across the layout reshape
  // at the end of the animation when we drop the scaffolding.
  final GlobalKey _openBuilderKey = GlobalKey();

  // Position and size of the closed container within the enclosing Navigator.
  final RectTween _rectTween = RectTween();

  static Animatable<List<BoxShadow>?> _getShadowsTween(List<BoxShadow>? begin, List<BoxShadow>? end) {
    if (begin == null && end == null) {
      return ConstantTween<List<BoxShadow>?>(null);
    }
    return _ShadowsTween(begin: begin, end: end);
  }

  AnimationStatus? _lastAnimationStatus;
  AnimationStatus? _currentAnimationStatus;

  void _publishProgress() {
    final a = animation;
    if (a != null) OpenContainer.activeProgress.value = a.value;
  }

  @override
  TickerFuture didPush() {
    _takeMeasurements(navigatorContext: hideableKey.currentContext!);

    animation!.addListener(_publishProgress);
    animation!.addStatusListener((AnimationStatus status) {
      _lastAnimationStatus = _currentAnimationStatus;
      _currentAnimationStatus = status;
      switch (status) {
        case AnimationStatus.dismissed:
          _toggleHideable(hide: false);
        case AnimationStatus.completed:
          _toggleHideable(hide: true);
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          break;
      }
    });

    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    // Re-measure the navigator (in case its size changed mid-route — e.g. an
    // orientation change), but DO NOT re-measure the source rect. The source
    // rect captured on push is correct; re-reading it now would walk through
    // any transforms applied to the underlying screen since push (e.g. the
    // home shell's `Transform.scale` recede driven by `activeProgress`),
    // landing the close at the *transformed* rect and then snapping when the
    // placeholder is removed.
    _takeMeasurements(navigatorContext: subtreeContext!, delayForSourceRoute: true, remeasureSource: false);
    return super.didPop(result);
  }

  @override
  void dispose() {
    animation?.removeListener(_publishProgress);
    OpenContainer.activeProgress.value = 0.0;
    if (hideableKey.currentState?.isVisible == false) {
      // Route may be disposed without dismissing its animation if it's
      // removed by the navigator — restore the source widget's visibility.
      SchedulerBinding.instance.addPostFrameCallback((Duration d) => _toggleHideable(hide: false));
    }
    super.dispose();
  }

  void _toggleHideable({required bool hide}) {
    if (hideableKey.currentState != null) {
      hideableKey.currentState!
        ..placeholderSize = null
        ..isVisible = !hide;
    }
  }

  void _takeMeasurements({
    required BuildContext navigatorContext,
    bool delayForSourceRoute = false,
    bool remeasureSource = true,
  }) {
    final navigator =
        Navigator.of(navigatorContext, rootNavigator: useRootNavigator).context.findRenderObject()! as RenderBox;
    final Size navSize = _getSize(navigator);
    _rectTween.end = Offset.zero & navSize;

    void takeMeasurementsInSourceRoute([Duration? _]) {
      if (!navigator.attached || hideableKey.currentContext == null) return;
      if (remeasureSource) {
        _rectTween.begin = _getRect(hideableKey, navigator);
      }
      // Always re-establish the placeholder so the source widget is replaced
      // by a SizedBox while the route owns the visual. This is what makes
      // `_HideableState.isInTree` return false, which is the gate buildPage
      // uses to decide whether to render the closed copy inside the route.
      // (When the route is fully open, the status listener sets
      // `placeholderSize = null` so the underlying `Visibility` takes over;
      // re-setting it on pop re-arms the closed copy for the close morph.)
      if (_rectTween.begin != null) {
        hideableKey.currentState!.placeholderSize = _rectTween.begin!.size;
      }
    }

    if (delayForSourceRoute) {
      SchedulerBinding.instance.addPostFrameCallback(takeMeasurementsInSourceRoute);
    } else {
      takeMeasurementsInSourceRoute();
    }
  }

  Size _getSize(RenderBox render) {
    assert(render.hasSize);
    return render.size;
  }

  Rect _getRect(GlobalKey key, RenderBox ancestor) {
    assert(key.currentContext != null);
    assert(ancestor.hasSize);
    final render = key.currentContext!.findRenderObject()! as RenderBox;
    assert(render.hasSize);
    return MatrixUtils.transformRect(render.getTransformTo(ancestor), Offset.zero & render.size);
  }

  bool get _transitionWasInterrupted {
    var wasInProgress = false;
    var isInProgress = false;

    switch (_currentAnimationStatus) {
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        isInProgress = false;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        isInProgress = true;
      case null:
        break;
    }
    switch (_lastAnimationStatus) {
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        wasInProgress = false;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        wasInProgress = true;
      case null:
        break;
    }
    return wasInProgress && isInProgress;
  }

  void closeContainer({T? returnValue}) {
    Navigator.of(subtreeContext!).pop(returnValue);
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    // Provide DefaultTextStyle + IconTheme that the stripped `Material` was
    // supplying. Without these, Text falls back to the framework's debug
    // style (red text, yellow double underline) — visible mid-morph.
    final ThemeData theme = Theme.of(context);
    final TextStyle textStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    return IconTheme.merge(
      data: theme.iconTheme,
      child: DefaultTextStyle(
        style: textStyle,
        child: Align(
          alignment: Alignment.topLeft,
          child: AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              if (animation.isCompleted) {
                // Final layout — drop all the morphing scaffolding.
                return SizedBox.expand(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(color: openColor, shape: openShape, shadows: openShadows),
                    child: Builder(
                      key: _openBuilderKey,
                      builder: (BuildContext context) {
                        return openBuilder(context, closeContainer);
                      },
                    ),
                  ),
                );
              }

              final Animation<double> curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
                reverseCurve: _transitionWasInterrupted ? null : Curves.fastOutSlowIn.flipped,
              );
              TweenSequence<Color?>? colorTween;
              TweenSequence<double>? closedOpacityTween, openOpacityTween;
              switch (animation.status) {
                case AnimationStatus.dismissed:
                case AnimationStatus.forward:
                  closedOpacityTween = _closedOpacityTween;
                  openOpacityTween = _openOpacityTween;
                  colorTween = _colorTween;
                case AnimationStatus.reverse:
                  if (_transitionWasInterrupted) {
                    closedOpacityTween = _closedOpacityTween;
                    openOpacityTween = _openOpacityTween;
                    colorTween = _colorTween;
                    break;
                  }
                  closedOpacityTween = _closedOpacityTween.flipped;
                  openOpacityTween = _openOpacityTween.flipped;
                  colorTween = _colorTween.flipped;
                case AnimationStatus.completed:
                  assert(false); // Unreachable.
              }
              assert(colorTween != null);
              assert(closedOpacityTween != null);
              assert(openOpacityTween != null);

              final Rect rect = _rectTween.evaluate(curvedAnimation)!;
              final ShapeBorder shape = _shapeTween.evaluate(curvedAnimation)!;
              final List<BoxShadow>? currentShadows = _shadowsTween.evaluate(curvedAnimation);

              final Widget content = Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: colorTween!.evaluate(animation),
                  shape: shape,
                  shadows: currentShadows,
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    // Closed child fading out — laid out at its original size.
                    FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: _rectTween.begin!.width,
                        height: _rectTween.begin!.height,
                        child: (hideableKey.currentState?.isInTree ?? false)
                            ? null
                            : FadeTransition(
                                opacity: closedOpacityTween!.animate(animation),
                                child: Builder(
                                  key: closedBuilderKey,
                                  builder: (BuildContext context) {
                                    // Pass a no-op for the open callback while we're
                                    // already in the process of opening.
                                    return closedBuilder(context, () {});
                                  },
                                ),
                              ),
                      ),
                    ),

                    // Open child fading in — laid out at the destination size.
                    FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: _rectTween.end!.width,
                        height: _rectTween.end!.height,
                        child: FadeTransition(
                          opacity: openOpacityTween!.animate(animation),
                          child: Builder(
                            key: _openBuilderKey,
                            builder: (BuildContext context) {
                              return openBuilder(context, closeContainer);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );

              final Color scrim = _scrimTween.evaluate(curvedAnimation) ?? Colors.transparent;
              final double blurSigma = _blurTween.evaluate(curvedAnimation);
              // BackdropFilter has a real cost; only insert it once the blur
              // is actually visible (skip it at the very start/end of the
              // animation when sigma rounds to ~0).
              final bool hasBlur = blurSigma > 0.01;

              // 3D tilt — peaks at midpoint of the morph (sin(π·t) is 0 at
              // both endpoints, 1 at 0.5). Applied symmetrically on open and
              // close. Only constructed when peak rotation is non-zero so the
              // default flat morph doesn't pay for an extra Transform layer.
              final bool hasTilt = peakTiltY != 0.0 || peakTiltX != 0.0;
              final double tiltT = hasTilt ? math.sin(curvedAnimation.value * math.pi) : 0.0;

              return SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // Blurred + tinted layer behind the morph card. The
                    // BackdropFilter samples the underlying screen; the
                    // ColoredBox child paints the scrim on top of the blur.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: hasBlur
                            ? BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                                child: ColoredBox(color: scrim),
                              )
                            : ColoredBox(color: scrim),
                      ),
                    ),
                    // Morph card.
                    Align(
                      alignment: Alignment.topLeft,
                      child: Transform.translate(
                        offset: Offset(rect.left, rect.top),
                        child: hasTilt
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, tiltPerspective)
                                  ..rotateY(tiltT * peakTiltY)
                                  ..rotateX(tiltT * peakTiltX),
                                child: SizedBox(width: rect.width, height: rect.height, child: content),
                              )
                            : SizedBox(width: rect.width, height: rect.height, child: content),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;
}

class _FlippableTweenSequence<T> extends TweenSequence<T> {
  _FlippableTweenSequence(this._items) : super(_items);

  final List<TweenSequenceItem<T>> _items;
  _FlippableTweenSequence<T>? _flipped;

  _FlippableTweenSequence<T>? get flipped {
    if (_flipped == null) {
      final newItems = <TweenSequenceItem<T>>[];
      for (var i = 0; i < _items.length; i++) {
        newItems.add(TweenSequenceItem<T>(tween: _items[i].tween, weight: _items[_items.length - 1 - i].weight));
      }
      _flipped = _FlippableTweenSequence<T>(newItems);
    }
    return _flipped;
  }
}

class _ShadowsTween extends Tween<List<BoxShadow>?> {
  _ShadowsTween({super.begin, super.end});

  @override
  List<BoxShadow>? lerp(double t) {
    return BoxShadow.lerpList(begin, end, t);
  }
}
