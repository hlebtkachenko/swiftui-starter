# Architecture Decision Records

The durable record of AppName's load-bearing technical decisions: what we chose, why, and what each choice commits us to. One decision per file, numbered, immutable once **Accepted**. To change a decision, add a new ADR that supersedes the old one and mark the old one `Superseded by ADR-XXXX`; never rewrite an accepted record.

**Canonical vs evidence.** These ADRs are the canonical "what we decided." The research report [`../plans/os26-apple-native-research.md`](../plans/os26-apple-native-research.md) holds the Apple primary-source evidence (API signatures, citations, trade-offs) behind them; its §0.5 table is the original lock log from 2026-06-09. [`../../STATE.md`](../../STATE.md) carries the at-a-glance snapshot.

## Records

| # | Decision |
|---|----------|
| [0001](0001-platform-os-floor-liquid-glass.md) | Platform, OS 26 floor, and Liquid Glass |
| [0002](0002-language-build-concurrency.md) | Language, build toolchain, and concurrency |
| [0003](0003-ui-state-architecture.md) | UI and state architecture |
| [0004](0004-dependency-policy.md) | Dependency policy |
| [0005](0005-data-persistence-sync-offline.md) | Data, persistence, sync, and offline |
| [0006](0006-sharing-access-control-roles.md) | Sharing, access control, and family roles |
| [0007](0007-file-attachment-storage.md) | File and attachment storage |
| [0008](0008-in-app-search.md) | In-app search |
| [0009](0009-notifications.md) | Notifications |
| [0010](0010-on-device-ai-posture.md) | On-device AI posture |
| [0011](0011-auth-account-lifecycle.md) | Authentication and account lifecycle |
| [0012](0012-observability-analytics.md) | Observability and analytics |
| [0013](0013-testing-strategy.md) | Testing strategy |
| [0014](0014-ci-distribution-versioning.md) | CI, distribution, and versioning |
| [0015](0015-project-structure-agent-ergonomics.md) | Project structure and agent ergonomics |
| [0016](0016-monetization-app-store-category.md) | Monetization and App Store category |
| [0017](0017-web-support-legal.md) | Web presence, support, and legal pages |

## Format

- File name `NNNN-kebab-title.md`; heading `# ADR-NNNN: Title`.
- Status one of `Proposed`, `Accepted`, `Superseded by ADR-XXXX`, `Deprecated`.
- Sections: Context, Decision, Consequences, plus links to the evidence and related records.
- Keep each record short; push detailed proof to the research report and link to it.

Records 0001-0017 were Accepted on 2026-06-09 as AppName's founding stack.
