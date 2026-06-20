# ADR-0010: On-device AI posture

**Status:** Accepted - 2026-06-09

## Context

AI could help with suggestions, summaries, and smarter search, but a cloud model would pull in a backend, API keys, billing, and a new privacy surface, all of which clash with the zero-dependency, pure-Apple stack.

## Decision

- Ship no AI in v1.
- When AI is added, keep it on-device only: Foundation Models (`SystemLanguageModel`, optionally Private Cloud Compute) for generation and extraction, `NLEmbedding` for semantic search, Core ML for any custom model, and App Intents/Spotlight for system surfacing.
- Use no cloud or third-party LLM. The local-first store from [ADR-0005](0005-data-persistence-sync-offline.md) is what makes private, no-network AI inexpensive, since the data is already on device.

## Consequences

- On the OS 26 floor only the on-device `SystemLanguageModel` is available (26.0+), and only when the user has Apple Intelligence enabled; gate features on `SystemLanguageModel.default.availability` and degrade gracefully for `.appleIntelligenceNotEnabled`, `.deviceNotEligible`, and `.modelNotReady`. The on-device model has a 4,096-token context, fits summarize/extract/classify/tag/short-generate, and offers a `.contentTagging` use case for categorizing AppName items. Typed output uses `@Generable` (structs and enums only).
- `PrivateCloudComputeLanguageModel` and third-party providers (the `LanguageModel` protocol) are iOS/macOS 27.0 beta, not on our floor, which keeps the no-cloud-LLM stance automatic for v1.

## Links

- Evidence: research report section 5 (on-device AI).
