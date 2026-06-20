# ADR-0011: Authentication and account lifecycle

**Status:** Accepted - 2026-06-09

## Context

AppName needs accounts to anchor sharing and identity, and it wants a privacy-preserving sign-in. Offering account creation pulls in App Store obligations around deletion, and the CloudKit sharing model makes deletion structurally tricky.

## Decision

- Use Sign in with Apple only for now, which satisfies the privacy-preserving login expectation in guideline 4.8.
- Provide self-serve in-app account deletion, which is mandatory once account creation exists (guideline 5.1.1).
- Design deletion to handle `CKShare` ownership and zone teardown, so deleting an owner's account transfers or cleanly removes their shares without orphaning the other participants' views.

## Consequences

- One clean login path, no passwords to store.
- Deletion is coupled to the data model: the owner-deletion data-loss case in [ADR-0006](0006-sharing-access-control-roles.md) and [ADR-0007](0007-file-attachment-storage.md) must be solved before deletion ships.
- Implementation pattern (from Apple's Fruta sample, 2026-06-09): handle the `SignInWithAppleButton` result in an `@Observable` auth service; at launch call `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)` to restore or invalidate the session; keep the user identifier in the Keychain so it survives app deletion; short-circuit to signed-in under `#if targetEnvironment(simulator)`. See `docs/patterns.md`.

## Links

- Evidence: research report section 8.7 (account deletion, login services).
