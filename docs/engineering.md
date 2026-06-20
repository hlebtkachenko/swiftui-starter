# Engineering principles and conventions

The four principles below are adapted from the Karpathy coding guidelines (https://github.com/multica-ai/andrej-karpathy-skills). They bias toward caution over speed; for trivial tasks, use judgment. `AGENTS.md` carries the one-line summary; this is the full version.

## 1. Think before coding
State assumptions explicitly; if uncertain, ask. If multiple interpretations exist, present them, do not pick silently. If a simpler approach exists, say so and push back when warranted. If something is unclear, stop, name what is confusing, and ask.

## 2. Simplicity first
Minimum code that solves the problem, nothing speculative. No features beyond what was asked, no abstractions for single-use code, no "flexibility" that was not requested, no error handling for impossible scenarios. If 200 lines could be 50, rewrite it.

## 3. Surgical changes
Touch only what you must. Do not "improve" adjacent code, comments, or formatting. Match the existing style even if you would do it differently. Remove only the orphans your own changes create; flag pre-existing dead code instead of deleting it. Every changed line should trace directly to the request.

## 4. Goal-driven execution
Turn tasks into verifiable goals ("add validation" becomes "write tests for invalid input, then make them pass"). For multi-step work, state a brief plan with a verify step per item, then loop until verified.

## Conventions

- **English only** in all code, comments, commits, and documentation (exception: official proper names).
- **Conventional Commits** for PR titles and commits. Allowed types (enforced by `pr-check`): `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`, `build`, `style`, `revert`.
- Follow the **Swift API Design Guidelines** for naming.
- Proprietary project: see `LICENSE`. Use requires the owner's prior written approval, even for personal use.

## Apple platform conventions

Derived from Apple's official guidance and the Develop in Swift tutorials (https://developer.apple.com/tutorials/develop-in-swift/), aligned 2026-06-09. These are coding conventions; the decisions behind them live in `adr/`.

- **One source of truth per feature.** A model or service type owns the state; views read from it and keep no parallel copies in `@State`. Persisted data comes from Core Data; non-persistent state from an `@Observable` service.
- **Previews and tests share one in-memory store.** Build a single helper that loads an in-memory Core Data stack with sample data, and attach it both in `#Preview` and in the logic tests (the in-memory double from ADR-0013), instead of repeating setup.
- **Navigation, not actions, in the tab bar** (three to five tabs); put one or two key actions in the toolbar; use `Form` for grouped edit screens.
- **Named asset colors** referenced as `Color("Name")` from `Assets.xcassets`, never hard-coded literals in views.
- **New Swift files** drop straight into the synchronized folders; the project includes them without a project-file edit (see ADR-0015).

For reading Apple's docs efficiently, fetch the Swift-DocC JSON: `curl 'https://developer.apple.com/tutorials/data<page-path>.json'`. Concrete implementation recipes distilled from Apple's samples live in [patterns.md](patterns.md).
