#!/usr/bin/env bash
# Flag prose lines that appear verbatim in two or more Markdown files: the
# copy-paste form of documentation duplication. Each topic should live in one
# home (see docs/README.md) and be linked, not restated.
#
# Limits: this catches verbatim lines only. Paraphrased duplication (the same
# idea in different words) is not detectable here; the ownership map and review
# prevent that. CHANGELOG.md and fenced code blocks are excluded.
set -euo pipefail

min_len=45
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r f; do
  in_fence=0
  while IFS= read -r line; do
    case "$line" in
      '```'*) in_fence=$(( 1 - in_fence )); continue ;;
    esac
    [ "$in_fence" -eq 1 ] && continue
    norm="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ "${#norm}" -ge "$min_len" ] || continue
    printf '%s\t%s\n' "$norm" "$f" >> "$tmp"
  done < "$f"
done < <(git ls-files '*.md' ':!CHANGELOG.md' ':!CLAUDE.md')

dupes="$(sort -u "$tmp" | awk -F'\t' '{c[$1]++} END{for (k in c) if (c[k] > 1) print k}')"
if [ -n "$dupes" ]; then
  echo "::error::These lines appear verbatim in 2+ Markdown files. Keep each topic in one home (docs/README.md) and link instead:"
  printf '%s\n' "$dupes"
  exit 1
fi
echo "OK: no verbatim duplicated lines across Markdown docs."
