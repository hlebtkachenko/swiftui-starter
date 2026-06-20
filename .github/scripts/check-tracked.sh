#!/usr/bin/env bash
# Fail if any tracked file matches a secret/private pattern (e.g. force-added
# past .gitignore). Belt-and-suspenders for a public repo.
set -euo pipefail

patterns=(
  '.env' '**/.env' '.env.*' '*.env'
  'Secrets.xcconfig' '*.local.xcconfig'
  '*.key' '*.pem' '*.p8' '*.p12' '*.pfx' '*.cer' '*.der'
  '*.certSigningRequest' '*.mobileprovision' '*.provisionprofile'
  '*.jks' '*.keystore' '*.enc' '.netrc'
  'client_secret*.json' 'serviceAccount*.json'
  'GoogleService-Info.plist' 'AuthKey_*.p8'
  'fastlane/Matchfile' 'fastlane/Appfile'
)

hits="$(git ls-files -- "${patterns[@]}" || true)"
if [[ -n "$hits" ]]; then
  echo "::error::Tracked files match secret/private patterns and must not be committed:"
  echo "$hits"
  exit 1
fi
echo "OK: no secret/private files are tracked."
