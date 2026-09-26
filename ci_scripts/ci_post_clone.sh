#!/bin/sh
# Xcode Cloud runs this after cloning. The gitignored Secrets.xcconfig is not in
# the clone, so write the bundle ID prefix from the workflow's environment
# variable BUNDLE_ID_PREFIX; without it, archives fall back to com.example.
set -eu
if [ -n "${BUNDLE_ID_PREFIX:-}" ]; then
  printf 'BUNDLE_ID_PREFIX = %s\n' "$BUNDLE_ID_PREFIX" > "$CI_PRIMARY_REPOSITORY_PATH/Secrets.xcconfig"
fi
