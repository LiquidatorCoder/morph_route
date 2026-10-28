// Internal helper — not exported from `morph_route.dart`.

import 'package:flutter/widgets.dart';

/// Whether the platform asks for reduced motion.
///
/// iOS exposes Reduce Motion only through `AccessibilityFeatures.reduceMotion`
/// (it does not set `MediaQuery.disableAnimations`); Android's "Remove
/// animations" sets `MediaQuery.disableAnimations`. Either one counts.
///
/// `MediaQueryData` has no `reduceMotion` field, so a change to the iOS flag
/// does not rebuild dependents: call this from a builder that re-runs often
/// enough (per press, per animation tick) rather than caching it.
bool reduceMotionOf(BuildContext context) {
  return (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      (View.maybeOf(context)?.platformDispatcher.accessibilityFeatures.reduceMotion ?? false);
}
