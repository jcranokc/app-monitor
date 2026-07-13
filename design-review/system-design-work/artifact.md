# Retained template execution contract

## Reference

- Path: `/Users/jacob/.codex/plugins/cache/openai-curated-remote/openai-templates/0.1.0/skills/artifact-template-system-design/assets/reference.docx`
- SHA-256: `13504f6c221a42c1726460a9e865e563355539ff97d702d6c9b2267b4b261d76`
- Page count: 7
- Section count: 1
- Reference render: `template-reference-render/`
- Style evidence: `template-style-evidence.json`

## Page system

- US Letter portrait, 8.5 x 11 inches.
- Margins: 0.70 inch left/right/top, 0.62 inch bottom.
- One section, different first-page header enabled, no linked headers/footers.
- Preserve the first-page title block, navy/light-blue table system, heading ladder, footer, and recurring page furniture.

## Typography and components

- Primary font: Helvetica Neue; preserve the source run formatting and heading styles.
- Title page uses two Title paragraphs followed by metadata and a two-column details table.
- Heading 1 is the numbered section title; Heading 3 is the local subsection label.
- Tables use navy header fill, white header text, alternating pale-blue body fills, white separators, and vertically centered body content.
- The architecture figure is the only source component replaced structurally; it is replaced with a new raster diagram sized to the same content width and followed by the preserved caption pattern.
- Footer text remains source-derived but is changed to `App Monitor | System & Product Design Review`.

## Content flow and slot map

- Cover: replace system/title, status, owner, date, authors, reviewers, related docs, and scope text.
- Sections 1-12: replace every bracketed instructional placeholder with evidence-based App Monitor content.
- Goals/non-goals, component, contract, consistency, readiness, alternatives, and milestone tables: preserve table geometry and replace cell text in place.
- Architecture figure: replace the source placeholder image with a task-local diagram while preserving the caption location.
- Appendices: add Product Design Audit, UI Direction Gallery, and Prioritized Backlog after Section 12 using cloned source heading/body/table/image patterns.

## Package preservation and fidelity gates

- Keep the reference unchanged and build from a working copy.
- Preserve page geometry, styles, numbering, theme, headers, footers, relationships, and existing table styles unless an explicit content addition requires a new relationship.
- Embedded audit and concept images are task-local additions; do not modify source images.
- Render and inspect every final page at 100% zoom. Fail on clipping, overlap, broken tables, malformed image placement, unexpected pagination, or template placeholders.
- Re-run section/style/image audits and compare the final against the reference with `render_and_diff.py`.
