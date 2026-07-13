# KAN-49 — Menu-Bar Popover Audit

Date: 2026-07-12

## Coverage

- Light theme with the real empty-usage state
- Dark theme with a loading state
- System theme with an error state
- Top and lower scroll positions
- Accessibility-tree inspection for controls, metrics, progress/error status, storage segments, action rows, and freshness metadata
- Keyboard shortcuts for update check, storage scan, and the default dashboard action

## Evidence

- `01-light-top.png` — initial light render; exposed the incorrect inventory fallback in “Top Apps Today”
- `02-light-empty.png` — corrected light empty state
- `03-dark-loading-top.png` — corrected dark loading state
- `04-dark-loading-lower.png` — lower scroll position covering storage and pinned actions
- `05-system-error.png` — system-theme error state

## Findings and fixes

1. The fixed-height popover content could extend behind the action/footer region. The detail content now scrolls inside the 542 × 620 popover while warnings, cleanup, freshness, and the primary dashboard action remain pinned.
2. The popover did not provide the installed-app update action available in the main app. The header now includes update check and storage scan actions with matching keyboard shortcuts.
3. Loading and failure states were not visible. A compact status banner now reports inventory, scan, and update progress plus actionable failure text.
4. Freshness covered only storage scans. The footer now reports both the last storage scan and last installed-app update check.
5. When today’s usage was zero, “Top Apps Today” fell back to imported/inventory signals and displayed arbitrary apps as `1d`. It now uses measured usage for today only and presents the empty state when none exists.
6. Icon-only controls and visual storage/metric summaries lacked complete VoiceOver names. Explicit labels and combined descriptions were added, including a dynamic status-item label with warning and update counts.
7. Header actions are grouped as a keyboard focus section, and the primary dashboard action is the default action.

## Visual result

No alignment, overflow, truncation, or theme-contrast defect remained in the captured states. Scrolling preserves the pinned action area and exposes all detail content. The empty, loading, and error messages remain readable without relying on color alone.

## Verification

- Clean isolated worktree build: passed
- `swift test`: 56 tests passed, 0 failures
- Packaged debug app: signature and designated requirement validation passed
- Accessibility tree: update, scan, settings, progress/error, metric, storage, freshness, warning, cleanup, and dashboard elements were exposed with descriptive names

The primary worktree’s full build remains blocked by unrelated pre-existing `DashboardView.swift` edits; the KAN-49 files were verified in a clean worktree with the same project revision.
