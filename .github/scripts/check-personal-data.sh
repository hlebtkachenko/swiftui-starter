#!/usr/bin/env bash
# Fail if tracked files contain personal data: email addresses (other than
# allowlisted placeholders), or any string from a private denylist.
# This guards against leaking contact details, names, or infrastructure into a
# public repository. Excludes this scripts directory so its patterns do not
# match themselves.
set -euo pipefail

status=0
scope=(. ':!.github/scripts')

# 1) Email addresses. Catches leaked personal/contact emails. Placeholder and
#    example addresses are allowlisted so docs can show a sample.
email_re='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
allow_re='@(example\.(com|org|net)|test|localhost)|^(you|your-email|user|name|email|someone)@'
emails="$(git grep -nIE -- "$email_re" "${scope[@]}" || true)"
if [ -n "$emails" ]; then
  bad="$(printf '%s\n' "$emails" | grep -viE "$allow_re" || true)"
  if [ -n "$bad" ]; then
    echo "::error::Email address(es) found in tracked files. Remove personal or contact info from a public repo:"
    printf '%s\n' "$bad"
    status=1
  fi
fi

# 2) Private denylist of exact forbidden strings (real name, handles, infra,
#    phone, etc.). Provided out-of-band so the values never live in the repo:
#    - CI: the FORBIDDEN_STRINGS secret (newline-separated).
#    - Local: a gitignored .forbidden-strings file (newline-separated).
#    Matches are reported as file:line only, never the matched text, to avoid
#    re-leaking the value in public logs.
denylist=""
if [ -n "${FORBIDDEN_STRINGS:-}" ]; then
  denylist="$FORBIDDEN_STRINGS"
elif [ -f .forbidden-strings ]; then
  denylist="$(cat .forbidden-strings)"
fi
if [ -n "$denylist" ]; then
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    hits="$(git grep -nIF -- "$term" "${scope[@]}" || true)"
    if [ -n "$hits" ]; then
      echo "::error::A forbidden private string appears in tracked files (locations only):"
      printf '%s\n' "$hits" | cut -d: -f1-2
      status=1
    fi
  done <<< "$denylist"
fi

[ "$status" -eq 0 ] && echo "OK: no personal data detected in tracked files."
exit "$status"
