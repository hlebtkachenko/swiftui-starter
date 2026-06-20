#!/usr/bin/env bash
# Apply the committed `main` branch ruleset to this repository (idempotent).
#
# GitHub rulesets are repository settings, not files, so a fork or copy does NOT
# inherit them. Run this once after creating your repo to reproduce the
# protection described in docs/ci-cd.md: PR required, the four required status
# checks, linear history, and no force-push or deletion.
#
# Requires the `gh` CLI, authenticated, with admin on the repo.
#
#   ./.github/scripts/setup-branch-protection.sh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
ruleset_file="$repo_root/.github/rulesets/main.json"
name="main"

[ -f "$ruleset_file" ] || { echo "::error::Ruleset file not found: $ruleset_file"; exit 1; }
command -v gh >/dev/null || { echo "::error::The 'gh' CLI is required. See https://cli.github.com/."; exit 1; }

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "Applying ruleset '$name' to $repo ..."

# Update the existing ruleset in place if one with this name exists, else create.
existing_id="$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id" 2>/dev/null | head -1 || true)"
if [ -n "$existing_id" ]; then
  gh api -X PUT "repos/$repo/rulesets/$existing_id" --input "$ruleset_file" >/dev/null
  echo "Updated existing ruleset (id $existing_id)."
else
  gh api -X POST "repos/$repo/rulesets" --input "$ruleset_file" >/dev/null
  echo "Created ruleset."
fi

echo "Done. Verify in repo Settings -> Rules -> Rulesets."
