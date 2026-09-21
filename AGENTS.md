# morph_route — agent working rules

Discovered from this repository on 2026-09-21. Everything here is observed, not
assumed: if a rule below is not backed by a file in this repo, it does not belong here.

## What this repo is

A **published Dart/Flutter package** (`morph_route`, version `0.1.2` in `pubspec.yaml`),
plus a demo app under `example/`.

- Library source: `lib/morph_route.dart` (the public export barrel) and `lib/src/*.dart`
  (`open_container.dart`, `morph_recede.dart`, `morph_tile.dart`).
- Demo app: `example/` — its own pubspec (`publish_to: 'none'`), depends on the package
  by `path: ../`. Has `android/` and `ios/` directories; no macOS/web/linux/windows.
- Lints: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`; the
  `linter.rules` block is empty (no project-specific overrides yet).
- SDK constraints (`pubspec.yaml`): Dart `^3.11.1`, Flutter `>=3.0.0`.

**The package is published to pub.dev.** `lib/`'s public surface and `pubspec.yaml`'s
version/metadata are therefore a release path, not ordinary source — see
`.claude/docs/routing.yaml`.

## Commands (the real ones)

There is **no CI workflow, no Makefile, and no script runner** in this repo. These are
the actual toolchain commands, confirmed to run here:

| Purpose | Command |
|---|---|
| Static analysis | `flutter analyze` |
| Format check | `dart format --output=none --set-exit-if-changed .` |
| Format (write) | `dart format .` |
| Tests | `flutter test` |
| Demo app analysis | `flutter analyze` from `example/` |
| Release dry-run | `flutter pub publish --dry-run` |
| Dependencies | `flutter pub get` |

Run them through `tool/harness/verify <tier>` rather than one at a time — that is what
the completion gate reads.

## Test layout

**This repo currently has no tests.** There is no top-level `test/` directory, and
`example/test/` is an empty directory. `flutter test` therefore has nothing to run; the
verifier reports the test check as `skipped` with a reason, never as `passed`. New tests
go in `test/`, mirroring `lib/src/` (`test/src/<name>_test.dart`) — the Dart convention,
since this repo has established none of its own.

## Architecture conventions

Observable, and deliberately short — this is a three-widget package, not a layered app:

- `lib/morph_route.dart` exports the public API. Anything not exported there is
  internal; adding or removing an export is a public-API change.
- `lib/src/` holds the implementation. Files there are not importable by consumers.
- `example/` must never be imported by `lib/`. The dependency runs one way only.

No state-management, DI, routing, or persistence conventions exist in this repo — do not
introduce one as a side effect of another change.

## Rules for agents

- Never edit `example/` to make a `lib/` change look like it works; fix `lib/`.
- A change to `lib/morph_route.dart`'s exports, to any exported widget's constructor
  signature, or to `pubspec.yaml`'s `version` is a **release-path** change: full tier,
  and `CHANGELOG.md` gets an entry in the same change.
- `pubspec.lock` is gitignored here and is not part of any change set.
- `demo.gif`/`demo.mov` are large binaries already committed; do not regenerate them
  unless asked.
