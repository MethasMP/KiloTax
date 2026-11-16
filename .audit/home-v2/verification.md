# Home v2 implementation verification

Implemented the approved local Home concept in Flutter. No production fixtures or sample amounts were added to application code.

## Decisions

- Model the Domain. HomeRecordSummary distinguishes checked details from pending evidence and from export-time file inspection. TaxCalculatorService owns monetary calculations.
- Prove It Works. Actual Flutter widget renders and interaction tests verify navigation, capture entry, optional receipt linking, pending GPS drafts and narrow layouts.
- Existing AppState remains the sole owner of persisted records. Home implementation and navigation/capture implementation used disjoint files, then one integrated check.
- Full new design exploration was skipped because the user approved the interactive prototype. No commits or PR were created in this heavily modified checkout.

## Checks

- 36 targeted tests passed across home_v2_test, home_capture_flow_test, typography_navigation_layout_test, cpk_compliance_ux_test, expense_link_preservation_test and evidence_review_service_test.
- 2 selected MainScaffold/Home integration tests passed in ui_screens_18_test.
- Targeted analysis of 13 modified implementation/test files passed with no issues.
- Scoped git diff --check passed.
- Actual Flutter renders are first-day.png and daily-home.png. Values are test fixtures, not user records. Camera and GPS are not simulated as real-device verification.

## Behavior

Home shows a provisional deduction only when the selected method has sufficient checked detail. It excludes unresolved trips/expenses, labels ledger odometer readings honestly and shows elapsed logbook days rather than compliance. Receipt files are separately checked during export. Confirmed receipt details alone do not create a perpetual Home review badge for an inspection that has not yet run.

Capture opens existing scanner/OCR, GPS and past-trip routes. OCR trip matches require explicit acceptance. Configuring Bluetooth does not itself report a hardware connection. A completed positive-distance GPS recording is saved as unclassified before opening review. Zero distance never becomes an invented trip. Repeated finish calls cannot duplicate the draft.

## Limits

Real-device background GPS, Bluetooth, camera and OCR still require a device run. The broader existing test attempts failed in two onboarding expectations before the new capture path, including a removed Ford Ranger quick choice and old heading text. They are outside this Home change. The selected current Home/navigation tests pass. No whole-suite pass is claimed.
