#!/usr/bin/env bash
# Rename the AppName placeholder to your app's name, once, from a clean checkout:
#   ./rename.sh MyApp
# Replaces AppName / appName / appname in every tracked text file (binaries such
# as PNGs are skipped), then renames the tracked files and folders. Review the
# result with `git status` and `git diff`; undo with `git reset --hard`.
set -euo pipefail

new="${1:-}"
if [[ ! "$new" =~ ^[A-Z][A-Za-z0-9]*$ || "$new" == AppName ]]; then
  echo "usage: ./rename.sh MyApp" >&2
  echo "The name must start with an uppercase letter and use only letters and digits." >&2
  exit 1
fi

cd "$(dirname "$0")"
if [ ! -d AppName.xcodeproj ]; then
  echo "AppName.xcodeproj not found: this copy is already renamed." >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Commit or stash your changes first, so the rename can be reviewed and undone." >&2
  exit 1
fi

lower="$(tr '[:upper:]' '[:lower:]' <<< "$new")"
camel="$(tr '[:upper:]' '[:lower:]' <<< "${new:0:1}")${new:1}"

# 1. File contents. -I skips binary files; this script keeps its placeholders.
git grep -lzI -e AppName -e appName -e appname -- . ':!rename.sh' |
  xargs -0 perl -i -pe "s/AppName/${new}/g; s/appName/${camel}/g; s/appname/${lower}/g"

# 2. Paths: rename the outermost tracked path component that still holds
# AppName, then look again, until none is left.
while path="$(git ls-files | grep -m1 AppName)"; do
  prefix="$(awk -F/ '{ p = ""; for (i = 1; i <= NF; i++) { p = (i > 1 ? p "/" : "") $i; if ($i ~ /AppName/) { print p; exit } } }' <<< "$path")"
  base="$(basename "$prefix")"
  git mv "$prefix" "$(dirname "$prefix")/${base//AppName/$new}"
done

# 3. Nothing may be left behind.
if git grep -qI -e AppName -e appName -e appname -- . ':!rename.sh'; then
  echo "Placeholders remain:" >&2
  git grep -nI -e AppName -e appName -e appname -- . ':!rename.sh' >&2
  exit 1
fi

echo "Renamed AppName to ${new} (bundle ID suffix and iCloud container: ${lower})."
echo "Next: docs/using-the-template.md, step 3. You can delete rename.sh now."
