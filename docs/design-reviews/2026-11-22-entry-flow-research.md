# KiloClaim entry-flow research — 22 November 2026

## Scope and confidence
Desk research of official documentation and local routing code. No fresh competitor installs, participant interviews, lab sessions, or conversion experiments were performed. Support documents establish described flows, not exact current screen layouts or their effectiveness. Prior design suggestions are hypotheses, not evidence.

## Product context
DESIGN.md positions KiloClaim as tax evidence software for Australian tradies, contractors and sole traders. Current onboarding supports both account and guest entry, automatic and manual logging, and vehicle setup. A successful entry should lead to a usable first work-trip record and a correct understanding of tracking and record storage, rather than merely an auth completion.

## Evidence
- Apple onboarding guidance: keep prerequisite onboarding brief; teach through interaction and contextual tips; postpone nonessential setup. Does not prescribe one screen. https://developer.apple.com/design/human-interface-guidelines/onboarding
- Android permissions: request in feature context, explain why, avoid requesting every permission at startup. https://developer.android.com/training/permissions/usage-notes
- Driversnote account guide: mobile Get started leads to account creation, country and workplace setup. Does not establish that an extra login shortcut is useful in KiloClaim's shared OAuth flow. https://driversnote.helpscoutdocs.com/article/115-how-to-create-a-driversnote-account
- Driversnote Australia logbook configuration includes vehicle, business/personal trips, odometer and reporting needs. https://driversnote.helpscoutdocs.com/article/533-how-to-create-a-detailed-mileage-logbook-australia
- MileIQ quickstart: account, permissions, drive, classify, report. https://support.mileiq.com/hc/en-us/articles/18124154381844-MileIQ-Quickstart-Guide
- MileIQ new-device guide describes Get Started for returning users too. A label need not imply registration only. https://support.mileiq.com/hc/en-us/articles/205801699-How-to-put-MileIQ-on-a-new-device
- ATO myDeductions illustrates a local record-keeping model with explicit backup responsibilities. This is evidence of a different category model, not evidence of KiloClaim storage guarantees. https://www.ato.gov.au/api/public/content/0-e0652215-c939-4ad4-9a51-84ad9a5ad9e1
- Everlance business onboarding requires invitation/account setup; this enterprise context is a poor direct match for an independent tradie. https://help.everlance.com/hc/en-us/articles/45327070956571-Welcome-Series-Part-1-Getting-Started

## Local code findings
OnboardingSlidesScreen has both a Get started callback and a separately pushed SignInScreen. The former advances the parent state; the latter pops on auth success. These are different route implementations for substantially the same user decision. OnboardingFlowScreen also short-circuits to main when hasVehicle is true. Returning-user restoration and partial onboarding therefore need explicit coverage before altering routing. No change is justified solely by reducing screen count.

## Alternatives
1. Combined value proposition and provider entry: fewer transitions, but value explanation competes with account choice, guest explanation and legal controls. Useful comparator, not established winner.
2. Brief welcome with one Continue action, then shared account/guest selection: separates product understanding from identity decision; costs one transition. Lowest-risk baseline given current product and code.
3. Welcome Start setup bypasses auth; separate Sign in restores existing records: meaningfully distinct actions and early hands-on use, but requires validating local persistence, migration, recovery and backup explanations. Not a copy-only change.

## Provisional recommendation
Prototype option 2 first. Welcome has one Continue action; remove the duplicate returning-user link. Explain work-trip records and accountant handoff briefly, optionally with one compact clearly labelled example. Entry screen handles new and returning users through the same provider choices and an explicit guest option. Do not repeat the welcome pitch. Keep contextual permission explanation and manual entry. Preserve static logo at auth; optional nonblocking one-shot mark motion at welcome.

This is a design judgment based on available evidence, not a demonstrated niche preference. Option 1 should remain a comparator rather than be rejected by assumption.

## Validation before adopting a winner
Use counterbalanced prototypes with 5–8 relevant participants for formative learning (not statistical conversion proof): first-time sole trader, returning account holder/new phone, and manual/offline preference. Tasks: explain what the app does, start first work trip, recover records, choose manual tracking. Observe wrong turns, hesitation, backtracking, completion, first usable record, and understanding of tracking and guest storage. Set comparative success criteria before sessions. Do not select a winner from tap count alone.

## Implementation status
Research only. No application code changed during this investigation.
