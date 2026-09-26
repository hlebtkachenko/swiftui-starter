# ADR-0012: Observability and analytics

**Status:** Accepted - 2026-06-09; amended 2026-09-26 (generic wording, MetricManager)

## Context

We need logging, crash insight, and usage signal to maintain the app, but third-party analytics or crash SDKs would add dependencies, a tracking surface, and tension with the template's privacy-first posture.

## Decision

- Use first-party tooling only: `OSLog` for logging, MetricKit for metrics and diagnostics, the Xcode Organizer for crash reports, and App Store Connect for usage analytics.
- Add no Crashlytics, Sentry, or third-party analytics SDK.

## Consequences

- Keeps the zero-dependency and no-tracking posture clean and the privacy labels honest.
- Implementation (2026-09-26): MetricKit reports arrive through the async `MetricManager` streams on OS 27, started once from `AppEnvironment.start()` on every platform; the delegate-based `MXMetricManager`, whose callback ran off the main actor and trapped under main-actor default isolation, is no longer used.
- No live cloud crash dashboard; insight comes from MetricKit and Organizer after the fact. Acceptable at this scale, revisited only on a concrete need.

## Links

- Evidence: research report section 0.5 (observability decision).
