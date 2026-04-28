/// `morph_route` — iOS 26-inspired container morph for Flutter.
///
/// Single import surface for the package:
///
/// ```dart
/// import 'package:morph_route/morph_route.dart';
/// ```
///
/// ## What's in here
///
/// - [OpenContainer] — the morph route. Use directly when you need finer
///   control than [MorphTile] gives. Exposes [OpenContainer.activeProgress]
///   for cross-tree reactions to the morph (used internally by [MorphRecede]).
/// - [MorphTile] — a pressable tile that morphs into a route. Wraps
///   [OpenContainer] with idiomatic press feedback (scale + tint overlay).
///   95% of callers want this.
/// - [MorphRecede] — wraps a scaffold body so it scales down as a morph route
///   opens. Pair with [MorphTile] / [OpenContainer] for the iOS app-open feel.
/// - [ContainerTransitionType] — `fade` vs `fadeThrough` for the cross-fade.
/// - Builder typedefs — [OpenContainerBuilder], [CloseContainerBuilder],
///   [CloseContainerActionCallback], [ClosedCallback].
///
/// ## Architecture notes
///
/// - [OpenContainer.activeProgress] is a global static `ValueNotifier<double>`
///   that the active morph route writes to every tick. Assumes at most one
///   morph open at a time on screen, which holds for typical UX. Multi-morph
///   is not supported; the second morph's progress would clobber the first's.
///
/// - The morph publishes a *raw* (linear, uncurved) progress value. Consumers
///   apply their own curve. This keeps the recede decoupled from the morph's
///   own curve so they can settle differently.
library;

export 'src/morph_recede.dart';
export 'src/morph_tile.dart';
export 'src/open_container.dart';
