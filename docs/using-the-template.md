# Using this template

How to start a new app from this template. `AppName` is the placeholder; you replace it with your app's name. Bundle IDs are `$(BUNDLE_ID_PREFIX).appname`: the prefix is a build setting you set once (step 3), not part of the rename.

## 1. Get a copy

Create each new app from the template:

```
gh repo create myapp --private --template hlebtkachenko/swiftui-starter --clone
cd myapp
git config core.hooksPath .githooks
```

Or click **Use this template** on GitHub. Either way you start with fresh history.

## 2. Rename `AppName` to your app

From the repo root, on a clean working tree:

```
./rename.sh MyApp
```

The script replaces `AppName` with the name you give, `appName` with its lower-camel form, and `appname` with its lowercase form (used in the bundle ID, the iCloud container, and the support domain) in every tracked text file, then renames the tracked files and folders. It refuses a name that is not letters and digits starting with an uppercase letter, refuses a dirty tree, refuses a copy that is already renamed, and fails if any placeholder is left. Review with `git status`, undo with `git reset --hard`. The steps below use `NEW` for the name and `LOWER` for its lowercase form.

The `appname` -> `myapp` pass turns the bundle ID into `$(BUNDLE_ID_PREFIX).myapp` and the container into `iCloud.$(BUNDLE_ID_PREFIX).myapp`. The log subsystem follows the bundle ID at run time.

Manual fallback, if you cannot run the script (`-I` skips binary files such as the PNGs in `docs/images/`):

```
NEW=MyApp
LOWER=myapp
CAMEL=myApp
git grep -lzI -e AppName -e appName -e appname -- . ':!rename.sh' | xargs -0 perl -i -pe "s/AppName/${NEW}/g; s/appName/${CAMEL}/g; s/appname/${LOWER}/g"
git mv AppName.xcodeproj ${NEW}.xcodeproj
git mv AppName ${NEW}
git mv AppNameTests ${NEW}Tests
git mv AppNameUITests ${NEW}UITests
git mv ${NEW}/AppNameApp.swift ${NEW}/${NEW}App.swift
git mv ${NEW}/AppName.entitlements ${NEW}/${NEW}.entitlements
git mv ${NEW}/Commands/AppNameCommands.swift ${NEW}/Commands/${NEW}Commands.swift
git mv ${NEW}/Data/AppNameModel.swift ${NEW}/Data/${NEW}Model.swift
git mv ${NEW}/Data/AppNameStore.swift ${NEW}/Data/${NEW}Store.swift
git mv ${NEW}Tests/AppNameTests.swift ${NEW}Tests/${NEW}Tests.swift
git mv ${NEW}UITests/AppNameUITestsLaunchTests.swift ${NEW}UITests/${NEW}UITestsLaunchTests.swift
```

## 3. Signing and bundle ID prefix

Copy the example, then set your Apple Developer Team ID and your reverse-DNS bundle ID prefix. `Secrets.xcconfig` is gitignored and never committed:

```
cp Secrets.xcconfig.example Secrets.xcconfig
```

Edit `Secrets.xcconfig`: replace `YOUR_TEAM_ID`, and set `BUNDLE_ID_PREFIX` (for example `com.acme`). Without the file the build falls back to `com.example` from `Shared.xcconfig`, so a fresh clone still builds.

Give CI the same prefix once per repo as a repository variable (not a secret); the workflows write it into `Secrets.xcconfig` before building:

```
gh variable set BUNDLE_ID_PREFIX --body com.acme
```

## 4. Build

You need Xcode 27: every target deploys to OS 27 (iOS / iPadOS / macOS 27) and later.

```
xcodebuild build -scheme ${NEW} -destination 'platform=macOS'
xcodebuild build -scheme ${NEW} -destination 'platform=iOS Simulator,name=iPhone 17'
```

Replace the simulator name with one you have (`xcrun simctl list devices`).

## 5. Protect `main`

Branch protection is a repository setting, not a file, so it does not carry over on copy. Apply the checked-in ruleset (needs the `gh` CLI with admin on your repo):

```
./.github/scripts/setup-branch-protection.sh
```

See [ci-cd.md](ci-cd.md) for what the ruleset enforces. CI passes with no repository secrets configured.

## 6. Make it yours

- Replace the Folder / Item example in `${NEW}/Data` (model, store) and `${NEW}/ContentView.swift` with your own model and views. The app spine in `${NEW}/Core` is domain-agnostic; keep it.
- Delete the template's showcase files: `docs/images/`, `llms.txt`, `rename.sh`, and the `rename` job in `.github/workflows/build.yml`. Replace `README.md` with your app's own, and rewrite `STATE.md` and `CHANGELOG.md` for your app.
- Replace `LICENSE` with your own license; the template's MIT license names the template's author, not you. Revisit any ADR in `docs/adr/` that does not fit, and update the record.
- CloudKit is **off** by default (`cloudKitContainerIdentifier` is `nil`, so the app runs as a local store). To enable sync: with automatic signing and `DEVELOPMENT_TEAM` set, add the container in Xcode (Signing & Capabilities -> iCloud -> CloudKit), which registers it; make sure its identifier matches `com.apple.developer.icloud-container-identifiers` in `${NEW}.entitlements` (it is `iCloud.$(BUNDLE_ID_PREFIX).${LOWER}`, expanded at build time), then set `cloudKitContainerIdentifier` in `PersistenceController.swift` to it. `Info.plist` needs no change. Deploy the CloudKit schema Development -> Production before the first external-TestFlight or production build (ADR-0014).
