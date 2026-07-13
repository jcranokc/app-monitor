# App Monitor end-to-end product design audit

**Audit date:** 2026-07-12  
**Build reviewed:** App Monitor 1.2.0 (4), installed at `/Applications/App Monitor.app`  
**Scope:** Main macOS window, scan state, dashboard, update management, app library, detail inspector, storage, usage, maintenance, and Settings.  
**User goal:** Understand the Mac, keep software current, identify real risks, and reclaim space without losing trust or data.  
**Accessibility target:** A keyboard- and assistive-technology-friendly macOS utility with legible hierarchy, non-color status communication, and clearly reversible actions.

## Overall verdict

App Monitor has a strong information architecture and unusually broad capability, but the current experience is not yet trustworthy enough for aggressive cleanup or security decisions. The dominant problem is not visual polish; it is signal quality and state clarity. The app reports 1,103 warnings across 145 of 147 apps, recommends 50.47 GB for quarantine, labels some large cleanup groups `Safe`, and briefly shows contradictory usage states during and immediately after a scan. At the default window width, opening the inspector also clips content and collapses toolbar labels into icons.

The product should keep its current dark, card-based visual system. The next pass should focus on confidence, prioritization, responsive layout, and plain-language action semantics.

## What is working

- The sidebar groups the product into understandable jobs: updates, library, storage, usage, and maintenance.
- Quarantine is presented as reversible and preview-first rather than delete-first.
- Storage Overview has the strongest hierarchy in the app: headline capacity, category cards, distribution, and drill-downs are coherent.
- The update queue exposes source, current version, available version, status, and per-item actions.
- Most controls and chart marks expose useful accessibility labels in the macOS accessibility tree.
- The dark theme, card geometry, spacing, and icon language are visually consistent across the app.

## Highest-impact findings and recommended changes

### P0 — Make safety and measurement confidence explicit before expanding cleanup automation

1. **Reduce warning saturation.** The Warnings screen shows 1,103 warnings across 145 apps, including 842 medium items. A system that marks almost everything as problematic cannot communicate urgency. Exclude protected/system bundles from ordinary performance warnings, suppress generic writable-bundle findings where normal macOS ownership explains them, deduplicate repeated path findings, and rank by user impact plus confidence.
2. **Do not call uncertain cleanup groups `Safe`.** The Quarantine screen labels items such as `Unused Home Storage` (12.63 GB, 83 items) and multi-gigabyte developer caches `Safe`, even though usage coverage and ownership context are not visible. Replace `Safe` with confidence-aware language such as `Usually rebuildable`, `Review app state`, or `Protected`; show why the item qualifies, the observed date range, last modification, owning app, and exclusions.
3. **Separate measured inactivity from unknown activity.** `Never Used` currently mixes true inactivity with missing or incomplete activity history. Use `No activity recorded` until the tracking window is long enough, show the measurement start date, and never treat that state alone as cleanup eligibility.
4. **Refresh scan-dependent modules atomically.** During and immediately after the scan, Usage Trends had hours and sessions while Activity Timeline or Recent Activity could show no data. Hold the previous complete snapshot until the new one is ready, or mark each affected module `Refreshing from latest scan` and swap all dependent snapshots together.

### P1 — Repair the default-width layout and action model

5. **Make the inspector responsive.** At the default window size the inspector extends beyond the right edge, clips update copy and summary cards, and reduces toolbar labels to ambiguous icons. Use a resizable inspector with a narrower compact layout, enforce a usable minimum content width, or present details as a sheet when space is insufficient.
6. **Split `Updates` from `Adopt with Homebrew`.** Four adoption candidates are counted inside the update center even when current and available versions match. Give adoption its own metric and queue; reserve `Available updates` for actual version changes. Explain replacement risk before adoption.
7. **Clarify global actions.** `Updates` duplicates the sidebar destination, `Cleanup` appears as the visually dominant action on every screen, and the Options menu mixes filtering, sorting, saved filters, and exports. Make the toolbar contextual, rename navigation actions (`Open Updates`, `Review Cleanup`), and move table-specific commands into each screen.
8. **Use outcome language consistently.** History rows can say `Updates Partial` while the Result column says green `Completed`. Define outcome as `Succeeded`, `Partially succeeded`, `Failed`, `Pending`, or `Reverted`; reserve completed for lifecycle state only. Replace the ambiguous `Request` action with the exact result (`Request revert`, `View log`, or `Not reversible`).

### P1 — Restore prioritization and legibility

9. **Turn Warnings into a triage queue.** Default to actionable, high-confidence findings. Add `Ignore`, `Acknowledge`, `False positive`, and `Recheck`; show why the issue matters, whether App Monitor can verify a fix, and when it was last confirmed.
10. **Fix truncation in dense tables.** Update source subtitles, version strings, long filenames, filter chips, and inspector copy are clipped. Favor one meaningful secondary line, allow column resizing, provide hover/VoiceOver expansion, and avoid exposing internal tokens such as `needsReview`.
11. **Improve the dashboard narrative.** `131 discovered this week`, `143 matching filters`, `Review recommended`, and `118 suggestions` are not a coherent decision path. Make the overview answer: what changed, what needs action now, what is safe to defer, and what would reclaim space.
12. **Make charts explain small data sets.** A single-day stacked area renders as a dominant solid block and makes large percentage comparisons look precise. For one represented day, use a bar or annotated summary, explain the comparison denominator, and hide percentages when the baseline is too small.

### P2 — Accessibility and settings completeness

13. **Add text or shape to color-coded states.** Charts, heatmaps, severity chips, and status dots rely heavily on color. Retain the palette but add patterns, icons, direct labels, or borders. Increase contrast of secondary gray text and tiny timestamps.
14. **Give heatmap cells semantic roles.** The accessibility tree exposes heatmap cells as unknown elements, even though descriptions exist. Expose them as accessible chart/data cells with day, hour, duration, sessions, and top app; provide an equivalent table.
15. **Make focus visible and test the entire keyboard path.** The search field retained focus after Tab in this audit environment and no visible focus transition was apparent. Verify full keyboard access with macOS keyboard navigation enabled, including sidebar disclosure rows, chart modes, filter menus, table actions, inspector controls, and destructive confirmations.
16. **Add Privacy & Data controls.** Settings explain schedules and updates but not activity-monitoring permission, measurement coverage, stored history, retention, export/delete, ignored apps, or Keychain authorization behavior. Add a Privacy & Data section plus a first-run readiness checklist.
17. **Keep the full navigation discoverable.** At the default height, lower sidebar destinations can disappear below the fold with little indication that the sidebar scrolls. Keep Settings pinned, show a visible scroll affordance, and consider collapsing rarely used source filters by default.

## Numbered flow review

### 1. Launch and Overview — **Needs work**

![Overview](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/24-overview-stable.png)

The main hierarchy is strong, but summary cards mix inventory, filters, warnings, and savings without a clear next decision. A post-scan capture briefly showed Recent Activity empty while Usage Trends on the same screen contained 4h 33m and 133 sessions; a later capture populated the list.

### 2. Full scan progress — **Healthy with clarity gaps**

![Scan progress](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/02-scan-progress.png)

The progress bar exposes app count, percent, current phase, path, file count, and size. However, stale screen metrics remain fully actionable during the scan and affected modules do not explain whether their data is old, partial, or refreshing.

### 3. Installed app updates — **Needs work**

![App updates](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/25-app-updates-stable.png)

Provider coverage is excellent. Adoption candidates, actual updates, manual actions, and change logs compete in one workspace; long versions and source details truncate; the available count does not clearly distinguish a newer version from management adoption.

### 4. Package updates — **Generally healthy**

![Package updates](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/03-package-updates.png)

The formula queue is understandable and batch selection is discoverable. Row subtitles truncate to fragments and the scan banner competes with an already dense action area.

### 5. All Apps library — **Needs work**

![All Apps](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/26-all-apps-stable.png)

The table is scannable, but `Warnings` dominates most rows, app identities can duplicate, and zero or missing storage is not distinguished from confirmed zero. Sorting is described in copy but not visibly attached to column headers.

### 6. App detail inspector — **High-risk layout failure**

![App details](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/27-app-details-stable.png)

The inspector consolidates update, usage, insight, storage, and file evidence well. At the default width it is visibly clipped off-screen, hides parts of cards and copy, and turns the main toolbar into unlabeled icons.

### 7. Browse by Source — **Healthy, secondary**

The disclosure exposes App Store, Homebrew, Sparkle, metadata, Electron, and formulae. The accepted screenshot could not be retained because the capture surface returned an invalid mostly blank frame; the accessibility tree confirmed the menu structure. Keep it collapsed by default so primary navigation remains visible.

### 8. Storage Overview and explorer — **Strongest screen**

![Storage Overview](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/28-storage-stable.png)

![Storage Explorer](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/10-storage-lower.png)

The screen creates a clear drill-down from total usage to categories and folders. Add a clear definition of tracked storage versus the full disk and explain why totals can differ from the Overview during a scan.

### 9. Large Files — **Needs work**

![Large Files](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/11-large-files.png)

Long hashed filenames become unreadable, `needsReview` leaks as an internal state label, and ellipsis actions are not self-explanatory. Add owner, full path on demand, modification date, risk, and a plain-language recommended action.

### 10. Usage Trends — **Needs work**

![Usage Trends](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/29-usage-trends-stable.png)

![Usage heatmap](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/13-usage-heatmap.png)

The metric cards and mode controls are useful. One-day data renders as an oversized solid stacked area, comparisons appear overconfident, the chart relies on color, and the heatmap lacks semantic accessibility roles.

### 11. Activity Timeline — **Generally healthy after scan**

![Activity Timeline](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/30-activity-timeline-stable.png)

The timeline is the clearest usage visualization and includes Timeline, List, and Heatmap modes. During the scan it showed a zero-data empty state while Usage Trends already had data; after completion it populated to 134 sessions, confirming a synchronization and state-labeling problem rather than missing data.

### 12. Warnings — **High risk**

![Warnings](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/31-warnings-stable.png)

The severity grouping and detailed explanation are good foundations. Signal saturation, clipped filter labels, an off-screen inspector, broad false-positive candidates, and the absence of dismiss/recheck controls make this screen hard to trust or finish.

### 13. Quarantine Review — **Promising but confidence is too strong**

![Quarantine Review](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/32-quarantine-stable.png)

The queue, category totals, checkboxes, and disabled action until selection support a reversible workflow. `Safe` is too categorical for large grouped data tied to apps with incomplete activity context; the screen needs evidence, exclusions, and confidence levels.

### 14. History and restore — **Needs work**

![History](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/33-history-stable.png)

![History records](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/19-history-records.png)

Storage history and event grouping are useful. The graph lacks a visible value scale, `Restore Latest` appears beside zero restore points, and event outcomes/actions use conflicting or ambiguous language.

### 15. Settings — **Good foundation, incomplete trust controls**

![Settings](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/34-settings-stable.png)

![Update settings](/Users/jacob/Documents/App Monitor/design-review/live-audit-2026-07-12/21-settings-updates.png)

Appearance, launch behavior, full scans, self-update, installed software updates, and source inclusion are organized clearly. Privacy, activity permission/readiness, retention, data deletion/export, exclusion management, notification policy, and a fuller explanation of saved administrator authorization are missing.

### 16. Menu bar popover — **Not captured**

The chosen native-app capture surface exposed the main window but not the macOS status-item popover. Settings confirm that the popover is a supported surface, but this audit does not claim visual or accessibility coverage for it.

## Accessibility evidence and limits

- Positive: major buttons, sidebar items, segmented controls, update actions, rows, and chart marks generally had descriptive macOS accessibility labels.
- Risk: heatmap cells appeared with unknown roles; status and severity depend heavily on color; secondary labels are small and low contrast; some actions collapse to icons when the inspector is open; visual focus movement could not be confirmed.
- Not verified: VoiceOver reading order and announcements, Switch Control, reduced motion, increased contrast, color filters, Dynamic Type-like text scaling, zoom/reflow, full keyboard traversal, and exact WCAG contrast ratios.
- The configured external vision script could not run because no supported vision-provider API key was available. Every accepted screenshot was still opened and visually inspected in the current audit, but no external vision-model output is claimed.

## Recommended implementation sequence

1. **Trust and safety:** warning normalization, cleanup confidence model, system/protected exclusions, measurement coverage, atomic scan snapshots.
2. **Core layout:** responsive inspector, toolbar adaptation, sidebar overflow, dense-table truncation.
3. **Action semantics:** separate adoption from updates, normalize outcomes, clarify history and global actions.
4. **Accessibility:** non-color states, heatmap/table equivalents, contrast and focus pass, keyboard/VoiceOver QA.
5. **Settings and onboarding:** Privacy & Data, permission readiness, retention/export/delete, exclusions, authorization explanation.

## Evidence inventory

Accepted screenshots are stored beside this report under `design-review/live-audit-2026-07-12/`. The installed app was code-signed with a Developer ID, had a stapled notarization ticket, and completed a fresh in-app full scan during the audit. No updates, adoptions, quarantines, restores, uninstalls, or settings changes were executed.
