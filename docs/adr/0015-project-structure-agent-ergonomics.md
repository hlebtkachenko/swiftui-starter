# ADR-0015: Project structure and agent ergonomics

**Status:** Accepted - 2026-06-09

## Context

Editing the Xcode project file by hand is historically painful for both people and agents, which tempts teams toward project generators. The AppName project was inspected directly to check whether that pain actually applies here.

## Decision

- Keep a single `AppName.xcodeproj`. It already uses Xcode 16+ filesystem-synchronized groups (`PBXFileSystemSynchronizedRootGroup`) for the `AppName`, `AppNameTests`, and `AppNameUITests` folders, so adding a Swift file needs no project-file edit and creates no per-file merge conflict; agents add files simply by writing into the folder.
- Do not adopt Tuist or XcodeGen, since they would replace a working native feature with a third-party tool.
- Keep local SPM packages optional, justified only by build time or module boundaries as the app grows, never as a workaround for project-file churn.

## Consequences

- Routine file additions are a non-issue for agents. The project file changes only for new targets, build settings, capabilities, or dependencies, which are infrequent and best done in Xcode.
- This is foundational repo knowledge: do not re-raise project-file pain or propose a generator to "fix" something the synchronized groups already solve.
- Recommended shape if and when packages are warranted (from Apple's Food Truck and Backyard Birds samples): a `AppNameData` package (Core Data stack, `CKShare` helpers, value types; no SwiftUI import) and a `AppNameUI` package (views taking entities as arguments); the app, future widgets, and tests depend on both, while UI depends on Data only. Detail in `docs/patterns.md`.

## Links

- Evidence: research report section 7 (repo and project structure); verified against `AppName.xcodeproj/project.pbxproj`.
