// morph_route's own file classifier: changed files -> required verification tier.
//
// Repo-specific by design. The generic harness runtime (~/.claude/harness/runtime/lib)
// deliberately does NOT ship a classifier, because "what does this change risk" is a
// question only a specific repo can answer. This one answers it for a published
// Flutter package with a demo app.
//
// LOCKSTEP: `.claude/docs/routing.yaml` is the human-readable statement of this same
// policy, and `RULES` below is its executable form. Node has no built-in YAML parser
// and this repo has no YAML dependency (it is a Dart package), so the policy is not
// parsed from the YAML at runtime. Change both files together. Both are listed in
// POLICY_FILES, so editing either one changes the verification policy fingerprint and
// invalidates every existing verify.json — which is what makes drift loud instead of
// silent.

export const TIERS = ["fast", "normal", "full"];
export const TIER_RANK = { fast: 0, normal: 1, full: 2 };

// Files whose content defines what verification means here. Hashed into every
// verify.json's verification_policy_fingerprint.
export const POLICY_FILES = [
  "tool/harness/verify",
  "tool/harness/lib/classify.mjs",
  "tool/harness/lib/reviewpolicy.mjs",
  ".claude/docs/routing.yaml",
  "analysis_options.yaml",
];

// Never part of a workspace fingerprint: task bookkeeping, managed worktrees, build
// output, and Dart/Flutter's own generated directories. `.dart_tool/` and `build/` are
// gitignored here anyway; listing them is belt-and-braces for an explicit --files scope.
export const FINGERPRINT_EXCLUDE_PREFIXES = [
  ".claude/tasks/",
  ".claude/worktrees/",
  ".dart_tool/",
  "build/",
  "example/.dart_tool/",
  "example/build/",
  "coverage/",
];

// Shared resources a worker may serialize on. No codegen (this repo has no
// build_runner) and no device pool.
export const LOCK_RESOURCES = ["dependency-resolution", "repo-format", "release"];

// First match wins, in order. Mirrors routing.yaml's `classification:` block.
export const RULES = [
  { match: "pubspec.yaml", tier: "full", why: "SDK constraints, dependencies and the published version live here" },
  { match: "CHANGELOG.md", tier: "full", why: "part of the pub.dev release artifact" },
  { match: "lib/morph_route.dart", tier: "full", why: "the public export barrel is the package's API surface" },
  { match: "lib/**", tier: "normal", why: "package implementation consumed by real apps" },
  { match: "analysis_options.yaml", tier: "normal", why: "lint config re-scopes every analyze run" },
  { match: "tool/harness/**", tier: "normal", why: "verifier and gate logic" },
  { match: ".claude/docs/routing.yaml", tier: "normal", why: "verification policy" },
  { match: "AGENTS.md", tier: "normal", why: "the rules agents work from" },
  { match: "example/**", tier: "fast", why: "demo app; not published, not depended on by lib/" },
  { match: "README.md", tier: "fast", why: "documentation" },
  { match: "docs/**", tier: "fast", why: "documentation" },
  { match: ".claude/tasks/**", tier: "fast", why: "task bookkeeping" },
  { match: "*", tier: "fast", why: "default floor — nothing here is verification-exempt" },
];

const DOUBLESTAR = "__HARNESS_DOUBLESTAR__";

/**
 * Minimal glob matcher for the forms RULES actually uses: an exact path, a `dir/**`
 * prefix, a single `*` segment wildcard, and the bare `*` catch-all. Deliberately not a
 * general glob implementation — a rule form not listed above is a policy authoring
 * mistake, and a silently-mismatching clever matcher would be worse than an obvious one.
 */
export function matchesPattern(path, pattern) {
  if (pattern === "*") return true;
  if (!pattern.includes("*")) return path === pattern;
  if (pattern.endsWith("/**")) {
    const prefix = pattern.slice(0, -2); // keep the trailing slash
    return path.startsWith(prefix);
  }
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  const body = escaped.split("**").join(DOUBLESTAR).split("*").join("[^/]*").split(DOUBLESTAR).join(".*");
  return new RegExp(`^${body}$`).test(path);
}

/** The tier one path demands, plus the rule that decided it. */
export function classifyFile(path) {
  for (const rule of RULES) {
    if (matchesPattern(path, rule.match)) return { tier: rule.tier, rule: rule.match, why: rule.why };
  }
  // Unreachable while the `*` catch-all is present. Fail closed rather than return
  // undefined if someone ever removes it.
  return { tier: "full", rule: "(no rule matched)", why: "fail closed: no classification rule matched" };
}

/**
 * The highest tier any changed file demands. An EMPTY change set returns "fast" — the
 * floor, not "full": a verify run with nothing changed has nothing to escalate for.
 * Returns { requiredTier, reasons: [{path, tier, rule, why}] } with reasons listing only
 * the files that drove the maximum.
 */
export function classifyChanges(changedFiles) {
  let requiredTier = "fast";
  const all = [];
  for (const path of changedFiles) {
    const c = classifyFile(path);
    all.push({ path, ...c });
    if (TIER_RANK[c.tier] > TIER_RANK[requiredTier]) requiredTier = c.tier;
  }
  return { requiredTier, reasons: all.filter((r) => r.tier === requiredTier) };
}
