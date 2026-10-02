# Conventions and implementation patterns

Swift and Apple-platform conventions, plus reusable recipes distilled from Apple's official samples (Food Truck, Backyard Birds, Fruta) and documentation, mapped to AppName's stack. These are conventions, not decisions; the decisions and their rationale live in [`adr/`](adr/README.md), and the API evidence in [`plans/os26-apple-native-research.md`](plans/os26-apple-native-research.md).

**Modernize anything borrowed.** The samples floor at iOS 15-17, so before adopting a pattern, replace the dated parts: `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` become Observation (`@Observable` + `@State` + `@Environment`); `PreviewProvider` becomes the `#Preview` macro; `NavigationView` and `NavigationLink(tag:selection:)` become `NavigationSplitView` and value-based links; `Task.sleep(nanoseconds:)` becomes `Task.sleep(for:)`; `AnimatableModifier` becomes `Animatable`. The samples' size-class shims and pre-27 fallbacks are dropped at our OS 27 floor.

## Conventions

- Name things per the **Swift API Design Guidelines**.
- **One source of truth per feature.** A model or service type owns the state; views read from it and keep no parallel copies in `@State`. Persisted data comes from Core Data; non-persistent state from an `@Observable` service.
- **Navigation, not actions, in the tab bar** (three to five tabs); put one or two key actions in the toolbar; use `Form` for grouped edit screens.
- **Named asset colors** referenced as `Color("Name")` from `Assets.xcassets`, never hard-coded literals in views.
- Read Apple's docs as Swift-DocC JSON: `curl 'https://developer.apple.com/tutorials/data<page-path>.json'`.

## House rules

- Priority order when goals conflict: no data loss, then no crashes, then no other bugs, then performance, then developer convenience.
- Classes are `final` unless designed for subclassing.
- One primary type, or one tight cluster of types for one concern, per file, named after the type or concern; per-platform variants of the same role (for example the iOS and macOS `AppDelegate`) may share it.
- Every SwiftUI view file ships a `#Preview`, backed by the in-memory store where it needs data.
- Keep `init` of `@Observable` types and `@State` defaults free of side effects (SwiftUI may evaluate a `@State` default more than once), except a subscription that must exist before the first window (the `AppEnvironment` sync subscription); start other work in an explicit `start()` or `.task`.
- Keep `#if os(...)` out of view bodies: isolate platform differences in a small helper type or modifier, one per concern.
- SwiftUI first; wrap UIKit/AppKit with `UIViewRepresentable`/`NSViewRepresentable` only where SwiftUI is measured too slow or lacks a required behavior, and note why at the call site.
- UI tests find elements by `accessibilityIdentifier`, never by visible or localized text; keep identifiers as constants in one place when the first UI test needs them.
- Formatting: see the `swift format` command in AGENTS.md.

## Localization

- User-facing strings go through String Catalogs from the first screen; give every string a translator comment.
- Use the catalog's plural variations, not separate singular/plural keys.
- Use `.leading`/`.trailing`, never `.left`/`.right`, so right-to-left languages work.

## Project structure and modularization

- One native multiplatform target for iPhone, iPad, and Mac (iOS and macOS SDKs; Food Truck confirms a single target, not per-platform targets); never Mac Catalyst.
- When modularization is warranted (see [ADR-0015](adr/0015-project-structure-agent-ergonomics.md)), use the Data/UI package split that Backyard Birds and Food Truck use: a `AppNameData` local package (the `NSManagedObject` subclasses, the `NSPersistentCloudKitContainer` stack, `CKShare` helpers, fetch-request factories, and value-type snapshots, with no SwiftUI import) and a `AppNameUI` package (reusable views that take entities as plain arguments). The app target, any future widget, and the Swift Testing suites all depend on both; UI depends on Data, never the reverse. Local packages declare the OS 27 floor and the Swift 6 language mode.
- Keep domain assets (named colors, custom SF Symbols, images) in the owning package's own `Assets.xcassets` and expose them as typed `Image` / `Color` members loaded with `bundle: .module`, instead of string literals at the call site.
- Co-locate String Catalogs (`.xcstrings`) per feature and address them with `bundle: .module`.

## Adaptive navigation shell

- Drive navigation from one screen enum (`Destination`): `Hashable, Identifiable, CaseIterable`, each case yielding both its sidebar label and its detail view.
- `ContentView` reads a `prefersTabNavigation` environment flag (derived from idiom and size class) and switches between a `TabView` for compact width (iPhone) and a `NavigationSplitView { sidebar } detail: { stack }` for regular width (iPad, Mac), over the same data.
- Register `.navigationDestination(for:)` per screen and type it on the object's `NSManagedObjectID` (the template's identity; it has no `id` attribute), not on a live `NSManagedObject`; resolve the ID to an object inside the destination so `NavigationPath` stays value-safe.
- A card or row that navigates needs a compact-versus-regular split: a `NavigationLink(value:)` on compact iPhone, but a sidebar `selection` binding on iPad and Mac so the split view responds (Food Truck's `CardNavigationHeader`). Use a width-threshold reader to make the compact/wide decision in one place.

## Core Data previews and tests

Supports the in-memory test double in [ADR-0013](adr/0013-testing-strategy.md): previews and logic tests share one in-memory store instead of repeating setup.

- Build previews and tests on `PersistenceController(inMemory: true)` (a `/dev/null` store URL, no CloudKit) and create the objects they need through `AppNameStore`, so they exercise the same write path as the app.
- Ship no seed or sample data in Release builds. Demo content for screenshots lives behind the debug-only `-demoContent` launch argument (`AppName/Data/DemoContent.swift`), writes through `AppNameStore`, and seeds only an empty store.

## Sign in with Apple

Supports [ADR-0011](adr/0011-auth-account-lifecycle.md).

- Use the SwiftUI `SignInWithAppleButton` and handle its `Result<ASAuthorization, Error>` in an `@Observable` auth service.
- At launch, call `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)` to silently restore a valid session or sign the user out if the credential was revoked or transferred. This is required behavior, not optional polish.
- Store the stable `credential.user` identifier in the **Keychain**, not `UserDefaults`, so it survives app deletion (Fruta uses `UserDefaults` for brevity; AppName must not).
- Short-circuit to a signed-in state under `#if targetEnvironment(simulator)` so previews and the Simulator render account-gated UI without the real flow.
- Entitlement: `com.apple.developer.applesignin = [Default]`.

## Reusable SwiftUI conventions

- Define button styles as types plus a `static var` accessor, giving call sites like `.buttonStyle(.appNamePrimary)`; centralize animation constants on `Animation` (for example `.openCard`) instead of inline magic numbers.
- Expand a card from a list with `@Namespace` + `matchedGeometryEffect` + a ZStack overlay, rather than a navigation push, when the source item should stay in place.
- Pin a persistent action bar with `.safeAreaInset(edge: .bottom)` so list content scrolls beneath it.
- Add `.accessibilityRotor(...)` for the meaningful subsets of a list (for example "Items added this week") from the start; it is cheap to add alongside the list and costly to retrofit.
- Provide macOS menu commands through a `Commands` struct attached to the `Scene`.

## Future work (design now, build later)

- **App Group container.** Put the Core Data SQLite in a shared App Group container from the start, before any widget exists, so a future widget or App Clip can read the same store without a migration (Backyard Birds' widget reuses the data layer through a shared container).
- **Widgets and App Intents.** A widget reuses `AppNameData`; an interactive widget exposes an `AppEntity` lightweight mirror (id plus name) with an `EntityQuery`, and the `AppIntent.perform()` opens a fresh context, mutates, and saves, which propagates to CloudKit.

## Validated as-is

- Our `Shared.xcconfig` plus a gitignored `Secrets.xcconfig` is cleaner than the samples' bundle-ID disambiguator trick; no change needed.
