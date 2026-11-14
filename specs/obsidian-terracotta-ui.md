# Obsidian & Terracotta UI — EDE Tier 2

## Objective
A calm, warm interface that helps tradies see outstanding evidence and reach the existing accountant review/share flow. Styling and local presentation only.

## Invariants
- Tax calculations, persistence, exports, evidence validation and authentication are unchanged.
- AppColors remains a compatibility facade over AppColor; shared roles cannot drift.
- Normal text on primary buttons and primary-container labels has contrast >= 4.5:1. Brand decoration and actionable orange have separate roles.
- No colour alone communicates evidence status. Use text and icons.
- A home summary never treats a score or an empty queue as ATO approval or proof that receipt files exist. Final checks stay in EvidenceReviewScreen.
- Existing trip batch review remains available. Expenses also have a visible route to review on CPK home.
- The evidence card has no horizontal overflow at 320 logical pixels with 200% text scale; its action is >=48 logical pixels tall.
- Existing unrelated working changes are preserved.

## Implementation
Warm alabaster canvas, white cards, obsidian text/dark surfaces, restrained terracotta. Use #C2410C for white-labelled buttons and orange text on white; #EA580C for decorative accents. Neutral evidence card with explicit next step instead of an unexplained percentage. Keep existing destinations and data sources.

## Executable contract
- flutter test test/obsidian_terracotta_ui_test.dart: mathematical contrast checks, alias equality, missing/empty/reviewable record states, narrow/large-text layout and navigation.
- flutter test test/ui/evidence_handoff_render_test.dart test/ui/evidence_review_flow_test.dart test/cpk_gestalt_ux_test.dart: existing review and batch routes.
- flutter analyze lib test/obsidian_terracotta_ui_test.dart: no new warnings/lints.
- Capture the new evidence-card states with DRIVELOG_CAPTURE=1 and inspect images. Full-app rendering is additional evidence when the existing harness supports the current checkout.

## Limits
Tier 2 does not certify tax compliance. Actual outdoor readability and the complete app at large text require device testing; colour mathematics alone cannot prove them.

## Evidence recorded — 2026-11-08
- Scoped analyzer: exit 0, no issues across five production files and the new contract test.
- Review regression run: exit 0, 17 tests (five new UI contracts plus 12 existing review/batch tests).
- Final UI contract run: exit 0, six tests including the additional logbook home case. Total unique covered tests: 18.
- Runtime captures inspected: CPK home, logbook home, empty records, reviewable records and 320px/200% evidence card. Inspection caught a button font falling back in the renderer; the button now inherits the theme label font.
- Normal primary white/action contrast: approximately 5.18:1. Brighter orange is reserved for accent use; this is not a whole-app WCAG certification.
- Full lib analyzer still reports four pre-existing warnings in scan_receipt_screen.dart (two null-aware expressions) and tactile_primary_button.dart (two unused locals). These files were left unchanged.
- Old full-screen capture harness references a deleted migration screen and stale font-cache paths, so this change uses a self-contained renderer with bundled assets instead.
- Raw logs and PNGs: .audit/obsidian-terracotta/.

## Decision
Use the existing evidence report and review destination rather than adding another readiness model. Hide the duplicate money-recovery prompt while the evidence queue is nonempty. Keep trip batch review available. An empty queue invites checking files and sharing for accountant review; it never grants tax approval. No changes to calculation, persistence, export I/O or validation services.
