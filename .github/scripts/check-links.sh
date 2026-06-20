#!/usr/bin/env bash
# Verify relative Markdown links resolve to an existing path (no dead pointers).
# External links (http, mailto) and pure anchors are skipped.
set -euo pipefail

status=0
while IFS= read -r f; do
  dir="$(dirname "$f")"
  targets="$(grep -oE '\]\([^)]+\)' "$f" 2>/dev/null | sed -E 's/^\]\((.+)\)$/\1/' || true)"
  [ -z "$targets" ] && continue
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    path="${target%%#*}"
    [ -z "$path" ] && continue
    if [ ! -e "$dir/$path" ]; then
      echo "::error::$f: dead relative link -> $target"
      status=1
    fi
  done <<< "$targets"
done < <(git ls-files '*.md' ':!CLAUDE.md')

[ "$status" -eq 0 ] && echo "OK: all relative Markdown links resolve."
exit "$status"
