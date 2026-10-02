# Contributing

Thanks for helping improve the template. This repository is the starter itself: contributions change what every new app begins with, so they stay small, generic, and within the rules in [AGENTS.md](AGENTS.md#hard-constraints).

## Before you start

- **Bugs:** open a [bug report](https://github.com/hlebtkachenko/swiftui-starter/issues/new?template=bug_report.yml).
- **Features:** open a [feature request](https://github.com/hlebtkachenko/swiftui-starter/issues/new?template=feature_request.yml) first and wait for a go before writing code. App-specific features belong in your own app, not here.
- **Security problems:** never in a public issue; follow [SECURITY.md](SECURITY.md).

## Making a change

1. Fork, branch from `main`, and enable the pre-commit hook.
2. Build, test, format, and run the local gate with the commands in [AGENTS.md](AGENTS.md#commands).
3. Record user-facing changes under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md), and update [STATE.md](STATE.md) when the template's state changes.
4. Open a pull request with a [Conventional Commits](https://www.conventionalcommits.org/) title (`feat:`, `fix:`, `docs:`, ...) and a real description; the pull request template lists the checklist.

A pull request merges when the four required checks pass: `Scan for secrets` (gitleaks), `Block secrets and private files` (guard), `PR title and description` (pr-check), and `Build and test`. What each one does: [docs/ci-cd.md](docs/ci-cd.md).

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE), the same license as the project.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By taking part, you agree to uphold it.
