# Welcome / Get started redesign — 25 November 2026

User-approved copy revision: **Work kilometres. / Without the paperwork.**
Supporting text: “Record work trips, keep receipts together, and prepare records
for your accountant.” Replaces the initial generic “Less admin” headline.
Five focused layout/capture tests passed after this revision; rendered phone
preview inspected and hot reload sent.

## Research

- [Apple HIG: Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding): keep entry brief, teach through interaction and defer nonessential setup.
- [NN/g: Onboarding Tutorials vs Contextual Help](https://www.nngroup.com/articles/onboarding-tutorials/): explanatory tours create a memory burden; provide instruction when the user needs it.
- [NN/g: Mobile Tutorials](https://www.nngroup.com/articles/mobile-tutorials/): question whether a formal tutorial is necessary; interactive contextual approaches can support real tasks.

Sources checked for this task. The layout is an original design informed by
these principles, not a copied competitor screenshot or an assertion that one
visual style is universally superior.

## Four design requirements

1. **Hierarchy:** compact brand, expressive two-line benefit headline, concrete
   trip/receipt description, one large product preview, one primary action.
2. **Consistency/noise:** warm canvas, obsidian record card, restrained orange
   route/accent matching Login and Home. Removed multiple explanation paragraphs
   and horizontal rules from the previous preview.
3. **Progressive disclosure:** switch Work trip / Receipt to inspect local
   examples rather than a multi-page tutorial. Permission/account/vehicle flows
   remain in their existing later steps. Examples never write records.
4. **Navigation/ergonomics:** Get started remains pinned in a SafeArea footer,
   available during entrance animation. Main content scrolls at small heights,
   landscape and enlarged text; headline scale is reduced at large text without
   capping the user's text scaler.

## Real implementation and review loop

- Abstract route artwork draws once with the existing welcome timeline; receipt
  selection adds a paper illustration and changes sample details.
- Examples are explicitly labelled; sample amounts are not deductions/claims.
- Retained existing Get started callback and account/vehicle routing.
- Initial tests exposed an AnimatedSize layout failure at zero duration with
  Reduce Motion. Removed that animation; reduced motion has no active ticker.
- Rendered inspection exposed oversized marketing text on 320px/2× text; the
  headline and top gap now adapt, preserving the primary action.
- Final captures use bundled Inter, Material icons, AppTheme.light and iOS
  safe-area padding. Capture files live in
  `tool/design_audit/welcome_redesign/`.

## Verification

Final command and results are recorded below after the last rendered review.
Widget/integration-style tests do not verify production OAuth or native GPS.

- Final combined suite: **22 tests passed**, covering example switching, fixed
  CTA reachability, small/large text, landscape, brand assembly, Reduce Motion
  toggled mid-animation, and the existing guest/manual/vehicle setup flow.
- Focused `flutter analyze --no-pub` across source, layout test and capture
  harness: **No issues found**.
- Final rendered phone, receipt, compact and landscape previews inspected.
- `git diff --check` passed. Hot reload sent to the running Flutter app.
- Native simulator screenshot inspected after reload: new welcome is visible
  with both example selectors and Get started on screen. Saved as
  `tool/design_audit/welcome_redesign/simulator.png`.
- Existing Screens 1–4 onboarding route test passed after the copy update;
  Get started still leads through account/guest, permission choice and vehicle.
