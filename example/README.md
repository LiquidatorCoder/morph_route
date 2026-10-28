# morph_route example

Four tiles, each showing a different side of the package:

| Tile | Widget | What it shows |
|---|---|---|
| **Send** | `MorphTile` | the signature look — fade, backdrop blur, accent scrim, 3D tilt, press tint + haptic |
| **Receive** | `MorphTile` | `ContainerTransitionType.fadeThrough` from a coloured tile, flat (no tilt) |
| **Swap** | `OpenContainer` | used directly; **Confirm swap** closes with `returnValue`, delivered to `onClosed` |
| **Borrow** | `MorphTile` | a regular `MaterialPageRoute` pushed on top of the morph route, then popped |

The whole home screen is wrapped in `MorphRecede`, so it scales back while a route is open.

```bash
flutter run
```

## End-to-end tests

`integration_test/morph_e2e_test.dart` drives every tile on a real device or simulator:
open/close latency and frame timings, return values, push-on-top, double tap, close
mid-open, rotate-while-open landing, the largest accessibility text size, and Reduce
Motion. Each animated scenario prints a `PERF {json}` line.

```bash
flutter test integration_test -d <device-id>
```
