# KAN-45 Accessibility Verification

Verified against the packaged dark-mode app on 2026-07-12.

## Outcome

- Update states use text, distinct SF Symbols, tinted fills, and outlined capsules.
- Warning severity uses named severity groups, text labels, and distinct glyphs in addition to color.
- Quarantine risk and confidence use explicit labels, icons, and outlined capsules.
- History outcomes use named results, distinct symbols, and outlined capsules.
- Heatmaps retain luminance steps and cell borders in grayscale; when macOS “Differentiate without color” is enabled, active cells also receive shape symbols for low, medium, and high intensity.
- Secondary text contrast is 7.27:1 on the light card reference, 8.84:1 on dark cards, and 10.39:1 on the dark canvas.
- Metadata and timestamps in the affected screens use at least the SwiftUI `caption` text style.
- Increased Contrast strengthens card, status-capsule, and heatmap-cell outlines.

## Rendered evidence

- `02-updates.png` and `02-updates-grayscale.jpg`
- `03b-usage-heatmap-lower.png` and `03b-usage-heatmap-lower-grayscale.jpg`
- `04-warnings.png` and `04-warnings-grayscale.jpg`
- `05-quarantine.png` and `05-quarantine-grayscale.jpg`
- `06-history.png` and `06-history-grayscale.jpg`

The grayscale renders preserve the state labels, icons, outlines, and heatmap intensity ordering. No affected status depends on hue alone.

## Automated verification

- `swift build --scratch-path /tmp/app-monitor-kan45-build2`
- `swift test --scratch-path /tmp/app-monitor-kan45-build2` — 62 tests, 0 failures
- `./scripts/build_app.sh debug` — packaged bundle signed and validated
- `git diff --check`

## Vision tooling note

The required local vision client was invoked for each screenshot. Its configured provider could not run because this environment has no vision API key, so the final visual review used Codex’s built-in image viewer plus the app’s accessibility tree and grayscale renders.
