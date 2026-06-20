# Implementation patterns

Reusable recipes distilled from Apple's official samples (Food Truck, Backyard Birds, Fruta) and documentation, mapped to AppName's stack. These are conventions, not decisions; the decisions and their rationale live in [`adr/`](adr/README.md), and the API evidence in [`plans/os26-apple-native-research.md`](plans/os26-apple-native-research.md).

**Modernize anything borrowed.** The samples floor at iOS 15-17, so before adopting a pattern, replace the dated parts: `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` become Observation (`@Observable` + `@State` + `@Environment`); `PreviewProvider` becomes the `#Preview` macro; `NavigationView` and `NavigationLink(tag:selection:)` become `NavigationSplitView` and value-based links; `Task.sleep(nanoseconds:)` becomes `Task.sleep(for:)`; `AnimatableModifier` becomes `Animatable`. The samples' size-class shims and pre-26 fallbacks are dropped at our OS 26 floor.

## Project structure and modularization

- One multiplatform target for iPhone, iPad, and Mac (Food Truck confirms a single target, not per-platform targets).
- When modularization is warranted (see [ADR-0015](adr/0015-project-structure-agent-ergonomics.md)), use the Data/UI package split that Backyard Birds and Food Truck use: a `AppNameData` local package (the `NSManagedObject` subclasses, the `NSPersistentCloudKitContainer` stack, `CKShare` helpers, fetch-request factories, and value-type snapshots, with no SwiftUI import) and a `AppNameUI` package (reusable views that take entities as plain arguments). The app target, any future widget, and the Swift Testing suites all depend on both; UI depends on Data, never the reverse. Local packages declare the OS 26 floor and Swift 6 mode.
- Keep domain assets (named colors, custom SF Symbols, images) in the owning package's own `Assets.xcassets` and expose them as typed `Image` / `Color` members loaded with `bundle: .module`, instead of string literals at the call site.
- Co-locate String Catalogs (`.xcstrings`) per feature and address them with `bundle: .module`.

## Adaptive navigation shell

- Drive navigation from one screen enum (`Destination`): `Hashable, Identifiable, CaseIterable`, each case yielding both its sidebar label and its detail view.
- `ContentView` reads a `prefersTabNavigation` environment flag (derived from idiom and size class) and switches between a `TabView` for compact width (iPhone) and a `NavigationSplitView { sidebar } detail: { stack }` for regular width (iPad, Mac), over the same data.
- Register `.navigationDestination(for:)` per screen and type it on the entity's stable ID (a UUID or String), not on a live `NSManagedObject`; resolve the ID to an object inside the destination so `NavigationPath` stays value-safe.
- A card or row that navigates needs a compact-versus-regular split: a `NavigationLink(value:)` on compact iPhone, but a sidebar `selection` binding on iPad and Mac so the split view responds (Food Truck's `CardNavigationHeader`). Use a width-threshold reader to make the compact/wide decision in one place.

## Core Data previews and seed data

Supports the in-memory test double in [ADR-0013](adr/0013-testing-strategy.md).

- Expose a `.appNameDataContainer(inMemory:)` `ViewModifier` that builds an `NSPersistentCloudKitContainer` with an in-memory store (a `/dev/null` store URL), seeds it on appear, and injects it. Use the same modifier in `#Preview` and in the headless logic tests, so previews and tests share one populated store.
- Put seed data in per-entity `Entity+SampleData.swift` files inside `AppNameData` (no UI import), orchestrated by a single `AppNameSeedData.populate(into:)`. Make generation deterministic with a seeded random generator so previews and tests are stable run to run.
- Provide a generic `ModelPreview<Entity>` wrapper that fetches the first object of a type from the in-memory container and hands it to the preview closure, keeping feature previews to one line.
- Give every entity and value type a `static var preview` sample instance.

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
- Add `.accessibilityRotor(...)` for the meaningful subsets of a list (for example "Unclaimed gifts") from the start; it is cheap to add alongside the list and costly to retrofit.
- Provide macOS menu commands through a `Commands` struct attached to the `Scene`.

## Future work (design now, build later)

- **App Group container.** Put the Core Data SQLite in a shared App Group container from the start, before any widget exists, so a future widget or App Clip can read the same store without a migration (Backyard Birds' widget reuses the data layer through a shared container).
- **Widgets and App Intents.** A widget reuses `AppNameData`; an interactive widget exposes an `AppEntity` lightweight mirror (id plus name) with an `EntityQuery`, and the `AppIntent.perform()` opens a fresh context, mutates, and saves, which propagates to CloudKit.
- **App Clip.** A AppName App Clip could open a shared list from a `appname.hapd.dev` universal link without installing the app (Fruta's `onContinueUserActivity` plus an `APPCLIP` compile condition; a 15 MB budget; an AASA file on the domain). Design the share-URL scheme and the handler now so the clip can be added later without API changes.

## Validated as-is

- Our `Shared.xcconfig` plus a gitignored `Secrets.xcconfig` is cleaner than the samples' bundle-ID disambiguator trick; no change needed.
