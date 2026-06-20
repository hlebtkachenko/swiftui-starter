# Docs and ownership map

Single source of truth: **each topic lives in exactly one file.** Other files link to it, they do not restate it. If you are about to write something that already exists elsewhere, link instead.

| Topic | Home |
|-------|------|
| Coordination, constraints, boundaries, commands (lean index) | [`../AGENTS.md`](../AGENTS.md) |
| Current state, blockers, how to resume | [`../STATE.md`](../STATE.md) |
| Change history and versioning | [`../CHANGELOG.md`](../CHANGELOG.md) |
| License | [`../LICENSE`](../LICENSE) |
| Vulnerability-reporting policy | [`../SECURITY.md`](../SECURITY.md) |
| Engineering principles and conventions | [engineering.md](engineering.md) |
| Secrets, personal data, privacy, guard internals, denylist | [security.md](security.md) |
| CI gates, the `main` ruleset, release process | [ci-cd.md](ci-cd.md) |
| How to start a new app from this template | [using-the-template.md](using-the-template.md) |
| Founding technical decisions (canonical, one per record) | [adr/README.md](adr/README.md) plus the numbered records listed below |
| OS 26 SwiftUI / Liquid Glass stack research and evidence behind the ADRs | [plans/os26-apple-native-research.md](plans/os26-apple-native-research.md) |
| Implementation recipes distilled from Apple samples and docs | [patterns.md](patterns.md) |

`AGENTS.md` may carry one-line summaries that point here; that is the index, not duplication. Anything longer than a pointer belongs in one home only.

This map is enforced per PR by `check-ownership-map.sh` in the `guard` workflow: every documentation file must appear in this file, so the map cannot go stale when docs are added or renamed.

## Architecture Decision Records

The canonical decision log is [`adr/`](adr/README.md): one record per decision, immutable once accepted. Link to a record, do not restate it; the research report holds the evidence behind each.

| Record | File |
|--------|------|
| ADR index and format guide | [adr/README.md](adr/README.md) |
| ADR-0001 platform, OS floor, Liquid Glass | [adr/0001-platform-os-floor-liquid-glass.md](adr/0001-platform-os-floor-liquid-glass.md) |
| ADR-0002 language, build, concurrency | [adr/0002-language-build-concurrency.md](adr/0002-language-build-concurrency.md) |
| ADR-0003 UI and state architecture | [adr/0003-ui-state-architecture.md](adr/0003-ui-state-architecture.md) |
| ADR-0004 dependency policy | [adr/0004-dependency-policy.md](adr/0004-dependency-policy.md) |
| ADR-0005 data, persistence, sync, offline | [adr/0005-data-persistence-sync-offline.md](adr/0005-data-persistence-sync-offline.md) |
| ADR-0006 sharing, access control, roles | [adr/0006-sharing-access-control-roles.md](adr/0006-sharing-access-control-roles.md) |
| ADR-0007 file and attachment storage | [adr/0007-file-attachment-storage.md](adr/0007-file-attachment-storage.md) |
| ADR-0008 in-app search | [adr/0008-in-app-search.md](adr/0008-in-app-search.md) |
| ADR-0009 notifications | [adr/0009-notifications.md](adr/0009-notifications.md) |
| ADR-0010 on-device AI posture | [adr/0010-on-device-ai-posture.md](adr/0010-on-device-ai-posture.md) |
| ADR-0011 authentication and account lifecycle | [adr/0011-auth-account-lifecycle.md](adr/0011-auth-account-lifecycle.md) |
| ADR-0012 observability and analytics | [adr/0012-observability-analytics.md](adr/0012-observability-analytics.md) |
| ADR-0013 testing strategy | [adr/0013-testing-strategy.md](adr/0013-testing-strategy.md) |
| ADR-0014 CI, distribution, versioning | [adr/0014-ci-distribution-versioning.md](adr/0014-ci-distribution-versioning.md) |
| ADR-0015 project structure and agent ergonomics | [adr/0015-project-structure-agent-ergonomics.md](adr/0015-project-structure-agent-ergonomics.md) |
| ADR-0016 monetization and App Store category | [adr/0016-monetization-app-store-category.md](adr/0016-monetization-app-store-category.md) |
| ADR-0017 web presence, support, legal pages | [adr/0017-web-support-legal.md](adr/0017-web-support-legal.md) |
