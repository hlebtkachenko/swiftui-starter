# ADR-0012: Observability and analytics

**Status:** Accepted - 2026-06-09

## Context

We need logging, crash insight, and usage signal to maintain the app, but third-party analytics or crash SDKs would add dependencies, a tracking surface, and tension with the family-app posture.

## Decision

- Use first-party tooling only: `OSLog` for logging, MetricKit for metrics and diagnostics, the Xcode Organizer for crash reports, and App Store Connect for usage analytics.
- Add no Crashlytics, Sentry, or third-party analytics SDK.

## Consequences

- Keeps the zero-dependency and no-tracking posture clean and the privacy labels honest.
- No live cloud crash dashboard; insight comes from MetricKit and Organizer after the fact. Acceptable at this scale, revisited only on a concrete need.

## Links

- Evidence: research report section 0.5 (observability decision).
