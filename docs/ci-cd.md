# CI, branch protection, and releases

## Gates

All run on GitHub-hosted runners, and every workflow uses `concurrency: cancel-in-progress`, so a newer commit supersedes an in-flight run. The first three are required checks on `main`; `codeql` is suspended as a gate (below).

| Workflow | Required check | Runs on | Runner, cost | What it does |
|----------|----------------|---------|--------------|--------------|
| `gitleaks.yml` | Scan for secrets | PR, push to `main` | ubuntu, ~10 s | Secret scan over full history, redacted output. |
| `guard.yml` | Block secrets and private files | PR, push to `main` | ubuntu, ~15 s | The `.github/scripts/check-*.sh` guards: secrets/private files, private keys, oversized files, personal data, dead links, duplicate docs, ownership map. See [security.md](security.md). |
| `pr-check.yml` | PR title and description | PR only | ubuntu, ~5 s | Conventional Commits title and a non-trivial description. |
| `codeql.yml` | - (suspended) | weekly (Mon 04:23 UTC), manual | **macOS**, ~17 min | Swift security and quality scan. A cheap Ubuntu `detect` job decides `has_swift` before the macOS `analyze` job runs. |
| `release-check.yml` | - | `v*` tag push | ubuntu, ~10 s | Validates `vX.Y.Z` and a matching `CHANGELOG.md` entry, then publishes the GitHub release. |

`push` is scoped to `main` so a same-repo PR branch is scanned once (through `pull_request`), not twice.

### CodeQL on Xcode 27: suspended as a gate

Since 2026-09-26 the `xcode-27` runner image ships Xcode's `swift-plugin-server` and `sandbox-exec` as arm64-only, while CodeQL's Swift tracer runs the build as x86_64, so every macro expansion fails with "Bad CPU type in executable". Pinning an older CodeQL bundle does not help, and the OS 27 floor rules out building on Xcode 26. Until the problem is fixed upstream, `codeql.yml` runs only weekly and on demand as a probe, and `Analyze Swift` is not a required check. The first green probe on `main` runs the `restore` job, which opens a PR that restores the `push` / `pull_request` triggers and the ruleset entry. That job needs Settings -> Actions -> "Allow GitHub Actions to create pull requests" enabled; after merging the PR, run `setup-branch-protection.sh`.

### Why CodeQL is slow, and why it gates anyway

CodeQL's Swift extractor needs a full build under its compiler tracer, and the tracer re-precompiles every imported system module (SwiftUI, CloudKit, CoreData, ...) on each run. Measured on the runner: the same lean build takes about 30 s untraced and about 17 min traced; caching the module cache or pre-warming it untraced made no difference. The cost is irreducible, and security scanning of real code is worth it. If the per-PR cost becomes a problem, use a self-hosted or larger macOS runner; to go back to a scheduled-only scan, drop the `pull_request` trigger and the `code_scanning` ruleset rule.

## The `main` ruleset

`main` is protected by a repository ruleset (not classic branch protection):

- Pull request required (0 approvals; a solo owner cannot approve their own PR).
- Required status checks: `Scan for secrets`, `Block secrets and private files`, `PR title and description` (`Analyze Swift` returns once CodeQL works on Xcode 27, see above).
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
