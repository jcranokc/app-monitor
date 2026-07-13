# App Monitor 1.2.0 beta 5

This release packages the complete KAN-28 product-design, trust, and accessibility remediation epic (KAN-29 through KAN-49).

## Trust and safety

- Reduces warning saturation with normalized, deduplicated, confidence-ranked findings and protected-system exclusions.
- Replaces categorical cleanup safety claims with evidence, ownership, exclusions, confidence, and review-first handling for uncertain data.
- Separates missing monitoring history from verified inactivity and publishes scan-dependent data as one atomic snapshot.
- Reconciles duplicate app identities and distinguishes unscanned storage from confirmed zero-byte results.

## Product experience

- Makes the detail inspector and lower sidebar destinations work at default window sizes.
- Separates Homebrew adoption from genuine updates and makes toolbar actions contextual to each workspace.
- Improves dense tables, history outcomes, reversible-action language, sparse one-day charts, warning triage, Overview decisions, cleanup evidence, and Large Files review.
- Aligns the menu-bar popover with the main app across appearance modes, loading/empty/error states, freshness, and actions.

## Accessibility and privacy

- Adds non-color status and severity cues, stronger secondary-text contrast, stable focus treatment, and accessibility identifiers for core flows.
- Gives usage heatmaps semantic labels and an equivalent table view.
- Adds Privacy & Data controls for monitoring coverage, retention, export, deletion, exclusions, local storage, and saved Homebrew authorization.
- Includes keyboard and VoiceOver QA evidence for the main app and menu-bar flows.

## Verification

- `./scripts/ci`: 79 tests passed, 0 failures; the packaged app rebuilt and passed signature validation.
- The release artifact is Developer ID signed, notarized, stapled, and Gatekeeper-verified before publication.

