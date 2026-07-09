# Security Policy

## Supported Versions

App Monitor is currently distributed from the latest GitHub release. Security fixes are made against `main` and published in the next release.

| Version | Supported |
| ------- | --------- |
| Latest release | Yes |
| Older releases | No |

## Reporting A Vulnerability

Please do not open a public issue with exploit details or sensitive local data.

Use GitHub's private vulnerability reporting or repository security advisory flow for this repository when available. If private reporting is unavailable, open a public issue with a short non-sensitive summary asking for a private disclosure channel, and do not include reproduction details until a private channel is established.

Helpful reports include:

- Affected App Monitor version or commit.
- macOS version and hardware architecture.
- Clear reproduction steps.
- Expected and actual behavior.
- Impact assessment, including whether local files, app usage history, update checks, cleanup actions, or uninstall actions are affected.
- Logs or screenshots only after removing secrets, tokens, personal file contents, and unrelated local paths.

## Response Expectations

I will try to acknowledge security reports within 7 days and provide a status update within 14 days. Confirmed vulnerabilities will be fixed in `main` first, then included in a tagged release when practical.

## Scope

In scope:

- App Monitor source code in this repository.
- Release packaging scripts and generated app metadata.
- Local data handling for app inventory, usage history, storage scans, cleanup, update, and uninstall flows.

Out of scope:

- Vulnerabilities in macOS, Homebrew, `mas`, Apple Software Update, Sparkle feeds from other apps, or third-party services.
- Reports requiring access to another person's Mac, account, files, or private data without authorization.
- Social engineering, spam, denial-of-service, or physical attacks.

## Safe Harbor

Good-faith research is welcome when it avoids privacy harm, data destruction, persistence, lateral movement, and public disclosure before a fix is available. Stop testing and report promptly if you encounter sensitive data or behavior that could affect other users.
