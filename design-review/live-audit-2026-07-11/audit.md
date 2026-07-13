# App Monitor UX and Navigation Audit

Date: July 11, 2026  
Scope: Overview, installed-app updates, quarantine review, history, settings, and usage trends in the locally built macOS app.

## Overall verdict

The product has a strong visual system and unusually deep functionality, but its navigation and three-column layout made the app feel harder to understand than it is. The persistent inspector was the largest structural problem: it showed stale or irrelevant app details on high-level workspaces, reduced the main canvas by roughly one third, truncated labels, and forced dense content into narrow columns. Duplicate sidebar names and a buried Settings destination added orientation cost.

The implementation pass makes the main workspace the default, turns details into an explicit contextual action, gives sidebar destinations unique names, collapses advanced source filters, keeps Settings visible, consolidates toolbar options, and replaces developer-facing settings status with plain language.

## Flow steps

1. **Overview — healthy after improvement.** Before: the Codex inspector stayed open beside the overview, while the main canvas wrapped five metrics into two rows and toolbar labels collapsed. After: the overview uses the full canvas, five key metrics align in one row, and the toolbar actions are readable.

   Before: `01-overview-before.png`  
   After: `07-overview-after.png`

2. **Installed App Updates — healthy after improvement.** Before: an unrelated app inspector clipped the screen title, metrics, queue actions, table, and change-log timeline. After: the update queue has a complete readable table and the filter state remains visible without sacrificing the workspace.

   Before: `02-updates-before.png`  
   After: `08-updates-after.png`

3. **Quarantine Review — healthy with a minor density risk.** Before: safety information was useful but permanently consumed the right side; filter names and explanations truncated. After: the review queue is readable at full width, safety details are available from a clearly labeled Details control, and the destructive-looking workflow remains quarantine-first and reversible.

   Before: `03-quarantine-before.png`  
   After: `09-quarantine-after.png`

4. **History — healthy after improvement.** Before: the inspector compressed summary labels, chart legends, and the audit table even when the user had not asked for detail. After: the timeline and summary cards are readable, and selecting a history row can still open contextual details.

   Before: `04-history-before.png`  
   After: `12-history-after.png`

5. **Settings — substantially clearer.** Before: the screen mixed appearance, lifecycle, scans, self-update, installed-app update, and repository controls in an undifferentiated card, showed `SMAppServiceStatus(rawValue: 1)`, and displayed an unrelated Codex inspector. After: plain-language section headings explain the scope of each setting, launch status reads `Enabled`, and Settings remains pinned in the sidebar.

   Before: `05-settings-before.png`  
   After: `10-settings-after.png`

6. **Usage Trends — healthy after improvement.** Before: the inspector forced summary metrics into a sparse 3-by-2 grid and repeated the ambiguous phrase `No prior data`. After: five summary metrics form a single scan line, the chart has more room, and comparison copy explains when the baseline will appear.

   Before: `06-usage-before.png`  
   After: `11-usage-after.png`

## Highest-impact changes

1. Make the detail inspector contextual and hidden on navigation, with a labeled Details control when detail exists.
2. Rename repeated sidebar items to unique destinations: App Updates, Package Updates, All Apps, Unused Apps, and System Apps.
3. Collapse provider-level update filters under Browse by Source because they are advanced filtering, not primary destinations.
4. Pin Settings and scan status below the scrolling navigation list.
5. Consolidate filter, sorting, saved-filter, and export commands under Options so Scan, Updates, and Cleanup remain readable.
6. Organize Settings around General, Full Scan Schedule, Update App Monitor, and Update Installed Software.
7. Translate the macOS login-item enum into Enabled, Off, Needs approval in System Settings, or Unavailable.

## Accessibility observations and limits

The current accessibility tree exposes named sidebar buttons, labeled toolbar actions, checkbox and radio-button states, chart descriptions, and a labeled Show details control. The implementation also gives the inspector toggle an explicit accessibility label.

Screenshots and the accessibility tree do not prove full keyboard traversal, VoiceOver reading order, contrast ratios, Dynamic Type behavior, reduced-motion behavior, or zoom/reflow resilience. Those require hands-on assistive-technology and measurement testing.

