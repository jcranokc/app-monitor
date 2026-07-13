# KAN-47 Keyboard and VoiceOver QA

Test the signed App Monitor build with macOS Full Keyboard Access enabled and VoiceOver (`Command-F5`) on. Start with a fresh launch at the Overview screen.

## Keyboard traversal

- Press `Tab` from the sidebar through every visible destination. Confirm the blue macOS focus ring is never clipped and `Space` activates the focused destination.
- Expand **Browse by Source** without a pointer. Traverse every revealed source, collapse it, and confirm focus stays on the disclosure.
- Use `Command-1` through `Command-6` to open Overview, App Updates, All Apps, Warnings, Quarantine Review, and History. Use `Command-,` for Settings.
- Use `Command-K` to focus search. Type a query, clear it, and resume traversal from the search field.
- On All Apps, focus **Table Options**, change filters and sort, then activate an app row and use `Command-Option-I` to show or hide details.
- On App Updates, select updates with the checkbox, use Select Available/Clear, run Check Installed Apps, and reach each row action without a pointer.
- On Quarantine Review, traverse filter pills, sort controls, queue checkboxes, rows, and inspector actions. Verify a destructive action still requires its confirmation UI.
- On History, traverse rows and inspector actions; activate a row, then reach Revert/Request and snapshot controls.
- On Settings, traverse every picker, toggle, stepper, link, and update button in visual top-to-bottom order.

## VoiceOver

- Confirm sidebar destinations announce their visible names, selected state, and update counts without reading decorative icons.
- Confirm charts are exposed as one labeled summary element or as meaningful data points, never as unlabeled shapes.
- Confirm app, warning, update, quarantine, and history rows announce the primary name plus status/value context.
- Confirm update and quarantine checkboxes announce checked/unchecked and disabled states.
- Confirm opening a destination announces the new screen name.
- Confirm scans, update checks, selections, quarantine changes, restores, and errors announce the final status once.
- Confirm the inspector toggle announces **Show details** or **Hide details**, and focus continues in a stable order when the inspector appears.

## Regression record

Record macOS version, App Monitor version/build, input method, VoiceOver result, keyboard-only result, and any failed accessibility identifier. Attach screenshots for clipped or missing focus rings.
