// morph_route's own review policy: changed files -> required independent-review mode.
//
// Repo-specific by design (the generic runtime ships no review policy — see
// ~/.claude/harness/runtime/README.md's "Left out" section).
//
// The judgement encoded here is narrow and deliberate. This package has no network
// calls, no credential handling, no persistence, no platform-channel code, and no
// native signing configuration — so none of the usual trust-boundary categories apply.
// It has exactly one way to affect anyone outside this checkout: **being published to
// pub.dev**. That is the only thing review gates.
//
// LOCKSTEP with `.claude/docs/routing.yaml`'s `review:` block — see the same note in
// classify.mjs.

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { matchesPattern } from "./classify.mjs";

export const REVIEW_MODES = ["none", "standard", "adversarial"];
export const MODE_RANK = { none: 0, standard: 1, adversarial: 2 };

// Files whose content defines what review means here. Hashed into a review.json's
// review_policy_fingerprint.
export const REVIEW_POLICY_FILES = ["tool/harness/lib/reviewpolicy.mjs", "tool/harness/review", ".claude/docs/routing.yaml"];

// The release path, and nothing else.
export const RELEASE_PATH_PATTERNS = [
  { match: "pubspec.yaml", mode: "standard", why: "version, SDK constraints and publish metadata" },
  { match: "lib/morph_route.dart", mode: "standard", why: "a changed export is a breaking change downstream" },
  { match: "LICENSE", mode: "standard", why: "distribution terms of a published artifact" },
];

export const DEFAULT_MODE = "none";

export function maxMode(a, b) {
  return MODE_RANK[a] >= MODE_RANK[b] ? a : b;
}

/** { mode, reasons:[{path, mode, why}] } — reasons lists only files at the max mode. */
export function requiredReviewMode(changedFiles) {
  let mode = DEFAULT_MODE;
  const hits = [];
  for (const path of changedFiles) {
    for (const rule of RELEASE_PATH_PATTERNS) {
      if (matchesPattern(path, rule.match)) {
        hits.push({ path, mode: rule.mode, why: rule.why });
        mode = maxMode(mode, rule.mode);
        break;
      }
    }
  }
  return { mode, reasons: hits.filter((h) => h.mode === mode) };
}

/** sha256 over REVIEW_POLICY_FILES' bytes. A missing file hashes as absent, not zero. */
export function reviewPolicyFingerprint({ cwd, policyFiles = REVIEW_POLICY_FILES }) {
  const h = createHash("sha256");
  const sep = Buffer.from([0]);
  for (const rel of [...policyFiles].sort()) {
    h.update(rel);
    h.update(sep);
    try {
      h.update(readFileSync(join(cwd, rel)));
    } catch {
      h.update("<absent>");
    }
    h.update(sep);
  }
  return `sha256:${h.digest("hex")}`;
}
