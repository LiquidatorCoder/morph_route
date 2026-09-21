# Verification — morph_route

`tool/harness/verify <fast|normal|full>` is the only thing that decides whether this
repo's changes pass. An agent's judgement is not verification; the exit code and the
`verify.json` it writes are.

The checks below are this repository's actual commands (there is no CI workflow and no
Makefile here to inherit them from) — see `AGENTS.md` for where each one came from.

## Tiers

| Check | Command | fast | normal | full |
|---|---|:--:|:--:|:--:|
| `format` | `dart format --output=none --set-exit-if-changed .` | ✓ | ✓ | ✓ |
| `analyze` | `flutter analyze` | ✓ | ✓ | ✓ |
| `test` | `flutter test` | | ✓ | ✓ |
| `example_analyze` | `flutter analyze` in `example/` | | ✓ | ✓ |
| `publish_dry_run` | `flutter pub publish --dry-run` | | | ✓ |

- **fast** — static only, a couple of seconds. The working loop.
- **normal** — adds execution and the demo app. The default for any change under `lib/`.
- **full** — adds the pub.dev release gate. Required for `pubspec.yaml`,
  `CHANGELOG.md`, and `lib/morph_route.dart` (the public export barrel).

Which tier a change *requires* is not a matter of opinion: `tool/harness/lib/classify.mjs`
maps the changed-file set to a tier, and the completion gate takes the highest of (the
task's declared tier, the classifier's tier, the tier the verify run itself recorded).
Declaring `fast` on a change to `pubspec.yaml` does not make it a fast change.

## Known state of this repo (2026-09-21, at bootstrap)

Recorded here because a check that is green for the wrong reason is worse than a red one:

- **`format` currently fails.** `lib/src/open_container.dart` and
  `example/lib/main.dart` are not `dart format`-clean. This is pre-existing repository
  state and was deliberately left untouched by the harness bootstrap. `dart format .`
  fixes it; that is the repo owner's call, not the harness's.
- **`test` has nothing to run.** There is no top-level `test/` directory and
  `example/test/` is empty. The verifier reports `test` as **`skipped`** with a reason
  and lists it in `unsatisfied_required` — so `normal` and `full` come back
  `incomplete`, never `passed`. A required check that could not run is never success.

## Result semantics

`verify.json` (schema 3) carries, at minimum:

| Field | Meaning |
|---|---|
| `result` | `passed` only if every check in the tier actually ran and actually exited zero. `failed` if any check failed. `incomplete` if a required check could not run. |
| `completion_tier_satisfied` | `true` only when `result` is `passed`. |
| `unsatisfied_required` | `[{check, reason}]` — required checks that did not run. Non-empty blocks completion. |
| `required_tier` | What the changed files demand, per the classifier. |
| `tier` | What this run actually executed. |
| `workspace_fingerprint` | Content hash of the changed-file set. Changes after a run make the artifact stale. |
| `verification_policy_fingerprint` | Content hash of the verifier's own files (see `policy_files` in `.claude/docs/routing.yaml`). Editing the verifier invalidates every prior artifact. |
| `checks[]` | Per-check `{name, status, required, exit_code, duration_ms, detail}`. |

There is no code path in `tool/harness/verify` that writes `"status": "passed"` for a
command it did not run. Do not add one.

## Scoping

```
tool/harness/verify normal                       # default: diff against main
tool/harness/verify normal --base <ref>          # diff against an explicit ref
tool/harness/verify fast  --files a.dart b.dart  # an explicit file set
tool/harness/verify fast  --json-out .claude/tasks/<id>/verify.json
```

The scope is recorded in `verify.json`'s `verification_scope` and the gate recomputes
the fingerprint against that same scope — so a `--base`-scoped artifact stays valid
instead of going permanently stale against a differently-scoped default diff.

## Independent review

Optional here, and required only for the release path (`pubspec.yaml`,
`lib/morph_route.dart`, `LICENSE`) — see `review:` in `.claude/docs/routing.yaml`.
`tool/harness/review` drives it. If the Codex CLI is unavailable or not authenticated,
it writes an `incomplete` review artifact with the reason; it never writes a passing
one it did not obtain.
