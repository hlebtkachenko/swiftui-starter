# ADR-0016: Monetization and App Store category

**Status:** Accepted - 2026-06-09

## Context

Two early App Store choices shape later constraints: how the app makes money, and whether it enters the Kids Category. The Kids Category bans third-party analytics and ads and requires a parental gate, so it must be decided before any SDK is added.

## Decision

- Ship free with no in-app purchases for v1; wire StoreKit 2 later only on a concrete need.
- Submit as a general 4+ family app, not the Kids Category, because accounts require an Apple ID through Sign in with Apple and the shared data is adult-managed.

## Consequences

- Fastest route to shipping, with no purchase plumbing to build yet.
- "Family" here means made-for-families, which avoids the Kids Category constraints and keeps the door open to first-party analytics. If a future feature targets children directly, revisit guidelines 1.3 and 5.1.4.

## Links

- Evidence: research report section 8.7 (Kids Category, login services).
