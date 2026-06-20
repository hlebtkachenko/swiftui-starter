# CI, branch protection, and releases

## Gates

All run on GitHub-hosted runners. A pull request must pass the required ones before it can merge to `main`.

| Workflow | Job (required check) | What it does |
|----------|----------------------|--------------|
| `gitleaks.yml` | Scan for secrets | Secret scan over full history, redacted output. |
| `guard.yml` | Block secrets and private files | Secrets/private files, private keys, oversized files, personal data, dead links, duplicate docs, and ownership-map coverage. See [security.md](security.md). |
| `pr-check.yml` | PR title and description | PR title must be Conventional Commits; description must be non-trivial. |
| `codeql.yml` | Analyze Swift | Swift security + quality scanning on macOS. A required merge gate, despite being inherently ~17 min. See the trigger matrix below. |
| `release-check.yml` | (tag push) | On a `v*` tag: validates `vX.Y.Z` and a matching `CHANGELOG.md` entry. |

CodeQL is a required check: now that the app has real Swift code, security scanning gates the merge path even though its traced build is slow (~17 min). It also runs on push to `main`, weekly, and on demand. To revert it to a scheduled-only scan, drop the `pull_request` trigger and the `code_scanning` ruleset rule.

## Trigger matrix (what runs, when, and on what)

Fast Ubuntu checks gate every PR in seconds; the one slow macOS job (CodeQL) also gates, at a ~17-min cost accepted for security coverage.

| Workflow | PR | Push to `main` | Schedule / tag / manual | Runner | Cost | Notes |
|----------|----|----|----|--------|------|-------|
| `gitleaks` | yes | yes | - | ubuntu | ~10 s | `push` scoped to `main` so a same-repo PR branch is scanned once (via `pull_request`), not twice. |
| `guard` | yes | yes | - | ubuntu | ~15 s | Same `push`/`pull_request` dedup as gitleaks. |
| `pr-check` | yes | - | - | ubuntu | ~5 s | PR-only by design; nothing to check on a raw push. |
| `codeql` | yes | yes | weekly (Mon 04:23 UTC) + `workflow_dispatch` | **macOS** | ~17 min | Inherently slow and uncacheable (see below) but a required gate; runs on PR, push to `main`, weekly, and on demand. |
| `release-check` | - | - | on `v*` tag | ubuntu | ~10 s | Validates tag + changelog, publishes the release. |

Dependencies and ordering:

- The three fast checks are independent and run in parallel; all must be green to merge.
- `codeql` is a two-job chain: `detect` (cheap, Ubuntu) decides `has_swift`, and only then does `analyze` (expensive, macOS) run. It runs on PR, push to `main`, weekly, and on demand; `concurrency: cancel-in-progress` keeps a newer commit from stacking runs.
- Every workflow uses `concurrency: cancel-in-progress`, so a newer commit supersedes an in-flight run instead of stacking the queue.

### Why CodeQL is slow, and why we gate on it anyway

CodeQL's Swift extractor needs a full build wrapped by its compiler tracer. The build, not the analysis, is the cost. This was measured on the runner:

| Build variant | Time |
|---------------|------|
| Original (universal binary + previews, traced) | 18m39s |
| Lean (single arch, no previews/index/testability), traced | ~17 min |
| Lean + restored module cache (cache **hit**) | 15m50s |
| The exact same lean build **untraced** | **30 s** |

The project's ~950 lines compile in well under a second. The entire cost is the CodeQL tracer re-precompiling **every imported system module** (SwiftUI, CloudKit, CoreData, ...) on each run. It is **irreducible**: caching the precompiled modules and pre-warming them in an untraced build before the traced one were both tried and both made no difference, because the traced build redoes the precompile regardless of what is on disk. The lean-build settings shave a couple of minutes off the floor but cannot get near the 30 s untraced number.

It cannot be made fast, but security scanning of real code is worth the wait, so it gates the merge path: every PR and push to `main` runs it, on top of the weekly schedule and manual dispatch. If the per-PR cost becomes a problem, the options are a self-hosted macOS runner or GitHub's larger macOS runners; reverting to a scheduled-only scan means dropping the `pull_request` trigger and the `code_scanning` ruleset rule.

## The `main` ruleset

`main` is protected by a repository ruleset (not classic branch protection):

- Pull request required (0 approvals; a solo owner cannot approve their own PR).
- Required status checks: `Scan for secrets`, `Block secrets and private files`, `PR title and description`, `Analyze Swift` (CodeQL).
- Linear history, no deletion, no force-push.
- The repository admin can bypass (use sparingly, e.g. an unblockable greenfield case).

`CODEOWNERS` requests the owner's review on every PR.

A ruleset is a repository **setting**, so it does not travel with a clone or a fork. To keep it reproducible it is checked in as code at [`.github/rulesets/main.json`](../.github/rulesets/main.json), and applied with one idempotent command (needs the `gh` CLI with admin on the repo):

```bash
./.github/scripts/setup-branch-protection.sh
```

The script creates the ruleset, or updates it in place if one named `main` already exists. Edit the JSON and re-run to change the rules. You can also import the JSON manually under Settings -> Rules -> Rulesets -> New ruleset -> Import.

## Forks and secrets

CI passes with **no repository secrets configured**, so a fresh copy is green out of the box:

- `DEVELOPMENT_TEAM` (used by `codeql`) is optional - the analysis build disables code signing, so an unset value just writes an empty `Secrets.xcconfig`. Set it only to trace a signed build.
- `FORBIDDEN_STRINGS` (used by `guard`) is optional - the personal-data check runs its email scan regardless and only adds the private denylist when the secret is present.

Neither secret is required to merge. Add them later as enhancements.

## Versioning and releases

Release tags use `vX.Y.Z`:

- **X (major):** decided manually by the owner (for example `v1`, `v2`); never bumped automatically.
- **Y (feature):** normal releases for new features; increments freely, no upper bound.
- **Z (fix):** hotfixes and small or minor changes.

Release process:

1. Promote `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD`.
2. Merge to `main`.
3. Tag `vX.Y.Z` on the merge commit and push it; `release-check` validates the tag and changelog.
4. Create the GitHub release.
