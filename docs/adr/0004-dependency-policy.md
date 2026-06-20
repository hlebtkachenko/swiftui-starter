# ADR-0004: Dependency policy

**Status:** Accepted - 2026-06-09

## Context

Every third-party dependency is attack surface, a privacy-manifest obligation, and an ABI/maintenance risk. Apple's first-party frameworks already cover most of what AppName needs.

## Decision

- Use Swift Package Manager exclusively, with zero third-party dependencies to start.
- Prefer first-party frameworks; add a dependency only when a concrete need clearly beats first-party, and review each for its privacy-manifest entry and maintenance cost.
- Splitting our own code into local SPM packages is internal structure, not a dependency, and stays optional (see [ADR-0015](0015-project-structure-agent-ergonomics.md)).
- Do not adopt CocoaPods or Carthage.

## Consequences

- Smallest possible privacy and security surface, and clean App Store privacy labels.
- Some capabilities we build ourselves instead of pulling a library; accepted as the cost of the zero-dependency posture.
- CocoaPods trunk goes read-only on 2 December 2026, so avoiding it also dodges a dead-end.

## Links

- Evidence: research report section 6 (dependencies).
