# ADR-0001: Platform, OS 27 floor, and Liquid Glass

**Status:** Accepted - 2026-06-09; amended 2026-09-26 (floor raised from OS 26 to OS 27)

## Context

AppName targets iPhone, iPad, and Mac and wants the current design language. Liquid Glass arrived with the OS 26 SDK and does not back-deploy, so the design ambition sets the platform floor; the template tracks the newest OS generation, which is OS 27 as of this amendment.

## Decision

- Build one native multiplatform SwiftUI app target with iPhone, iPad, and a native "Designed for Mac" destination.
- Set the minimum deployment to OS 27 (iOS / iPadOS / macOS 27) on every destination, built with Xcode 27; no back-deployment and no pre-27 fallbacks.
- Adopt only genuine system Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`), and only in the navigation/control layer. Never imitate it with blurs or gradients, never stack glass on glass, never place it in the content layer.

## Consequences

- Excludes every user below OS 27; acceptable for a greenfield app chasing the newest look.
- The system material brings Reduce Transparency, Increase Contrast, and Reduce Motion adaptations for free; faking glass would forfeit them, which is the concrete reason the rule is enforced.
- Glass and overall visual correctness need a human or screenshot pass, since they cannot be fully asserted headlessly (see [ADR-0013](0013-testing-strategy.md)).

## Links

- Evidence: research report sections 1 and 2 (Liquid Glass, multiplatform structure).
