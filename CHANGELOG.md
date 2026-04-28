# Changelog

## 0.1.2

- Restructured README header (centered title, tagline, and pub/platform/license badges).
- Tightened wording, added subtle section emojis, and split the long lead paragraph into a scannable feature list.
- Removed the invalid `publisher:` pubspec key (publisher attribution lives in pub.dev's admin UI, not pubspec).

## 0.1.1

- Set `publisher: hashstudios.dev` so the package is attributed to the verified publisher.
- Use absolute GitHub raw URL for the demo GIF so it renders on pub.dev.
- Update README install instructions to point at the published version.

## 0.1.0 — Initial release

First public-shaped cut. Extracted from a Flutter wallet app where the morph
shipped on the Send flow.

### `OpenContainer`

Vendored from [`package:animations`](https://github.com/flutter/packages/tree/main/packages/animations) (BSD-3) with the following modifications:

- **No more `Material`.** Replaced with `Container` + `ShapeDecoration` so we
  don't inherit the ink splash, default elevation paint, or `animationDuration`
  for color changes. Custom shadow tokens via `closedShadows` / `openShadows`.
- **Dropped** `closedElevation` / `openElevation` and the elevation tween.
- **Tunable scrim color.** `scrimColor` (default transparent) replaces the
  hard-coded `Colors.black54`.
- **Backdrop blur.** `closedBlurSigma` / `openBlurSigma` — the route inserts a
  `BackdropFilter` that lerps with the morph curve so the underlying screen
  progressively goes out of focus.
- **3D tilt.** `peakTiltY` / `peakTiltX` / `tiltPerspective` — iOS 26-style
  perspective rotation that peaks at the morph's midpoint (`sin(π·t)`) and
  is 0 at both endpoints.
- **`activeProgress`.** Static `ValueNotifier<double>` published every animation
  tick so widgets outside the route (the host shell) can react in lock-step.
- **`reverseTransitionDuration`.** Override for snappier closes than opens.
- **Pop fix.** `_takeMeasurements` no longer re-reads the source rect on pop —
  upstream walks through every transform on the underlying screen
  (`getTransformTo(navigator)`), which lands the close at a transformed rect
  if the host applies its own transform during the morph (e.g. via
  [`MorphRecede`]).

### `MorphTile`

Pressable wrapper around `OpenContainer`. Adds:

- Tap handling (so you don't have to wire `tappable: false` plumbing).
- Press feedback: subtle `AnimatedScale` (default 0.98) + optional tinted
  overlay color.
- `onTap` hook for haptics / analytics.

### `MorphRecede`

Scaffold-body wrapper that scales down (and optionally translates) as a morph
route opens, synced to `OpenContainer.activeProgress`. Pluggable progress
source via the `progress` parameter for custom integrations.

### Example

`example/` runs a minimal demo of `MorphTile` + `MorphRecede` against a
placeholder destination screen.
