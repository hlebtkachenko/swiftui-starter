# ADR-0017: Web presence, support, and legal pages

**Status:** Accepted - 2026-06-09

## Context

The App Store requires a working support URL and a privacy policy URL, and AppName wants a small public face. The app itself needs no domain, since CloudKit and APNs run on Apple endpoints.

## Decision

- Host everything on `appname.hapd.dev`, which already exists: a minimal info-only marketing page plus the App Store-required support, privacy policy, terms, and account-deletion pages.
- Keep the site static and served over HTTPS, with no analytics. Treat branded Universal Links as optional and post-v1.

## Consequences

- One static property to maintain, and the required App Store URLs have a home.
- No personal contact information appears anywhere; support routes through GitHub, per the repo's boundaries.

## Links

- Evidence: research report sections 8 and 8.7 (App Store metadata, support, privacy).
