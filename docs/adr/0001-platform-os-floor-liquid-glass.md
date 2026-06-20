# ADR-0001: Platform, OS 26 floor, and Liquid Glass

**Status:** Accepted - 2026-06-09

## Context

AppName serves Apple families across iPhone, iPad, and Mac and wants the OS 26 design language. The Liquid Glass APIs ship only in the OS 26 SDK and do not back-deploy, so the design ambition sets the platform floor.

## Decision

- Build one native multiplatform SwiftUI app target with iPhone, iPad, and a native "Designed for Mac" destination.
- Set the minimum deployment to OS 26 on every destination; no back-deployment and no pre-26 fallbacks.
- Adopt only genuine system Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`), and only in the navigation/control layer. Never imitate it with blurs or gradients, never stack glass on glass, never place it in the content layer.

## Consequences

- Excludes every user below OS 26; acceptable for a greenfield app chasing the newest look.
- The system material brings Reduce Transparency, Increase Contrast, and Reduce Motion adaptations for free; faking glass would forfeit them, which is the concrete reason the rule is enforced.
- Glass and overall visual correctness need a human or screenshot pass, since they cannot be fully asserted headlessly (see [ADR-0013](0013-testing-strategy.md)).

## Links

- Evidence: research report sections 1 and 2 (Liquid Glass, multiplatform structure).
