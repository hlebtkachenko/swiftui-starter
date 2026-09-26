# ADR-0016: Monetization and App Store category

**Status:** Accepted - 2026-06-09; amended 2026-09-26 (category decided per app)

## Context

Two early App Store choices shape later constraints: how the app makes money, and whether it enters the Kids Category. The Kids Category bans third-party analytics and ads and requires a parental gate, so it must be decided before any SDK is added.

## Decision

- Ship free with no in-app purchases for v1; wire StoreKit 2 later only on a concrete need.
- Decide the App Store category and age rating per app, before any SDK is added. The template assumes no Kids Category: it adds no analytics or ads and requires nothing that would conflict, but it makes no category choice for you.

## Consequences

- Fastest route to shipping, with no purchase plumbing to build yet.
- An app that targets children must enter the Kids Category deliberately and follow guidelines 1.3 and 5.1.4 (parental gate, no third-party analytics or ads).

## Links

- Evidence: research report section 8.7 (Kids Category, login services).
