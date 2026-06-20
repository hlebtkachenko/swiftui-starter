#!/usr/bin/env bash
# Fail if private key material is present in tracked text files.
# Excludes this scripts directory so the pattern below does not match itself.
set -euo pipefail

if git grep -nI -E -e '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----' -- . ':!.github/scripts'; then
  echo "::error::Private key material found in tracked files."
  exit 1
fi
echo "OK: no private key material in tracked files."
