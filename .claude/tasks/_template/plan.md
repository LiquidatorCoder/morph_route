# Plan: <task-id>

## Change, file by file

| File | Change | Why |
|---|---|---|
| `lib/src/<file>.dart` | | |

## Public API impact

<Does `lib/morph_route.dart`'s export list change? Does any exported widget's
constructor signature change? If yes: this is a release-path change — full tier, and
CHANGELOG.md gets an entry in the same commit.>

## Verification

<Which tier, and which checks in it actually exercise this change. If a check cannot
exercise it — e.g. this repo currently has no tests — say so here rather than letting
a green run imply coverage that does not exist.>

## Risks

<What could break for a downstream consumer of the published package.>
