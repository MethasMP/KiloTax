# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users
- Primary: Australian tradies, contractors, and sole traders (ute / commercial vehicle drivers).
- Secondary: Their tax agents and accountants who review deduction evidence at EOFY.

## Product Purpose
"Tax Evidence Tool for Australian Tradies" (KiloClaim).
Help Australian tradies and sole traders capture, review, explain and hand over connected vehicle-tax evidence: trips, receipts, job references and odometer records. Success means a user can complete the workflow with trustworthy records and recover from mistakes, not merely see a mileage total or a polished dashboard. Evidence completeness is not a guarantee of tax deductibility or acceptance.

## Workflow Quality Standard

- Primary journey: prepare vehicle/tracking → capture trips and expenses → review suggestions → resolve missing evidence → review the logbook period → preview and export an accountant pack.
- Prioritize Logbook workflows first. Evaluate CPK and method changes separately to preserve existing evidence.
- Compare task completion, error recovery, data provenance and accountant handoff with relevant market products. Feature lists and automated render tests do not prove comparable usability.
- Distinguish captured, inferred, manually entered and user-confirmed information. Missing information must remain visible rather than being presented as established evidence.
- Every critical workflow needs a clear start, successful outcome, cancel/retry path and persistence verification. Include offline use, permission loss, duplicates, wrong vehicle, corrections and export failure.
- Visual polish follows validated workflows; do not add decorative redesign work while critical evidence-flow gaps remain unresolved.

## Positioning
Not a generic mileage tracker with spreadsheets. KiloClaim is an audit-ready tax evidence engine specifically designed around ATO compliance rules (Logbook Method vs. Cents per km arbitrage, 5,000 km threshold caps, Bulky Tools exception, and immutable audit logs).

## Operating Context
- End of day in the ute cabin: 1-tap resolution, high contrast, large tap targets (minimum 48x48dp), zero tedious data entry.
- Direct accountant exports: ATO-compliant CSV/PDF export packs.
- High-noise GPS and sensor telemetry filtering with offline-first resilience.

## Capabilities and Constraints
- Dual deduction method management: Cents per Kilometre (CPK) vs. 12-week Logbook Method.
- Real-time method arbitrage recommendation (showing real dollar tax differences).
- Odometer photo proof capture & receipt scanner integration.
- Strictly mobile native (Flutter iOS/Android) with offline local SQLite storage and Supabase sync.
- Light mode first; dark mode explicitly deferred.

## Brand Commitments
- Name: KiloClaim (internal repo DriveLog).
- Voice: Calm, authoritative, precise, professional, zero panic ("Evidence over panic").
- Color Palette: Deep Navy (`surfaceNavy`), Slate/Ink neutrals, Crisp Emerald Green (`positiveBright`), Amber (`attention`).

## Evidence on Hand
- Full comprehensive design audit and blueprints in `docs/design/01-ui-ux-audit.md` and `docs/design/02-design-system.md`.
- Token implementations in `lib/core/theme/` (`app_color.dart`, `app_typography.dart`, `app_space.dart`, `app_motion.dart`).

## Product Principles
1. **One Hero per Screen**: Exactly one primary metric or primary action commands the viewport.
2. **Numbers are the Interface**: Tabular monospace-aligned figures, locale-formatted AUD currency, and explicit measurement units.
3. **Evidence Over Panic**: Single amber/red card above the fold at most, authoritative feedback, zero alarmist fatigue.
4. **Quiet Chrome, Loud Data**: Meaningful gradients only on hero cards; utilitarian, clean data presentation everywhere else.
5. **Zero-Friction Tradie Ergonomics**: Minimum 48x48dp touch targets, legible in direct sunlight, resilient at 200% dynamic text scale.

## Accessibility & Inclusion
- Minimum 48x48dp touch targets across all interactive elements.
- WCAG AA contrast standards for sunlight readability.
- Layout resiliency up to 200% dynamic text scaling without RenderFlex overflow.
