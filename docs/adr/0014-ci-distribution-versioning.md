# ADR-0014: CI, distribution, and versioning

**Status:** Accepted - 2026-06-09

## Context

The project already runs GitHub Actions for repo hygiene, but building, signing, and shipping an Apple app wants Apple's own pipeline. CloudKit also has separate development and production environments that must be promoted deliberately.

## Decision

- Run two complementary CI lanes: Xcode Cloud builds, tests, signs, and ships to TestFlight and the App Store; GitHub Actions runs the fast PR gates (gitleaks, guard, pr-check) plus the `vX.Y.Z` tag-push release, and runs CodeQL (a slow Swift build) after merge to `main` and on a weekly schedule, off the PR critical path so PRs stay seconds-fast.
- Distribute through TestFlight, internal testers first and external testers later behind a Beta App Review.
- Version with `vX.Y.Z` tags as the marketing version; auto-increment the build number on every upload.
- Promote the CloudKit schema from Development to Production in the CloudKit Dashboard before the first external-TestFlight or production build, because dev/Xcode builds use Development while TestFlight and the App Store use Production.

## Consequences

- Xcode Cloud manages signing, removing most certificate handling.
- The schema promotion is an easy-to-miss release gate that produces an empty or mismatched schema for testers if skipped, recorded here so it is not forgotten.

## Links

- Evidence: research report section 8 (App Store requirements, TestFlight, CI).
