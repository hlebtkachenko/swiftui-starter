# Using this template

How to start a new app from this template. `AppName` is the placeholder; you replace it with your app's name. Bundle IDs default to `dev.hapd.appname`; keep the `dev.hapd` prefix or change it to your own.

## 1. Get a copy

If the template repository is marked as a GitHub template (one-time, on the source repo):

```
gh api -X PATCH repos/hlebtkachenko/swiftui-starter -F is_template=true
```

then create each new app from it:

```
gh repo create myapp --private --template hlebtkachenko/swiftui-starter --clone
cd myapp
git config core.hooksPath .githooks
```

Without the template flag: create an empty repo (`gh repo create myapp --private`), clone the starter, remove its `.git`, run `git init`, and point the remote at the new repo. Either way you start with fresh history.

## 2. Rename `AppName` to your app

From the repo root, set `NEW` (your app's name) and `LOWER` (its lowercase form, used in the bundle ID, the iCloud container, the log subsystem, and the support domain). This assumes you keep the `dev.hapd` prefix:

```
NEW=Myapp
LOWER=myapp
git ls-files -z | xargs -0 perl -i -pe "s/AppName/${NEW}/g; s/appname/${LOWER}/g"
git mv AppName.xcodeproj ${NEW}.xcodeproj
git mv AppName ${NEW}
git mv AppNameTests ${NEW}Tests
git mv AppNameUITests ${NEW}UITests
git mv ${NEW}/AppNameApp.swift ${NEW}/${NEW}App.swift
git mv ${NEW}/AppName.entitlements ${NEW}/${NEW}.entitlements
git mv ${NEW}/Commands/AppNameCommands.swift ${NEW}/Commands/${NEW}Commands.swift
git mv ${NEW}/Data/AppNameModel.swift ${NEW}/Data/${NEW}Model.swift
git mv ${NEW}/Data/AppNameStore.swift ${NEW}/Data/${NEW}Store.swift
git mv ${NEW}/Data/CoreDataAppNameStore.swift ${NEW}/Data/CoreData${NEW}Store.swift
git mv ${NEW}Tests/AppNameTests.swift ${NEW}Tests/${NEW}Tests.swift
git mv ${NEW}UITests/AppNameUITests.swift ${NEW}UITests/${NEW}UITests.swift
git mv ${NEW}UITests/AppNameUITestsLaunchTests.swift ${NEW}UITests/${NEW}UITestsLaunchTests.swift
```

The `appname` -> `myapp` pass covers the bundle ID `dev.hapd.myapp`, the container `iCloud.dev.hapd.myapp`, the log subsystem, and the `myapp.hapd.dev` domain in the docs. To change the prefix too, replace `dev.hapd` in the same `perl` pass.

To rename to a different prefix, add it to the substitution, for example `s/dev\.hapd/com\.acme/g`.

## 3. Signing

Copy the example and set your Apple Developer Team ID. `Secrets.xcconfig` is gitignored and never committed:

```
cp Secrets.xcconfig.example Secrets.xcconfig
```

Edit `Secrets.xcconfig` and replace `YOUR_TEAM_ID`.

## 4. Build

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

- Replace the example feature (a family wishlist) in `${NEW}/Data` and `${NEW}/Views` with your own model and views. The app spine in `${NEW}/Core` is domain-agnostic; keep it.
- Rewrite `README.md`, `STATE.md`, and `CHANGELOG.md` for your app. Revisit any ADR in `docs/adr/` that does not fit, and update the record.
- CloudKit is **off** by default (`cloudKitContainerIdentifier` is `nil`, so the app runs as a local store). To enable sync: provision an iCloud container, then set its identifier in `PersistenceController.swift`, `${NEW}.entitlements`, and `${NEW}/Info.plist`. Deploy the CloudKit schema Development -> Production before the first external-TestFlight or production build (ADR-0014).
