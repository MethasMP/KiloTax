# Record-keeping method screen — 26 November 2026

## Changes

- One main heading: “How will you keep your records?”
- Equal-weight choices describe what records to keep; orange indicates only
  an explicit selection, never a recommendation.
- No option is preselected. Save/continue is disabled until the user confirms
  an available method, including the single actual-expenses option.
- Choosing a different catalog/manual vehicle resets that confirmation.
- Compare methods is initially collapsed and uses short structured entries.
  Cars show logbook/CPK guidance; commercial-only screens show actual expenses.
- Primary action is in a SafeArea footer outside the scroll view. Expanding
  guidance and large text do not move it offscreen.
- Existing classification rules, tax calculations, vehicle fields and optional
  Bluetooth flow are retained. Subsequent screens accept the chosen method.

## Content references

Checked the primary ATO sources on 26 November 2026:

- [Logbook method](https://www.ato.gov.au/individuals-and-families/income-deductions-offsets-and-records/deductions-you-can-claim/work-related-deductions/cars-transport-and-travel/motor-vehicle-and-car-expenses/expenses-for-a-car-you-own-or-lease/logbook-method): representative logbook for at least 12 continuous weeks, odometer and expense records.
- [Cents per kilometre](https://www.ato.gov.au/individuals-and-families/income-deductions-offsets-and-records/deductions-you-can-claim/work-related-deductions/cars-transport-and-travel/motor-vehicle-and-car-expenses/expenses-for-a-car-you-own-or-lease/cents-per-kilometre-method): keep the basis for work kilometres; claim limit is 5,000 business kilometres per car per income year, not a recording limit.
- [Calculation methods](https://www.ato.gov.au/businesses-and-organisations/income-deductions-and-concessions/income-and-deductions-for-business/deductions/deductions-for-motor-vehicle-expenses/motor-vehicle-expense-calculation-methods): other-vehicle actual-cost distinction. This UI change does not revise the app's eligibility engine.

## Verification

Real-font/AppTheme.light renders cover normal phone, 320px at 2× text,
landscape at 2× text and commercial vehicle. Tests check no preselection,
disabled-save behavior, method-specific disclosure, fixed action position,
explicit method persistence, Bluetooth navigation and the full guest-to-Home
journey. Final results recorded after completion below.

- Final suite: **12 tests passed**, including the complete guest journey.
- Focused analysis: **No issues found**; diff whitespace check passed.
- Rendered phone/large-text/commercial previews inspected. Large text uses a
  smaller heading base size without limiting the user's text scaler.
- Sent hot reload to the existing running Flutter app. No real vehicle records
  were created by the preview tests; they use isolated callbacks.
