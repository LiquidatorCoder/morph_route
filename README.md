<h1 align="center">Morph Route ✨</h1>

---

<p align="center"><strong>iOS 26-inspired container morph for Flutter.</strong></p>

<p align="center">
  Tap a card, watch it expand into a full screen — and the screen behind it blur, tint, and step back like it's making room. <code>morph_route</code> is a modified <code>OpenContainer</code> plus two helper widgets that wire all of this up for you.
</p>

<p align="center">
  <a href="https://pub.dev/packages/morph_route"><img src="https://img.shields.io/pub/v/morph_route.svg?label=pub&color=blue" alt="pub package" /></a>
  <img src="https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter&logoColor=white" alt="Platform Flutter" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-BSD--3-orange.svg" alt="License BSD-3" /></a>
</p>

What you get out of the box:

- 🌫 **Backdrop blur** on the underlying screen as the morph opens.
- 🎨 **Accent scrim** — a low-alpha brand color washed over the host UI for warmth.
- 🎲 **iOS 26-style 3D tilt** that peaks at the morph's midpoint and resolves flat on both ends.
- 📦 **Scaffold-level recede** so the host UI scales down in lock-step with the morph.

<p align="center">
  <img src="https://raw.githubusercontent.com/LiquidatorCoder/morph_route/main/demo.gif" alt="morph_route demo" width="320" />
</p>

## 📦 Install

```yaml
dependencies:
  morph_route: ^0.1.2
```

Or `flutter pub add morph_route`.

## 🚀 30-second quickstart

```dart
import 'package:flutter/material.dart';
import 'package:morph_route/morph_route.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Wrap your body so it scales down behind any active morph route.
      body: MorphRecede(
        child: Center(
          // 2. Use MorphTile in place of a regular button/card.
          child: MorphTile(
            transitionDuration: const Duration(milliseconds: 460),
            reverseTransitionDuration: const Duration(milliseconds: 340),
            closedColor: Colors.white,
            openColor: Colors.white,
            closedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            closedShadows: const [
              BoxShadow(blurRadius: 4, color: Colors.black12),
            ],
            // The premium bits:
            openBlurSigma: 12,
            scrimColor: const Color(0x14D97757), // 8% coral
            peakTiltY: 0.09,                     // ~5° Y rotation mid-flight
            // Press feedback:
            pressedScale: 0.98,
            pressedOverlayColor: Colors.black12,
            onTap: () { /* haptics, analytics */ },
            closedBuilder: (context) => SizedBox(
              width: 160, height: 80,
              child: const Center(child: Text('Open')),
            ),
            openBuilder: (context, _) => const DetailScreen(),
          ),
        ),
      ),
    );
  }
}
```

## 🧩 API surface

| Widget              | What it does                                                                                                                                | When to reach for it                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **`MorphTile`**     | A pressable tile that morphs into a destination route. Wraps `OpenContainer` with idiomatic press feedback (subtle scale + tinted overlay). | 95% of callers — start here.                                                                        |
| **`MorphRecede`**   | Wraps a scaffold body so it scales down (and optionally translates) as a morph route opens, synced to `OpenContainer.activeProgress`.       | The "host UI is stepping back" feel.                                                                |
| **`OpenContainer`** | The morph route itself.                                                                                                                     | When you need finer control than `MorphTile` gives — programmatic open, custom press feedback, etc. |

Full dartdoc lives next to each class in `lib/src/`.

### 🎛 Tunable knobs you'll actually reach for

On `MorphTile` / `OpenContainer`:

- `transitionDuration` / `reverseTransitionDuration` — open vs close timing. Defaults are `300ms` / same. We recommend `460ms` open, `340ms` close (Emil Kowalski's "exits should be snappier than entrances").
- `openBlurSigma` — Gaussian blur on the underlying screen at full open. `0` = off. `8–12` reads as "out of focus" without becoming frosted glass.
- `scrimColor` — color washed over the underlying screen. Default transparent. Low-alpha brand accent (e.g. `0x14D97757`) gives a warm signal without being a tint.
- `peakTiltY` / `peakTiltX` — radians of rotation at the morph's midpoint (0 at both endpoints, peak at 0.5, follows `sin(π·t)`). `0.05–0.10 rad` ≈ 3°–6°. More than that flips.
- `tiltPerspective` — `1 / focal-length` for the 3D matrix. `0.0015` ≈ 660-unit focal length.
- `transitionType` — `fade` (default) or `fadeThrough`. `fadeThrough` cross-fades through `middleColor`.

On `MorphRecede`:

- `scaleFloor` — scale at full open (default `0.94`). `1.0` disables.
- `curve` — applied to the raw progress before scaling. Default `Curves.ease` (gentle, symmetric on close). Aggressive ease-out feels "snappy" on close.
- `progress` — override the source notifier. Defaults to `OpenContainer.activeProgress`.

## ⚠️ Caveats

- **One morph at a time.** `OpenContainer.activeProgress` is a single global `ValueNotifier<double>`, so two morphs running concurrently would clobber each other's published value. Fine for typical UX. If you need multi-morph, fork the package or pass an explicit notifier (not currently supported).
- **`BackdropFilter` is real GPU work.** The package skips the `BackdropFilter` layer entirely when `blurSigma <= 0.01`, but at non-zero values it samples and blurs the underlying tree every frame of the morph. Budget accordingly on low-end devices.
- **Reduced-motion not honored yet.** `MediaQuery.disableAnimations` isn't respected. Planned follow-up.
- **Tilt and hit-testing.** A tilted card has a tilted hit region. We don't accept input mid-morph anyway, so it's a non-issue in practice.

## Attribution

`OpenContainer` is vendored from [`package:animations`](https://github.com/flutter/packages/tree/main/packages/animations) (BSD-3, Flutter Authors), with several modifications documented in the file header. We retain the original copyright and add ours, both under BSD-3.

## License

BSD-3-Clause. See [LICENSE](LICENSE).
