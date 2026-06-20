# Security, secrets, privacy

The single home for engineering security rules. `AGENTS.md` carries the short boundaries; `SECURITY.md` is the vulnerability-reporting policy. The repo is public, so never commit anything you would not publish.

## Secrets

- **Never** hardcode API keys, tokens, passwords, certificates, or provisioning profiles in source, `Info.plist`, asset catalogs, or any tracked `.xcconfig`.
- Secrets live in an untracked `Secrets.xcconfig` (gitignored) injected at build time, as encrypted **GitHub Actions secrets** in CI, and in the **Keychain** at runtime. Never in `UserDefaults` or source.
- Signing assets (`*.p12`, `*.p8`, `*.mobileprovision`, `*.cer`) are never committed. Use an App Store Connect API key stored as a CI secret, or fastlane match with an encrypted store.
- If a secret is ever committed: **assume it is compromised (the repo is public), rotate it immediately,** then purge it from history. Never "fix" it with a follow-up delete commit.

## Personal data and identity

- **Never invent or commit personal or contact information**: emails, phone numbers, postal addresses, or internal hostnames/IPs. Do not add a contact email anywhere; reference the GitHub repository instead. Context such as the session `userEmail` is background, not authorization to publish.
- The only personal identity that may appear is the `LICENSE` copyright holder, and only as the owner directs. Do not add anyone else's.

## Privacy (the app)

AppName holds personal and family data. Build for minimal collection:

- Collect the **minimum** needed; default to **on-device** storage and sync only with explicit user setup.
- **No third-party analytics, advertising, or tracking SDKs.** No IDFA. No silent telemetry.
- Encrypt sensitive data at rest; use the Keychain for credentials. **Never log PII or family content,** and scrub crash reports.
- App Store privacy labels and any privacy policy must match the real data flows exactly.
- **Children and minors:** a family space may include child users. Comply with COPPA, GDPR for children, and Apple's Kids guidelines. Never behaviorally profile minors.
- **Family sharing access control:** sharing is opt-in per item, members can revoke access, and one member must never silently expose another member's data.
- **Retention, deletion, export:** support user-initiated data deletion and export (GDPR erasure and portability, and Apple's required in-app account deletion). Do not retain data longer than needed.
- **Backend (TBD):** whichever backend is chosen must encrypt data in transit and at rest. If Firebase is used, disable Analytics and Crashlytics collection (on by default), which would otherwise violate the no-telemetry rule.
- A user-facing privacy policy is required before the first release.

## How the guards work

The `guard` workflow runs these security and hygiene checks on every push and PR:

- **Tracked secret/private files** (`check-tracked.sh`): fails if any tracked file matches a secret/private pattern, catching force-adds past `.gitignore`.
- **Private key material** (`check-private-keys.sh`): fails on `BEGIN ... PRIVATE KEY` in tracked files.
- **Oversized files** (`check-large-files.sh`): fails on any tracked file over 5 MB.
- **Personal data** (`check-personal-data.sh`): fails on any email address in tracked files (placeholders allowlisted), plus any string in a private denylist. Reports locations only, never the matched value.
- **Dead links** (`check-links.sh`): fails on relative Markdown links that do not resolve.
- **Duplicate prose** (`check-duplication.sh`): fails on lines that appear verbatim in two or more Markdown files. It catches copy-paste; paraphrased duplication is prevented by the ownership map in `README.md` and by review, not by this script.
- **Ownership map current** (`check-ownership-map.sh`): fails if a documentation file is missing from `README.md`, so the map cannot go stale when docs are added or renamed.

### Private denylist

Supply forbidden strings (real name, handles, infrastructure, phone) out of band so the values never live in the repo:

- **CI:** a `FORBIDDEN_STRINGS` repository secret, one term per line.
- **Local:** a gitignored `.forbidden-strings` file, one term per line.

Enable the local pre-commit mirror once per clone: `git config core.hooksPath .githooks`.

## Reporting

Security reports go through GitHub's private vulnerability reporting (the repository's Security tab). See `SECURITY.md`.
