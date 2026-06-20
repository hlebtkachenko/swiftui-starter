# Building a Greenfield OS 26 SwiftUI Multiplatform App (Liquid Glass) — Official Apple Guidance

> **Scope.** A trustworthy, citation-backed research release on Apple's *official* guidance for a brand-new native app targeting iPhone, iPad, and Mac, with a hard floor of **OS 26 only** (iOS 26 / iPadOS 26 / macOS 26 "Tahoe"), built in SwiftUI, adopting genuine system **Liquid Glass**, and shipped via **App Store + TestFlight**.
>
> **Neutrality.** Architecture, dependency manager, backend/data, and test framework are presented as *open decisions* with neutral trade-offs, not prescriptions. Where something is Apple-official it is cited to a primary source; where it is community convention it is labeled **[Convention]**.
>
> **Tailoring context.** "AppName" is a shared family space (collect and connect things a family wants to do and give together), public-but-proprietary repo. Multi-user / shared-data and "family" framing surface specific App Store rules, flagged inline.
>
> **Provenance.** Every claim below was checked against Apple primary sources with live web access during the advisor review on **2026-06-09** (HIG, Technology Overviews, SwiftUI/SwiftData/CloudKit framework references, WWDC25 session pages, Xcode 26 release notes, App Store Review Guidelines, App Store Connect Help, TN3183, swift.org). Items that could not be confirmed against a primary source are explicitly labeled **Unconfirmed**; everything else is verified. See the "Advisor review notes" section at the end for what changed versus the prior draft.

---

## 0. The one-paragraph answer

Create the project in **Xcode 26** (which includes **Swift 6.2** and the iOS / iPadOS / macOS 26 SDKs) with the **Multiplatform → App** template (single shared target, multiple destinations: iPhone, iPad, and a native Mac destination). Write it in **Swift 6** with strict concurrency (Swift 6.2 adds "approachable concurrency" easements), **SwiftUI** lifecycle (`App` / `Scene` / `WindowGroup`), state via the **Observation** framework (`@Observable` / `@State` / `@Bindable` / `@Environment`) — Apple prescribes *no* MVVM/TCA. Adopt **Liquid Glass** only through real system APIs (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)` / `.glassProminent`, `glassEffectID`) and only in the navigation/control layer. Use **Swift Package Manager** for dependencies and to modularize your own code into local packages. For a multi-user "family" app the data layer is the hard architectural call: **CloudKit** (with `CKShare`) or a **custom server** support real cross-person sharing; **SwiftData/Core Data on the private CloudKit database does not share data between different people** (it only syncs one person's own devices). From day one you must have an **Apple Developer Program** membership, a permanent **bundle ID**, **automatic code signing** with secrets kept out of git, an **App Store Connect** record, a **Privacy Manifest** + **App Privacy** labels, **encryption export compliance** set, correct **versioning**, and — because of accounts/UGC/"family" framing — **in-app account deletion**, **UGC moderation + age-gating**, and a deliberate **Kids Category** posture.

---

## 0.5 Decisions locked (2026-06-09)

Recorded from the project owner. These resolve several day-1 items and narrow the open decisions.

> The decisions below are now tracked as canonical Architecture Decision Records under [`../adr/`](../adr/README.md). This table stays as the original lock log and ties each choice to the evidence sections that follow; when a decision changes, supersede its ADR rather than rewriting this table.

| Topic | Decision | Status |
|-------|----------|--------|
| Apple Developer Program | Enrolled | ✅ Have |
| Bundle identifier | `dev.hapd.appname` (from `appname.hapd.dev`) | ✅ Xcode project created with it |
| Xcode project | Created (`dev.hapd.appname`) | ✅ Done |
| Versioning | Same scheme as GitHub releases (repo `vX.Y.Z` tags) | ✅ Decided |
| Login method | **Sign in with Apple only** for now; no other methods needed | ✅ Decided (satisfies guideline 4.8; triggers in-app account-deletion requirement — see §8.7) |
| CI | **Xcode Cloud** (Apple first-party) | ✅ Decided |
| Localization | English by default; design for localization from day 1 (String Catalogs); other languages = backlog tasks | ✅ Direction set |
| App icon | Backlog (OS 26 / Icon Composer) | 📋 Backlog |
| All SHOULD-HAVEs (§9) | Accepted | ✅ Yes |
| Test framework | **Swift Testing** for unit/logic; XCTest only for UI automation (XCUITest) + performance | ✅ Decided (§3.1) |
| Architecture | Apple **`@Observable` model-view ("MV")**; add a per-screen ViewModel only when a screen earns it; no TCA | ✅ Decided (§4) |
| Dependency policy | **SPM only; zero third-party deps to start**, add only when a concrete need beats first-party (each reviewed for privacy-manifest + maintenance cost) | ✅ Decided (§6) |
| Data / persistence / sync | **CloudKit** (advisor-verified): local store as source of truth + CloudKit sync + `CKShare` family sharing, via Core Data + `NSPersistentCloudKitContainer`, `encryptedValues` for sensitive fields | ✅ Decided (§5) |
| Push notifications | **APNs via CloudKit** (remote-notifications + CloudKit capability) for background sync and share invitations; no separate push backend | ✅ Decided (§5) |
| Observability / crash / analytics | **First-party only:** `OSLog` for logging, **MetricKit** for metrics/diagnostics, Xcode Organizer crash reports, App Store Connect analytics. No Crashlytics/Sentry/third-party SDK (zero-deps + privacy) | ✅ Decided |
| AI | **Pure-Apple, no AI in v1.** Later, on-device **Foundation Models** only (`SystemLanguageModel`, optionally Private Cloud Compute); no third-party/cloud LLM (would break zero-deps + need a backend) | ✅ Decided (§5) |
| Monetization | **Free, no in-app purchases** for v1; wire StoreKit 2 later only if a concrete need appears | ✅ Decided |
| Age rating / Kids Category | **General 4+ family app; NOT the Kids Category.** Accounts require an Apple ID (Sign in with Apple), shared data is adult-managed; avoids the Kids analytics/ad ban and parental-gate burden (1.3 / 5.1.4) | ✅ Decided (§8.7) |
| Support + privacy-policy hosting | **`appname.hapd.dev`** (already owned): marketing site + App Store support URL + privacy policy in one place | ✅ Decided (§8.7) |
| CI lanes | **Two complementary lanes:** Xcode Cloud = build/test/sign/TestFlight/App Store; GitHub Actions = repo gates (gitleaks, guard, pr-check, codeql) + `vX.Y.Z` tag-push release | ✅ Decided (§8.8) |
| In-app search | Local Core Data predicates + indexes for structured filter/sort; **Core Spotlight** (`NSCoreDataCoreSpotlightDelegate`, `CSSearchQuery`) for text search + OS-level Spotlight/Siri discovery. No raw SQLite FTS5 — it fights the CloudKit mirroring | ✅ Decided |
| File / attachment storage | **`CKAsset`** via Core Data "Allows External Storage"; the asset lives in the **owning record's** iCloud (owner's quota), encrypted by default. App deletion removes the local copy only and re-syncs on reinstall; permanent loss only if the **owner** deletes their iCloud data/account — ties to share/zone teardown (§8.7) | ✅ Decided (§5) |
| On-device AI substrate | Local-first store is the enabler: private, no-network AI reads local data directly. Add-ons when AI lands — Foundation Models (generation/extraction), `NLEmbedding` (on-device semantic search, vectors stored in Core Data), Core ML, App Intents/Spotlight. No cloud vector DB needed at family scale | ✅ Decided (§5) |
| Testing strategy | Two native layers: (1) **protocol-isolate CloudKit** → Swift Testing with an in-memory double = headless, deterministic, agent-loop-friendly (covers ~all logic); (2) real iCloud account(s) on signed builds for CloudKit/`CKShare` integration, the Mac app driven via computer-control. No headless CloudKit harness exists — integration is inherently device+account based | ✅ Decided (§3.1) |
| Project file / agent ergonomics | Keep the single `.xcodeproj`; it already uses **filesystem-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`, Xcode 16+), so adding a `.swift` file needs **no** pbxproj edit and causes no per-file merge conflict. No Tuist/XcodeGen (they would replace a working native feature). Local SPM packages remain optional, justified by build time / module boundaries if the app grows — not by pbxproj churn | ✅ Decided (§7) |
| CloudKit env promotion | dev/Xcode builds use the CloudKit **Development** environment; **TestFlight + App Store use Production**. The schema must be deployed **Development → Production** in the CloudKit Dashboard before the first external-TestFlight/production build, or testers hit an empty/mismatched schema | ✅ Decided (§8.8) |

**All four originally-open decisions are now resolved.** Architecture, dependency policy, test framework, and data/sync are decided above; details in §4, §6, §3.1, and §5.

**Full-stack closure (2026-06-09).** Beyond those four, the remaining cross-cutting choices needed to take AppName from project creation to App Store ship-and-maintain are now locked in the rows above: push, observability, AI posture, monetization, age rating / Kids Category, support + privacy-policy hosting, and the two-lane CI split. No stack decision remains open; what is left is execution. The implementation-level rows added the same day — in-app search (Core Spotlight), file/attachment storage (`CKAsset`) and its app-deletion vs owner-deletion semantics, the on-device AI substrate, the two-layer testing strategy, project-file/agent ergonomics (filesystem-synchronized groups, no Tuist), and CloudKit Dev→Prod schema promotion — record how the locked stack is built and tested, not new forks.

**Day-1 consequence of "Sign in with Apple only" + CloudKit:** because account creation exists, in-app **account deletion** is mandatory (§8.7). With the CloudKit + `CKShare` model, deletion must also handle **share ownership/transfer and zone teardown** — when a member who owns shared wishlists/zones deletes their account, their shares and zones must be transferred or torn down without orphaning other participants' views. Design this into the data model from the start.

---

## 1. Liquid Glass (official)

### 1.1 What it is
Apple defines **Liquid Glass** (introduced at WWDC25, shipping in OS 26) as a new digital *meta-material* that dynamically bends and shapes light and "behaves and moves organically… like a lightweight liquid, responding to both the fluidity of touch and the dynamism of modern apps." It is the unifying design language across iOS 26, iPadOS 26, macOS 26, watchOS 26, tvOS 26, and visionOS 26. *(Verified — WWDC25 session 219 "Meet Liquid Glass"; Technology Overviews "Liquid Glass".)*

There are **two material variants**: **regular** glass (legible by default) and **clear** glass (used where media sits behind it, e.g. AVKit; requires extra care for legibility). *(Verified — Technology Overviews "Liquid Glass".)*

### 1.2 Where to use it — and where NOT to
- **Use it in the navigation/control layer that floats *above* content** — bars, toolbars, tab bars, sidebars, floating controls. *(Verified — HIG "Materials" + WWDC25 s219.)*
- **Never put Liquid Glass in the content layer.** Apple: *"including it in the content layer can result in unnecessary complexity and a confusing visual hierarchy."* *(Verified — HIG.)*
- **Never stack glass on glass.** Apple: *"always avoid glass on glass. Stacking Liquid Glass elements… can quickly make the interface feel cluttered and confusing."* *(Verified — WWDC25 s219.)*
- **Reduce custom backgrounds on bars/controls.** Apple: *"Any custom backgrounds and appearances you use in these elements might overlay or interfere with Liquid Glass or other effects that the system provides."* *(Verified — "Adopting Liquid Glass".)*
- **Use custom glass sparingly.** Apple: *"Avoid overusing Liquid Glass effects… Limit these effects to the most important functional elements in your app."* *(Verified — "Adopting Liquid Glass".)*

**Implication for AppName:** glass goes on chrome (nav bars, tab bar, floating "add" controls). The family-content surfaces (lists of things to do/give, cards) stay in the content layer with standard backgrounds/materials.

### 1.3 The genuine system APIs (SwiftUI)
**Verified against the SwiftUI reference "Applying Liquid Glass to custom views" and the symbol pages.** All of the following are real OS 26 SDK APIs (iOS/iPadOS/macOS 26.0+):

| API | Verified signature / form | Purpose |
|-----|---------------------------|---------|
| `glassEffect(_:in:)` | `func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View` | Apply Liquid Glass to a view. **Default variant `.regular`; default shape `DefaultGlassEffectShape()`, which renders as a capsule** (verified against the symbol page, 2026-06-09). |
| `Glass` | struct with `.regular`, `.clear`, and `.identity` variants | The material configuration. `.identity` applies no effect; chainable with `.tint(_:)` and `.interactive(_:)`. |
| `Glass.tint(_:)` | `func tint(_ color: Color?) -> Glass` | Assign a tint color to suggest prominence. |
| `Glass.interactive(_:)` | `func interactive(_ isInteractive: Bool = true) -> Glass` | Make the glass react to touch/pointer with the same responsiveness as `.buttonStyle(.glass)`. |
| `GlassEffectContainer(spacing:)` | `GlassEffectContainer(spacing: CGFloat? = nil) { … }` | Group multiple glass shapes so they blend/morph and render efficiently. The optional `spacing` controls how nearby glass effects interact. |
| `glassEffectID(_:in:)` | `func glassEffectID(_ id: (some Hashable & Sendable)?, in namespace: Namespace.ID) -> some View` | Identify glass elements (with `@Namespace`) so they **morph** fluidly during transitions (e.g. a control expanding into a panel). |
| `glassEffectUnion(id:namespace:)` | `func glassEffectUnion(id: (some Hashable & Sendable)?, namespace: Namespace.ID) -> some View` | Merge adjacent glass shapes of similar shape/effect/ID into one visual unit. |
| `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` | `PrimitiveButtonStyle.glass`, `PrimitiveButtonStyle.glassProminent` (backed by `GlassButtonStyle`) | Liquid Glass button styles (standard vs prominent/tinted). |

**Worked example (verified against Apple's documentation code):**
```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(.regular.tint(.orange).interactive(), in: .rect(cornerRadius: 16.0))
```

**Note on signature shape (resolved 2026-06-09).** The current SwiftUI reference documents the two-parameter form `glassEffect(_ glass:in:)` as the only modifier; there is **no** `glassEffect(_:in:isEnabled:)` overload (the symbol page lists a single declaration). Treat `glassEffect(_:in:)` as canonical. For conditional glass, wrap the modifier in an `if` or a small `ViewModifier`, or use `Glass.interactive(_:)` to toggle touch response.

**Additional Liquid Glass APIs (verified 2026-06-09):** `GlassEffectTransition` (`.materialize`, the default within a container, and `.matchedGeometry` for far-apart views) applied via `.glassEffectTransition(_:)`; a `buttonStyle(.glass(_:))` overload taking a configured `Glass` (for example `.glass(.regular.tint(.orange))`); and the `UIDesignRequiresCompatibility` Info.plist key, which forces the pre-26 appearance even when built against the 26 SDK (AppName is greenfield and must never set it). No Liquid Glass API changed across the 26.1-26.5 point releases.

Which standard components auto-adopt Liquid Glass (verified — "Adopting Liquid Glass"): *"If your app uses standard components from SwiftUI, UIKit, or AppKit, your interface picks up the latest look and feel."* Named explicitly: SwiftUI `NavigationStack`, `NavigationSplitView`, `WindowStyle.titleBar`, and `View.toolbar(content:)`; UIKit `UINavigationBar` / `UITabBar` / `UIToolbar` / `UISplitViewController`; AppKit `NSToolbar` / `NSSplitView`. Apple summarizes: *"standard components like bars, sheets, popovers, and controls automatically adopt this material."* So `TabView`, toolbars, sheets, popovers, alerts, and search get the look for free; custom `glassEffect` is for bespoke floating controls.

UIKit/AppKit button equivalents (for reference if you ever drop down): `UIButton.Configuration.glass()` / `.prominentGlass()` / `.clearGlass()` / `.prominentClearGlass()`; `NSButton.BezelStyle.glass`. *(Verified — "Adopting Liquid Glass".)*

### 1.4 Cross-platform behavior
The material is shared across platforms but expresses differently per idiom. Documented per-platform notes from "Adopting Liquid Glass":
- **watchOS:** Liquid Glass changes are minimal and appear automatically on the latest release even without building against the latest SDK; to be safe, adopt standard toolbar APIs and button styles from watchOS 10.
- **tvOS:** standard buttons/controls take on Liquid Glass when focus moves to them; Apple TV 4K (2nd gen) and newer support the effects, older devices keep the current appearance.
- **iPadOS:** apps show window controls and support continuous (fluid) window resizing down to a minimum size.

For AppName's three targets (iPhone/iPad/Mac), there is **no documented behavioral difference that requires per-platform glass code**: standard components adapt automatically, and the same `glassEffect` APIs apply across iOS, iPadOS, and macOS 26. The expression differs by idiom (macOS sidebars/toolbars vs iOS tab bars), but that is handled by using the right standard containers, not by branching on platform.

### 1.5 Accessibility (load-bearing for the "never fake it" rule)
When you use the **real system material**, accessibility adaptations are applied **automatically and system-wide** — no per-app code. *(Verified — WWDC25 s219: "available automatically whenever you use the new material… across the board.")*
- **Reduce Transparency** → material becomes frostier/more opaque. *(Verified — WWDC25 s219.)*
- **Increase Contrast** → elements render with a contrasting (black/white) border. *(Verified — WWDC25 s219.)*
- **Reduce Motion** → reduces or removes the fluid morphing/shimmer animation. *(Verified — "Adopting Liquid Glass": "people can… turn on accessibility settings that reduce transparency or motion in the interface. These settings can remove or modify certain effects." Reduce Motion is named as one of the settings to test against.)*

Apple's instruction: *"Test your interface with a variety of display and accessibility settings… Ensure you test your app's custom elements, colors, and animations with different configurations of these settings."* *(Verified — "Adopting Liquid Glass".)*

**Why this kills "fake glass":** a blur/gradient imitation forfeits these automatic adaptations and would fail Reduce-Transparency / Increase-Contrast / Reduce-Motion users unless hand-reimplemented. This is the concrete, Apple-grounded reason the project's "Liquid Glass only, never fake it" rule is correct.

### 1.6 Why a true OS 26 floor is required
The Liquid Glass APIs exist only in the OS 26 SDK; there is no back-deployment (except the minimal, automatic watchOS case noted above, which is irrelevant to AppName). Building against OS 26 with deployment target 26 is what unlocks both the automatic component adoption and the explicit `glassEffect` APIs.

**Primary sources** *(all resolve as of 2026-06-09)*
- HIG, "Materials": https://developer.apple.com/design/human-interface-guidelines/materials
- Technology Overviews, "Liquid Glass": https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass
- Technology Overviews, "Adopting Liquid Glass": https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- SwiftUI reference, "Applying Liquid Glass to custom views": https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- WWDC25 session 219, "Meet Liquid Glass": https://developer.apple.com/videos/play/wwdc2025/219/
- WWDC25 session 323, "Build a SwiftUI app with the new design": https://developer.apple.com/videos/play/wwdc2025/323/

---

## 2. SwiftUI multiplatform app structure (official)

### 2.1 One target or several?
Apple's supported path is a **single multiplatform app target** that declares **multiple destinations** (iPhone, iPad, Mac). Xcode's **Multiplatform → App** template creates exactly this: one shared codebase, one target, destinations added per platform; you conditionalize settings/code where platforms diverge. Apple's reference: *"Configuring a multiplatform app."* Separate targets are only warranted when platforms diverge so much that sharing hurts more than helps. *(Verified — "Configuring a multiplatform app target"; sample app "Food Truck: Building a SwiftUI multiplatform app.")*

For the Mac destination, prefer the native **"Designed for Mac"** destination (a true Mac app) over **"Designed for iPad"** (runs the unmodified iOS app on Apple silicon) or **Mac Catalyst**. Xcode allows more than one Mac destination, which is useful when transitioning between these. *(Verified — "Configuring a multiplatform app target.")*

### 2.2 App lifecycle
- `@main struct AppNameApp: App { var body: some Scene { … } }`
- **Scenes:** `WindowGroup` (primary, multi-window capable on iPad/Mac), plus macOS-specific scenes: `Settings`, `MenuBarExtra`, `Window`, `DocumentGroup` (if document-based).
- **Multiple windows** come largely for free from `WindowGroup` on iPad/Mac; `@Environment(\.openWindow)` opens new ones.

### 2.3 Adaptive layout
- **`NavigationSplitView`** for two/three-column layouts that collapse to a stack in compact width (iPhone, narrow iPad multitasking) — the canonical adaptive container for a "library + detail" app like AppName.
- **`NavigationStack`** for push/pop flows.
- **Size classes** (`@Environment(\.horizontalSizeClass)`) and layout tools (`Grid`, `ViewThatFits`, `.containerRelativeFrame`) for adaptation. Prefer adaptive APIs over `#if os(...)` conditionals; reserve conditionals for genuinely platform-specific affordances.

**Primary sources**
- "Configuring a multiplatform app target": https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target
- "App organization" (SwiftUI): https://developer.apple.com/documentation/swiftui/app-organization
- HIG "Layout": https://developer.apple.com/design/human-interface-guidelines/layout

---

## 3. Language + tooling stack (OS 26 era)

| Item | Value | Notes |
|------|-------|-------|
| **Xcode** | **Xcode 26** | "Xcode 26 includes Swift 6.2 and SDKs for iOS 26, iPadOS 26, tvOS 26, watchOS 26, macOS Tahoe 26, and visionOS 26." Requires a Mac running **macOS Sequoia 15.6 or later**. *(Verified — Xcode 26 Release Notes.)* |
| **Swift** | **Swift 6.2** (shipped in Xcode 26) | *(Verified — Xcode 26 Release Notes overview.)* |
| **Language mode** | **Swift 6** language mode = complete data-race safety / strict concurrency, set via the Swift Language Version build setting. | Swift 6 mode makes data-race safety errors compile-time. |
| **Concurrency easements** | Swift 6.2 "approachable concurrency" | Feature flags grouped under Approachable Concurrency: `NonisolatedNonsendingByDefault` (introduces `nonisolated(nonsending)` and `@concurrent`, SE-0461), plus `DisableOutwardActorInference`, `GlobalActorIsolatedTypesUsability`, `InferIsolatedConformances`, `InferSendableFromCaptures`. A separate **default actor isolation** option can isolate a module to the **main actor by default** (ideal for UI/app targets). *(Verified — swift.org "Swift 6.2 Released"; Swift compiler diagnostics docs.)* |
| **Strict Memory Safety** | Optional Swift 6.2 feature | Xcode 26 release notes reference "the Strict Memory Safety feature introduced in Swift 6.2." Opt-in. |
| **Deployment target** | iOS 26 / iPadOS 26 / macOS 26 | Set per destination. |
| **Testing** | **Swift Testing** (new) + **XCTest** (still required for UI/perf) | See below. |

### 3.1 Swift Testing vs XCTest (Apple's current positioning)
- **Swift Testing** (`@Test`, `#expect`, `#require`, `@Suite`, parameterized tests, traits) is Apple's modern test framework, included in Xcode's test targets and actively expanded in Xcode 26 (e.g. **exit tests** for code that calls `precondition()`/`fatalError()`, attachments, issue-handling traits). Apple positions it as the recommended framework for **new** unit tests. *(Verified — Xcode 26 Release Notes, "Testing" section.)*
- **XCTest** remains supported and is still required for **UI automation** (XCUITest) and **performance** tests. The two coexist in the same target; Xcode 26 adds runtime-issue detection across both.

**Primary sources**
- Xcode 26 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes
- Swift 6.2 release: https://www.swift.org/blog/swift-6.2-released/
- Swift migration / concurrency guide: https://www.swift.org/migration/documentation/migrationguide/
- Swift Testing: https://developer.apple.com/documentation/testing/

---

## 4. Architecture + state (neutral; Apple-official vs convention)

### 4.1 Observation is the official state model
The **Observation** framework (`@Observable` macro) is Apple's current SwiftUI state model:
- `@Observable` on a reference-type model → SwiftUI tracks only the properties a view actually reads.
- `@State` owns a model instance's lifetime in a view.
- `@Bindable` creates two-way bindings to an `@Observable` object's properties.
- `@Environment` injects shared `@Observable` models down the tree.

This supersedes the older `ObservableObject` / `@Published` / `@StateObject` pattern for new code. *(Verified — Observation framework reference; "Managing model data in your app.")*

### 4.2 Apple does NOT prescribe an app architecture
Apple's documentation and sample code do **not** mandate MVVM, VIPER, or TCA. Apple's samples generally show a pragmatic **model + SwiftUI view** approach: `@Observable` model types injected via `@Environment`, views reading/mutating them directly (sometimes called "MV"). **MVVM** is a **[Convention]** many teams layer on; **TCA** (The Composable Architecture, Point-Free) is a **[Convention]** third-party framework. None is required by Apple.

**Recommendation posture for AppName (neutral):** start with Apple's `@Observable` model-view approach; introduce a view-model layer only where view logic genuinely warrants it. Defer TCA unless the team already knows it — it is a large dependency and a paradigm commitment. (Architecture remains an open decision.)

**Primary sources**
- Observation: https://developer.apple.com/documentation/observation
- "Managing model data in your app": https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app

---

## 5. Data / persistence / sync (RESOLVED — chosen architecture)

**Decision (advisor-verified 2026-06-09):** local store as the source of truth + CloudKit as sync transport + `CKShare` for family sharing + `encryptedValues` for sensitive fields. Pure Apple, zero third-party dependencies.

### Principle
The **local store is the source of truth** and the query engine (SQL, indexes, full-text search, joins, sort, offline). **CloudKit is the sync transport, not the query layer** — never run app-logic queries against CloudKit; mirror in the background and query locally. This also neutralizes CloudKit's weak server-side querying and its inability to index encrypted fields.

### Container and databases
One CloudKit container, two relevant scopes:
- **Private database** — the user's own data. It counts toward the **user's** iCloud storage quota, not the developer's. *(Verified — CKContainer private database doc.)*
- **Shared database** — a per-participant view into another user's private DB, populated when that user shares records. `NSPersistentCloudKitContainer` can mirror both scopes with two stores (one `.private`, one `.shared`).

Shareable records must live in a **custom record zone** in the private database (the default zone is not shareable); custom zones also give reliable per-zone change tracking. *(Verified — CKShare / shared-records docs.)*

### Chosen path for AppName (pure-Apple)
**Core Data + `NSPersistentCloudKitContainer` with sharing** (recommended default):
- Mirrors the local Core Data store to CloudKit across the user's own devices (private DB) automatically.
- Supports **true cross-person sharing**: create a share with `share(_:to:completion:)`, accept with `acceptShareInvitations(from:into:completion:)`, manage participants with `addParticipant(_:)` / `removeParticipant(_:)`, persist with `persistUpdatedShare(_:in:completion:)`. Each share gets its own CloudKit record zone. Present sharing UI with `UICloudSharingController` (macOS: `NSSharingService`). Per-participant permission is read-only or read-write via `CKShare.Participant.permission`. *(Verified — "Sharing Core Data objects between iCloud users.")*

**Fallback: `CKSyncEngine` + your own store** (e.g. SQLite). You own the schema and local DB; `CKSyncEngine` handles change tokens, batching, retries, and push-driven sync (persists `CKSyncEngine.State.Serialization`; needs the remote-notifications capability). More control, more code. Choose only if `NSPersistentCloudKitContainer`'s model constraints become a problem.

### Where SwiftData fits (and where it does not)
**SwiftData + CloudKit auto-sync covers only one person's own devices (private DB); it does NOT share data between different people** — WWDC25 added only model inheritance + schema migration, not shared/public DB. So the **shared family data lives in the Core Data + CloudKit stack.** SwiftData may still be used for purely local, single-user data that never needs cross-person sharing, but mixing both adds surface — for v1, standardizing on Core Data + `NSPersistentCloudKitContainer` for everything shared is the simpler call. (Note the CloudKit-mirroring model constraints: no `@Attribute(.unique)`, all relationships optional, no `deny` delete rule, explicit inverses.) Re-verified 2026-06-09: `ModelConfiguration.CloudKitDatabase` still exposes only `.automatic` / `.private` / `.none` (no `.shared` or `.public`), and the June-2026 SwiftData additions (sectioned `@Query`, a `.codable` option, `ResultsObserver`, `HistoryObserver`) add no cross-person sharing, so the Core Data choice stands and matches Apple's own "Sharing Core Data objects between iCloud users" sample.

### Sharing shape
A `CKShare` can cover **either** a whole record zone **or** a specific record **hierarchy** (root record + descendants). For a wishlist (list + its items) **share the hierarchy**, not the whole zone, so unrelated lists are not dragged in. A record can be in only one share. Invitations go through the native share sheet; recipients resolve to Apple (iCloud) accounts; each participant needs an active iCloud account. **No invite-link backend** — CloudKit hosts the share URL and invitation flow.

**Sharing constraints (verified 2026-06-09).** `NSPersistentCloudKitContainer` moves the **entire object graph** of a shared object into the share's zone, and it **does not allow relating objects that belong to different shares** — so model AppName so items in different families carry no direct Core Data relationship to each other. CloudKit caps zones per database, so funnel shared content into a few shares (for example one per family group) with an "add to existing share" path, rather than a zone per item. Since iOS 16.4 the container auto-observes the system sharing UI and updates share state, so on the OS 26 floor no manual accept-share delegate is required. Encrypted fields decrypt for participants too when Advanced Data Protection is on.

### Gift-claim partitioning (design note — decide before building the schema)
In a shared zone/hierarchy every participant sees the same records, and a writer's changes are visible to all. So **"this gift is already claimed/bought" must NOT live on the shared wishlist-item record**, or the wishlist owner would see the spoiler. Partition it: keep claim status where the owner cannot read it (a separate share/zone among gift-givers the owner is not a participant of; or claim state kept local to each giver and never synced into owner-visible records; or "claim" modeled as records the owner is excluded from at the share level). Hard to retrofit.

### Encryption
- CloudKit is encrypted in transit and at rest by default. **`encryptedValues`** adds end-to-end encryption: encrypted on-device before save, decrypted after fetch, keys rooted in the user's **iCloud Keychain** (never on Apple servers); for shared records, keys go to the share's participants.
- **Eligible encrypted types:** strings, numbers, dates, data, location, arrays (`NSString`, `NSNumber`, `NSDate`, `NSData`, `CLLocation`, `NSArray`).
- **`CKAsset`** is encrypted by default, so it cannot be placed in `encryptedValues`. (Apple says "encrypted by default"; it does not literally label assets "end-to-end" on that page.)
- **`CKReference` is never encrypted** (the server must read it to resolve relationships) — never put sensitive data in a reference.
- Encrypted fields cannot be indexed, so they cannot appear in CloudKit query predicates/sort descriptors. **Non-issue here because all querying is local.**
- **iCloud Keychain reset caveat:** if the user loses or resets iCloud Keychain, the key material is gone and encrypted data is **permanently unrecoverable** (often surfaced as `zoneNotFound`). Design an explicit error path; do not assume encrypted data is always recoverable.

### On-device AI (Foundation Models) — optional, NOT v1
Not required for v1, and the partner-model path conflicts with the zero-dependency stance. If added later, the **Foundation Models framework** exposes Apple's on-device LLM from Swift (no API keys, no cloud cost, offline) with **guided generation** (`@Generable` typed output), tool calling, and streaming. The on-device model suits summarization, extraction, classification, and short generation, not broad world knowledge or heavy reasoning (the WWDC25 on-device model was ~3B params / 4,096-token context; the WWDC26 generation is larger).

**Provider story and OS gating (verified 2026-06-09).** On the OS 26 floor only the **on-device `SystemLanguageModel`** is available (iOS/iPadOS/macOS 26.0+), and only when the user has **Apple Intelligence enabled** — gate features on `SystemLanguageModel.default.availability` (or `.isAvailable`) and handle `.unavailable(.appleIntelligenceNotEnabled / .deviceNotEligible / .modelNotReady)`. The on-device model has a **4,096-token** context and fits summarization, extraction, classification, tagging, and short generation, not broad world knowledge; a specialized `SystemLanguageModel(useCase: .contentTagging)` variant tags topics/actions/objects on-device. Typed output uses `@Generable` (structs and enums only) with `@Guide`; streaming yields a `Partial`. The `PrivateCloudComputeLanguageModel` and the `LanguageModel` protocol for third-party providers (Anthropic, Google) are **iOS/macOS 27.0 beta, not available on the 26 floor** (PCC needs the `com.apple.developer.private-cloud-compute` entitlement). So for AppName v1 the only option is the on-device model; partner packages would reintroduce third-party deps, auth, and billing, and stay out of scope regardless.

**Primary sources**
- Encrypting user data (`encryptedValues`, eligible types, `CKAsset`, `CKReference`, indexes, Keychain reset): https://developer.apple.com/documentation/cloudkit/encrypting-user-data
- Shared records (hierarchy vs zone): https://developer.apple.com/documentation/cloudkit/shared-records
- `CKShare` (custom zone, participants, permissions, `UICloudSharingController`): https://developer.apple.com/documentation/cloudkit/ckshare
- "Sharing Core Data objects between iCloud users": https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users
- `NSPersistentCloudKitContainer`: https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer
- `CKSyncEngine`: https://developer.apple.com/documentation/cloudkit/cksyncengine
- Private database (quota): https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase
- SwiftData + CloudKit constraints: https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
- Foundation Models framework: https://developer.apple.com/documentation/foundationmodels
- WWDC26 "Bring an LLM provider to the Foundation Models framework": https://developer.apple.com/videos/play/wwdc2026/339/

---

## 6. Dependencies (official)

- **Swift Package Manager (SPM)** is Apple's first-party dependency manager, integrated directly into Xcode (*File → Add Package Dependencies…*). It is the default and recommended choice. *(Verified — swift.org Package Manager; "Adding package dependencies to your app.")*
- **Apple's posture:** prefer first-party frameworks; add third-party dependencies sparingly (each is attack surface, privacy-manifest burden, and a maintenance/ABI risk).
- **Modularize your own code** into **local Swift packages** — improves build times, enforces boundaries, and enables previews per feature. **[Convention but consistent with Apple sample structure.]**
- **CocoaPods** is in maintenance mode and is going **read-only**: its trunk will permanently stop accepting new or updated Podspecs on **December 2, 2026** (read-only milestones already in progress through 2025-2026). **Carthage** is legacy. New projects should use SPM and not adopt these. *(Verified — CocoaPods blog "Trunk Read-only Plan." Note: the read-only date is a CocoaPods-published plan, not an Apple source.)*

**Primary sources**
- SPM: https://www.swift.org/package-manager/
- "Adding package dependencies to your app": https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app

---

## 7. Repo / project structure (official + flagged convention)

### 7.1 Creating the project
Xcode → **File → New → Project → Multiplatform → App**. This yields a `.xcodeproj`, a single multiplatform target, an `Assets.xcassets`, and a SwiftUI `App` entry point. *(Apple-official template.)*

### 7.2 Project file vs package vs workspace
- **`.xcodeproj`** — standard for an app. *(Official.)*
- **`.xcworkspace`** — Xcode creates an implicit workspace when you add local Swift packages; you rarely hand-author one for a single app. *(Official behavior.)*
- **"Thin app + everything in a local SPM package"** (app target is a shell; features live in a `Packages/` SwiftPM package) — a popular **[Convention]** (Point-Free / modularization style), not Apple-mandated. Good for large modular apps; overkill for a small one at the very start.

### 7.3 Folder/module organization **[Convention]**
A common, defensible layout:
```
AppName/
  AppName.xcodeproj
  App/                 # @main App, root scenes, app-level wiring
  Features/            # feature folders or local SPM packages (FamilySpace, Items, Sharing…)
  Core/                # models, persistence, networking, design system (Liquid Glass components)
  Resources/           # Assets.xcassets, String Catalogs, Icon Composer source
  Tests/               # Swift Testing + XCTest UI
  Secrets.xcconfig     # gitignored — team ID, non-secret build config (NEVER credentials in git)
  .gitignore
```
Apple does not prescribe folder names; the above is convention. Asset catalogs (`Assets.xcassets`) hold app icon, accent color, images, and named colors. From OS 26, app icons are authored with **Icon Composer**: a single design produces variants across **Default, Dark, and Mono** rendering modes, with adjustable depth/lighting. *(Verified — Xcode 26 Release Notes.)*

### 7.4 `.gitignore`
Use the GitHub **Swift**/**Xcode** template. Must ignore: `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `.build/`, `.swiftpm/`, and any `Secrets.xcconfig` / signing assets. The repo already ships a Swift `.gitignore` (per STATE.md) — confirm it covers `Secrets.xcconfig`.

---

## 8. App Store day-1 requirements (the critical section)

Distinguishing **MUST** (hard requirement / very hard to retrofit) from **SHOULD** (strong recommendation).

### 8.1 Account, identity, signing
- **Apple Developer Program** membership — **MUST** to use TestFlight or submit. The fee is **99 USD per membership year** (or local currency); enrolling via the Apple Developer app makes it an auto-renewable annual subscription, or you can purchase on the web. Fee waivers exist for nonprofits, accredited educational institutions, and government entities. Choose **Organization** (D-U-N-S) vs **Individual** deliberately; org enables team roles. *(Verified — "Apple Developer Program / What's Included"; "Fee Waivers.")*
- **Bundle identifier** — **MUST**, reverse-DNS, **permanent once shipped**. Pick before the first App Store Connect record. **Locked: `dev.hapd.appname`** (from the `appname.hapd.dev` site), Xcode project already created with this identifier.
- **Code signing** — **MUST**. Use **Automatically manage signing** in Xcode; Apple Development + Apple Distribution certificates and provisioning profiles are generated for you. **Keep signing assets/API keys OUT of git** — certificates in Keychain, App Store Connect API keys in CI secrets, build config in untracked `Secrets.xcconfig`.

### 8.2 App Store Connect + capabilities
- **App Store Connect app record** — **MUST** before any upload: name, primary language, bundle ID, SKU.
- **Capabilities / entitlements** — enable only what you use (iCloud/CloudKit, Push, App Groups, Sign in with Apple). Each adds an entitlement and an identifier capability. **MUST** match between Xcode and the App ID.

### 8.3 Privacy (multiple distinct obligations — do not conflate)
- **Privacy Manifest `PrivacyInfo.xcprivacy`** — **MUST**. Declares **Required Reason API** usage. There are **exactly five** categories — `NSPrivacyAccessedAPICategoryActiveKeyboards`, `…DiskSpace`, `…FileTimestamp`, `…SystemBootTime`, `…UserDefaults` — each entry a dict with **exactly two** keys (`NSPrivacyAccessedAPIType` = string category name; `NSPrivacyAccessedAPITypeReasons` = array of reason codes like `CA92.1`). *(Verified — TN3183.)* **`UserDefaults` is the one almost every app must declare.** The manifest also declares collected data types and tracking domains. Bundled third-party SDKs must ship their own manifests.
- **App Privacy "nutrition labels"** (in App Store Connect) — **MUST**. Separate from the manifest: you declare what data you collect, whether it's linked to identity, and whether used for tracking.
- **Usage-description strings** in Info.plist — **MUST** for any permission you request (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, etc.). Missing string = guaranteed rejection / crash.

### 8.4 Networking + crypto compliance
- **App Transport Security** — **MUST** use HTTPS; avoid ATS exceptions (they draw review scrutiny).
- **Encryption export compliance** — **MUST** resolve. Set **`ITSAppUsesNonExemptEncryption`** in Info.plist. Apple: set it to **`NO`** if your app "doesn't use encryption, or if it only uses forms of encryption that are exempt" — and "the use of encryption that's built into the operating system — for example, when your app makes HTTPS connections using `URLSession` — is exempt." Set to `YES` only if you use proprietary/non-exempt encryption. Setting `NO` skips the per-build self-classification prompt. *(Verified — "Complying with encryption export regulations.")*

### 8.5 Assets, Info.plist, versioning
- **App icon** — **MUST**. From OS 26, author with **Icon Composer** (single design → Default / Dark / Mono rendering modes); provide the 1024×1024 marketing icon. *(Verified — Xcode 26 Release Notes.)* The exhaustive list of pixel sizes required for OS 26 submission is **Unconfirmed** here (Icon Composer generates the needed renderings from one source; verify against the asset-catalog requirements in Xcode at submission time).
- **Info.plist** — display name, usage strings, `ITSAppUsesNonExemptEncryption`, scene config.
- **Versioning** — **MUST**: `CFBundleShortVersionString` (marketing, e.g. `1.0.0`) + `CFBundleVersion` (build, must increment every upload). See the repo's `vX.Y.Z` tag scheme.

### 8.6 Quality expectations (review + retention)
- **Accessibility** — **SHOULD** (and a review-quality expectation): VoiceOver labels, Dynamic Type, contrast. Liquid Glass gives you transparency/contrast/motion adaptations for free (§1.5) — don't undo them.
- **Localization readiness** — **SHOULD** from day 1: use **String Catalogs** (`.xcstrings`) even if shipping English-only; retrofitting hard-coded strings later is painful. (Xcode 26 adds type-safe Swift symbols and AI-generated comments for String Catalogs.)

### 8.7 Review Guidelines that bite a "family" app (conditional — design in early)
- **In-app account deletion** — **MUST if you offer account creation** (guideline 5.1.1). The option must be easy to find (typically account settings), delete the entire account record plus associated personal data, and must not force a phone call / email / support flow (outside highly regulated industries). *(Verified — Review Guidelines 5.1.1; "Offering account deletion in your app.")* For shared family data this means designing deletion/ownership-transfer of shared records up front.
- **UGC moderation + age-gating** — **MUST if users post content others see** (guideline 1.2). Need: a method for filtering objectionable content, a mechanism to report and act on offensive content (with timely action), the ability to block abusive users, and published contact info. *(Verified — Review Guidelines 1.2 "User-Generated Content.")*
- **Kids Category posture** — **decision MUST be made early** (guideline 1.3 / 5.1.4). If AppName opts into the Kids Category: it **must not** include third-party analytics or third-party advertising (narrow exceptions exist, and they must not transmit IDFA or any data that identifies a child, their location, or device). This constrains your SDK choices, so decide before adding any analytics dependency. *(Verified — Review Guidelines, Kids Category rules.)*
- **Sign in with Apple / third-party login** — guideline 4.8 ("Login Services"). The current rule is **neutral**: if your app uses a *third-party or social* login (Google, Facebook, etc.) to set up/authenticate the primary account, you must **also** offer an equivalent privacy-preserving login option (limits data collection to name + email, lets users keep email private, and does not collect interactions for advertising without consent). **Sign in with Apple satisfies this, but is no longer specifically mandated** — any login meeting those privacy properties qualifies. If AppName uses only its own email/password or only Sign in with Apple, 4.8 does not force an additional option. *(Verified — Review Guidelines 4.8; updated January 2024.)*
- **Complete metadata, no broken links, working demo account** for review — **MUST** at submission.

### 8.8 TestFlight + CI
- **TestFlight** — **Internal** testers: up to **100 App Store Connect users** with access to your content, no beta review; **External** testers: up to **10,000** people, requires a **Beta App Review**. A tester can install on up to **30 devices**; you can have up to **100 builds**. **Builds expire after 90 days.** *(Verified — TestFlight site + App Store Connect Help "TestFlight overview" / "Add internal testers".)*
- **CI / automated signing** — two official-ish paths:
  - **Xcode Cloud** — Apple's first-party CI, integrated with Xcode/App Store Connect, manages signing for you, with a free monthly compute allotment (exact current free-tier hours are **Unconfirmed** here; confirm on the Xcode Cloud page at setup time). Lowest setup friction.
  - **fastlane** — open-source; `match` (git-stored encrypted signing), `gym` (build), `pilot` (TestFlight), `deliver` (metadata). More control, runs on any CI (GitHub Actions). *(Note: project CLAUDE.md standardizes on GitHub-hosted runners; fastlane fits there, but macOS runners are the cost item.)* (Test framework + CI choice remain open decisions.)

**Primary sources**
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- "Offering account deletion in your app": https://developer.apple.com/support/offering-account-deletion-in-your-app/
- TN3183 (Required Reason APIs): https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest
- "Privacy manifest files": https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- App privacy details (nutrition labels): https://developer.apple.com/app-store/app-privacy-details/
- "Complying with encryption export regulations": https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
- Apple Developer Program / membership: https://developer.apple.com/programs/whats-included/
- TestFlight: https://developer.apple.com/testflight/
- App Store Connect Help, "TestFlight overview": https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- Xcode Cloud: https://developer.apple.com/xcode-cloud/

---

## 9. Day-1 checklist (ordered: project creation → first TestFlight build)

### MUST-HAVE (hard requirements / hard to retrofit)
1. **Apple Developer Program** membership active (org vs individual decided).
2. **Bundle ID** chosen (permanent, reverse-DNS) and registered.
3. Xcode 26 project from **Multiplatform → App**; deployment target = OS 26 on all destinations; Mac = native ("Designed for Mac") destination.
4. **Swift 6** language mode on; strict concurrency building clean (consider Swift 6.2 main-actor-by-default for the app target).
5. **Code signing = Automatic**; certificates/profiles generated; `Secrets.xcconfig` + signing assets **gitignored** (verify `.gitignore`).
6. **App Store Connect** app record created (name, bundle ID, SKU, primary language).
7. **`PrivacyInfo.xcprivacy`** added; declare `UserDefaults` (+ any other of the five Required-Reason API categories) with valid reason codes; collected-data types listed.
8. **`ITSAppUsesNonExemptEncryption`** set in Info.plist (`NO` if only OS HTTPS/standard crypto).
9. **App icon** authored (Icon Composer → Default/Dark/Mono) + 1024×1024; **versioning** (`CFBundleShortVersionString` + auto-incrementing `CFBundleVersion`) wired.
10. **Data-architecture decision made** (CloudKit+`CKShare` vs `NSPersistentCloudKitContainer` vs custom server vs SwiftData-private) — because models, sync, and account-deletion all hang off it, and SwiftData alone does not share between people.
11. If accounts: **in-app account deletion** designed (incl. shared-record ownership/transfer). If UGC: **filtering + reporting/blocking + published contact** designed. **Kids Category** posture decided (gates analytics/ad SDK choice).
12. First **TestFlight internal** build uploads, processes, and installs.

### SHOULD-HAVE (strong recommendations, cheaper now than later)
- **String Catalogs** (`.xcstrings`) from the start; no hard-coded UI strings.
- **Accessibility** baseline: VoiceOver labels, Dynamic Type, don't fight Liquid Glass's automatic contrast/transparency/motion adaptations.
- **SPM modularization** of features into local packages; minimal third-party deps (each adds privacy-manifest + Kids-Category constraints).
- **Swift Testing** target wired (XCTest only for UI/perf).
- **App Privacy nutrition labels** drafted in App Store Connect early (forces clarity on data collection).
- **CI** chosen (Xcode Cloud for lowest friction, or fastlane on GitHub Actions macOS runners) with automated TestFlight upload.
- **App Store Review Guidelines** + **HIG** skim by the whole team before building UI.

---

## 10. Open questions

### Still open — need a decision
**None.** All four originally-open decisions (architecture, dependency policy, test framework, data/sync) are resolved — see below. Remaining `[VERIFY]`/Unconfirmed items are minor code-time confirmations, not decisions.

### Closed / resolved
- **Data / persistence / sync** → **CloudKit**, advisor-verified (§5): local store as source of truth + CloudKit sync + `CKShare` family sharing via Core Data + `NSPersistentCloudKitContainer`, `encryptedValues` for sensitive fields, query locally. SwiftData alone cannot share cross-person; `CKSyncEngine` + own store is the heavier fallback. Couples to account deletion (share/zone teardown — §8.7, §0.5).
- **Architecture** → Apple **`@Observable` model-view ("MV")**: `@Observable` model/service types injected via `@Environment` or held with `@State`, views read/mutate directly; push logic into model/service types (clean to test with Swift Testing); add a per-screen ViewModel only where a screen earns it; no TCA (dependency + lock-in clash with the native-first, zero-deps posture). See §4.
- **Dependency policy** → **SPM only, zero third-party deps to start**; prefer first-party (URLSession, Swift Concurrency, MetricKit/OSLog, ShareLink) and add a dependency only when a concrete need beats first-party, each reviewed for privacy-manifest + maintenance cost. Splitting *own* code into local SPM packages is structure, not a dependency. See §6.
- **Test framework** → **Swift Testing** for unit/logic tests; XCTest kept only for what Swift Testing can't do yet (UI automation / performance). Both coexist in one target (§3.1).
- **Login** → Sign in with Apple only (§0.5). Triggers mandatory in-app account deletion (§8.7).
- **CI** → Xcode Cloud (§0.5). *Free-tier compute hours not pinned to a primary source — minor, confirm on the Xcode Cloud page at setup; not a blocker.*
- **Bundle ID / Dev Program / Xcode project / versioning / localization direction / SHOULD-HAVEs** → decided (§0.5).
- **App-icon size matrix for OS 26** → not a research blocker; a backlog TODO. Icon Composer generates renderings from one source; verify the exact required set in Xcode's asset catalog at icon-production time.
- **`glassEffect` `isEnabled:` overload** → **resolved 2026-06-09: it does not exist.** The SwiftUI symbol page lists a single declaration, `glassEffect(_:in:)`. For conditional glass use an `if` / `ViewModifier`, or `Glass.interactive(_:)`. Settled, nothing to decide.

### On the `glassEffect isEnabled:` question (explained + recommendation)
Many SwiftUI modifiers ship an `isEnabled: Bool` parameter so you can toggle an effect on/off *in place* without wrapping the view in an `if`. Branching with `if` changes a view's identity, which can cause layout jumps and broken animations; an `isEnabled` flag avoids that. The open question was simply: does `glassEffect` have such an overload (e.g. `glassEffect(_:in:isEnabled:)`) on top of the confirmed two-argument `glassEffect(_:in:)`?

**Recommendation:** do not design around it existing. Treat `glassEffect(_:in:)` as the API. When you need glass conditionally (e.g. only when *not* in Reduce Transparency, or only on a selected card), prefer a tiny reusable `ViewModifier` wrapper over scattering `if`s, and if Xcode 26 autocomplete shows an `isEnabled:` overload in your SDK, use it. It is a one-line code-time check, not a blocker and nothing to decide now.

---

*Verified-core provenance: HIG "Materials"; Technology Overviews "Liquid Glass" and "Adopting Liquid Glass"; SwiftUI "Applying Liquid Glass to custom views"; WWDC25 sessions 219/291/323; Xcode 26 Release Notes; swift.org "Swift 6.2 Released"; SwiftData "Syncing model data across a person's devices"; TN3183; App Store Review Guidelines (4.8, 5.1.1, 1.2, 1.3); "Complying with encryption export regulations"; TestFlight + App Store Connect Help; Apple Developer Program pages. All URLs verified to resolve on 2026-06-09.*

---

## Advisor review notes

### Corrected versus the prior draft
- **`glassEffect` signature.** Draft asserted `glassEffect(_:in:isEnabled:)` as the primary modifier. The current SwiftUI reference ("Applying Liquid Glass to custom views") documents `func glassEffect(_ glass: Glass = .regular, in shape: some Shape = Capsule())`. Demoted the `isEnabled:` form to Unconfirmed and made `glassEffect(_:in:)` canonical, with exact verified signatures for `Glass.tint(_:)`, `Glass.interactive(_:)`, `GlassEffectContainer(spacing:)`, `glassEffectID(_:in:)`, and `glassEffectUnion(id:namespace:)`.
- **Button styles.** Confirmed `.glass` / `.glassProminent` are `PrimitiveButtonStyle` values backed by `GlassButtonStyle` (iOS/iPadOS/macOS 26.0+), and added the UIKit/AppKit equivalents from "Adopting Liquid Glass."
- **Swift version.** Draft hedged "Swift 6 (Xcode 26 ships Swift 6.2 [VERIFY])." Confirmed exactly: Xcode 26 includes **Swift 6.2** and SDKs for iOS/iPadOS/tvOS/watchOS 26, macOS Tahoe 26, visionOS 26; requires macOS Sequoia 15.6+ (Xcode 26 Release Notes overview).
- **Swift 6.2 approachable concurrency.** Replaced the [VERIFY] with the real feature names from swift.org: `NonisolatedNonsendingByDefault` (`nonisolated(nonsending)`, `@concurrent`, SE-0461) plus the other Approachable Concurrency flags, and the separate main-actor-by-default isolation option. Added Strict Memory Safety as a Swift 6.2 opt-in.
- **WWDC session numbers.** Confirmed 219 "Meet Liquid Glass" and 323 "Build a SwiftUI app with the new design" (draft had 323 flagged [VERIFY]); added 291 "SwiftData: Dive into inheritance and schema migration."
- **SwiftData sharing (the biggest fix).** Draft hedged but leaned correct. Hardened it with a primary-source headline: SwiftData + CloudKit syncs only one person's devices (private DB), does **not** share between people, and WWDC25 added only model inheritance + schema migration, **not** shared/public DB support. Documented the exact CloudKit model constraints from "Syncing model data across a person's devices" (no `.unique`, all relationships optional, no `deny` delete rule). Promoted Core Data `NSPersistentCloudKitContainer` and direct `CKShare` as the supported sharing paths.
- **Guideline 4.8.** Corrected to the current neutral wording (updated Jan 2024): any equivalent privacy-preserving login satisfies it; Sign in with Apple qualifies but is no longer specifically mandated. Draft's "[VERIFY current 4.8 wording]" resolved.
- **CocoaPods status.** Updated from "maintenance mode (2024)" to the concrete, current fact: CocoaPods trunk goes **read-only on December 2, 2026** (flagged that this is a CocoaPods-published plan, not an Apple source).
- **Icon Composer.** Replaced [VERIFY] with the verified Xcode 26 description: single design → Default / Dark / Mono rendering modes with depth/lighting.
- **Encryption export.** Added Apple's exact exemption wording (OS-built-in HTTPS via `URLSession` is exempt → set `ITSAppUsesNonExemptEncryption` to `NO`).
- **Mac destination.** Clarified the three options by their real Xcode names: "Designed for Mac" (native, preferred) vs "Designed for iPad" vs "Mac Catalyst."
- **Doc URLs.** Fixed the "Adopting Liquid Glass" home to the Technology Overviews path `/documentation/TechnologyOverviews/adopting-liquid-glass` (it is a Technology Overviews article, not a SwiftUI reference page) and added the dedicated "Liquid Glass" Technology Overviews page, the SwiftUI "Applying Liquid Glass to custom views" reference, "Configuring a multiplatform app target," the SwiftData syncing page, and the Core Data / CloudKit sharing pages. Swapped the SwiftUI "app-organization" link to its current slug.

### Confirmed as-is (already correct in the draft)
- Liquid Glass is navigation-layer only, never content layer, never glass-on-glass (HIG + s219).
- Accessibility adaptations are automatic with the system material: Reduce Transparency → frostier, Increase Contrast → border. Added that **Reduce Motion** is also handled automatically (resolved the draft's [VERIFY]).
- Standard components auto-adopt (bars, sheets, popovers, controls, NavigationStack/SplitView, toolbars, TabView, search).
- TN3183: exactly five Required-Reason API categories, two-key dict structure.
- TestFlight limits: internal 100 (App Store Connect users), external 10,000, 90-day build expiry; added 30 devices/tester and 100 builds.
- Developer Program 99 USD/year; account deletion required for account-creation apps (5.1.1); UGC moderation + age-gating (1.2); Kids Category third-party-analytics/ads ban (1.3 / 5.1.4).
- Observation framework is the official state model; Apple prescribes no MVVM/TCA.
- SPM is the first-party manager; Carthage legacy.

### Still genuinely unconfirmed (web-verification record — all dispositioned in §10, none blocking)
- Whether a `glassEffect(_:in:isEnabled:)` overload exists in addition to the documented `glassEffect(_:in:)`. → **closed 2026-06-09: no such overload exists** (verified against the SwiftUI symbol page).
- The exhaustive app-icon pixel-size matrix required for OS 26 submission (Icon Composer abstracts this; verify in Xcode). → backlog (§10).
- Xcode Cloud's current free-tier compute hours. → confirm at CI setup; CI decision (Xcode Cloud) already made (§0.5).

### Improvements/additions made
- Added the regular vs clear glass variant distinction (clear used behind media, e.g. AVKit).
- Added the per-platform Liquid Glass notes (watchOS / tvOS / iPadOS) and a clear statement that iPhone/iPad/Mac need no per-platform glass code.
- Added the verified worked code example for tinted interactive glass.
- Added "do not over-apply glass / reduce custom bar backgrounds" design rules from "Adopting Liquid Glass."
- Dated all source verification to 2026-06-09 and re-pointed every URL to a page confirmed to resolve.
