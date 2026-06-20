#!/usr/bin/env bash
# Fail if any tracked file exceeds the size limit (guards against accidental
# data dumps or private blobs). Limit: 5 MB.
set -euo pipefail

limit=$((5 * 1024 * 1024))
fail=0
while IFS= read -r -d '' f; do
  [[ -f "$f" ]] || continue
  size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f")
  if (( size > limit )); then
    echo "::error::$f is $((size / 1024 / 1024)) MB, over the 5 MB limit."
    fail=1
  fi
done < <(git ls-files -z)
exit "$fail"
