# Independent review

Reviewed task files against `/private/tmp/drivelog-evidence-baseline`, the design specification, the decision log, and the current tests. This is a static review. No product files were changed and the slow widget tests were not rerun.

## Findings

1. **Private linked routes escape the pack.** `lib/services/engine/tax_pack_builder.dart:258` writes origin and destination for every linked trip into both expense indexes. `lib/services/engine/accountant_workpaper_generator.dart:139` repeats them in the workpaper. Neither checks whether the trip is business, so a linked personal or unclassified trip exposes the addresses despite the specification's private-route restriction. The privacy test creates a private trip but does not link an expense to it. Add linked personal and unclassified cases and inspect every textual pack entry.
2. **The workpaper conflates OCR matches with user confirmation.** `lib/services/engine/accountant_workpaper_generator.dart:71` counts both `verified` and `confirmed` as taxpayer verified without checking the current receipt file or fingerprint. Lines 109-113 describe the total as confirmed by the taxpayer and a verified business claim. A missing, changed, or OCR-only receipt can therefore be presented as a verified claim. Line 125 also asserts that deductions are substantiated even when review issues exist. Report each status and current file condition accurately and avoid certification language.
3. **Cloud receipt links are invented.** `lib/services/engine/tax_pack_builder.dart:204` constructs a public storage URL whenever a local path is present, including when that path is missing, with no proof of upload, object name, accessibility, or matching bytes. The workpaper and both expense indexes present it as a direct cloud link. Use only a verified stored reference, or omit it.
4. **The workpaper can show an uncorrected merchant.** `lib/services/engine/accountant_workpaper_generator.dart:135` uses OCR merchant text even after the user corrects and confirms the expense. The corrected value is saved in notes by `lib/ui/screens/expenses/expense_detail_screen.dart:440`, while the audit intentionally retains the original OCR text. Label OCR as such or export a separately persisted confirmed merchant.
5. **Review flow test is out of sync with the UI.** `test/ui/evidence_review_flow_test.dart:52` expects `1 item needs attention`, while `lib/ui/screens/evidence/evidence_review_screen.dart:219` renders a Thai summary. The test cannot reach its remaining navigation assertions as written. Update the test to assert the intended visible copy and run it.

## Verification limits

`test/tax_pack_builder_test.dart` inspects actual ZIP contents, receipt bytes, and a private-trip sentinel, but its private trip has no linked expense. `test/ui/tax_pack_share_flow_test.dart` exercises the helper with a mocked mail channel and reads the ZIP during dispatch. It does not establish real device mail/share attachment lifetime or cancellation behavior. The decision log records baseline tests and design choices, but does not yet record final passing checks. The parent reported that iOS simulator builds are blocked by an MLImage binary platform incompatibility and baseline analysis has eight known issues. Those reports were not independently rerun here.

## Comment Sicko review

Review-only pass over task-added comments. No comments were deleted. Recommend deleting three narration comments in `accountant_workpaper_generator.dart` at lines 8-9, 51, and 121. The added class documentation makes an unsupported accountant-grade claim rather than defining a public contract. The other two narrate code. The catch comment in `tax_pack_share_helper.dart` describes external temporary-file behavior and can stay. No scoped `MUST KILL` reshape flags identified. No suppression added in the scoped diff was identified.

## Recheck

The five original findings have been addressed in the current source. Both expense indexes and the workpaper mask linked non-business routes. The ZIP test now links expenses to a personal trip and scans all textual entries for its private sentinels. It does not separately link an unclassified trip, although the same `!isBusiness` branch masks it. The workpaper separates human confirmation from OCR matches and removes the verified claim and substantiation assertion. Constructed cloud links and OCR merchant output are removed. The review screen again renders the English text expected by the flow test. The task-added workpaper comments identified above were removed with the rewrite.

The CPK readiness card and summary now include expense issues, and their trip counts use scoped records. One remaining copy issue is that `lib/ui/screens/tax/tax_summary_screen.dart:621` describes every scoped drive as having a purpose, even though personal trips are exempt from that check and can have no purpose.

Two further issues need attention. `lib/services/engine/tax_pack_builder.dart:99` treats a file with no saved fingerprint as available, while `lib/services/engine/accountant_workpaper_generator.dart:68` calls available files unchanged. Without a saved digest, the export cannot establish that the bytes are unchanged. Also, `_cell` at `lib/services/engine/accountant_workpaper_generator.dart:107` escapes HTML, pipes, and line breaks but leaves Markdown link and formatting syntax active in user-provided addresses and identifiers. Escape Markdown metacharacters as well so the rendered workpaper presents literal values.

This recheck is static. No tests were rerun and no product files were edited.

## Final recheck

The remaining review notes are resolved in the current source. `accountant_workpaper_generator.dart:70` and `:72` say “available files” rather than claiming a fingerprint match where none is recorded. `_cell` at `:108` escapes Markdown link and formatting characters in addition to HTML and table delimiters; `accountant_workpaper_generator_test.dart:125` asserts the literal escaped output for a link, pipe, and HTML input. `tax_pack_builder_test.dart:217` links an unclassified trip to an expense and checks all textual entries for private route and purpose sentinels. `tax_summary_screen.dart:620` now says drives were recorded without asserting that each has a purpose.

The recorded `verification.log` ends the targeted suite at 113 passing tests and the rendering suite at three passing tests. It includes the editor confirmation, no-op save, and replacement test, and the helper share test. The log also contains caught warnings from uninitialized Supabase and missing location plugins in tests. The helper test uses mocked platform channels, so it does not prove native device attachment lifetime. This final recheck did not rerun tests or edit product code.

## Final resolver check and verdict

`trip_quick_resolve_sheet.dart:121` now saves an empty business purpose as empty rather than synthesizing one. The regression at `evidence_review_flow_test.dart:70` clears the field through the review flow, saves it, and asserts both the empty stored value and the remaining review item. No additional actionable finding arose in this limited recheck. The latest `verification.log` records 114 passing targeted tests and three passing rendering tests. I did not rerun them. Native device attachment lifetime remains unverified by the mocked share test, and the earlier simulator build limitation remains as reported by the parent.
