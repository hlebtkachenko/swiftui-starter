#!/usr/bin/env bash
# Keep the ownership map (docs/README.md) current. Every documentation file must
# be listed there, so adding or renaming a doc forces a map update and the map
# cannot silently go stale. Dead links in the map are caught by check-links.sh.
set -euo pipefail

map="docs/README.md"
[ -f "$map" ] || { echo "::error::$map (ownership map) is missing."; exit 1; }

required="$(git ls-files '*.md' ':!CHANGELOG.md' ':!CLAUDE.md' ':!README.md' ':!docs/README.md' ':!.github') LICENSE"
status=0
for f in $required; do
  base="$(basename "$f")"
  grep -qF "$base" "$map" || { echo "::error::$f is not listed in the ownership map ($map). Add it."; status=1; }
done

[ "$status" -eq 0 ] && echo "OK: ownership map lists every documentation file."
exit "$status"
