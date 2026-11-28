# Login redesign — 25 November 2026

## Why the previous iteration failed

It kept the same page architecture: brand, a large gap, paragraphs, provider
buttons and more paragraphs. Changing copy and spacing did not create a new
visual hierarchy or improve the position of the actions sufficiently.

## Research and design decisions

Sources were checked on 25 November 2026. Product help pages document actual
sign-in flows; they are not evidence of their precise screen appearance.
Linear and Notion login URLs returned JavaScript shells to the web reader, so
their visual layouts were not used as evidence.

| Source | Finding | Application |
| --- | --- | --- |
| [Apple HIG: Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple) | Explain sign-in value briefly, preserve recognizable provider controls and allow useful access before commitment where appropriate | Brief backup benefit, visible Apple button, guest access retained |
| [Google branding](https://developers.google.com/identity/branding-guidelines) | Branded label/logo, similar prominence to other providers | Both providers remain full-width and directly accessible |
| [NN/g: Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/) | Defer secondary details until requested | Returning-account help and device-only guest explanation in secondary sheets |
| [Slack: Sign in](https://slack.com/help/articles/212681477-Sign-in-to-Slack) | Existing Apple/Google accounts are supported sign-in routes | Keep familiar provider names; do not introduce another password form |
| [Dropbox: Google Sign-In](https://help.dropbox.com/account-access/google-sign-in) | Existing-account identity matters across login and signup | Returning-user help explains choosing the same provider/account |

## New architecture

1. Dark brand/benefit area with a short headline and a decorative illustration
   of trips and receipts, rather than a wall of explanatory copy.
2. A warm rounded action area near the bottom of the phone, with both provider
   actions grouped and visible.
3. A quieter guest route; device-only limitations are explained before entry.
4. Returning-user guidance is available when requested. Legal consent and links
   remain visible rather than hidden in help.

This is a design judgment informed by the sources, not a claim that dark heroes
or rounded action surfaces are universally better. Success is assessed through
clear hierarchy, less persistent text, action reachability and rendered output.

## Validation gates

- Actual Flutter render with Inter and AppTheme.light; realistic iOS safe areas.
- 390×844, 320×568 at 1×/2× text, landscape at 2× text.
- Auth pending disables competing entry actions; cancellation restores them.
- Guest confirmation is required before guest callback; help and both legal
  destinations remain functional and reachable.
- Visual review and correction after rendering, then local simulator reload.

Production OAuth and App Store publishing are outside this UI verification.

## Implementation and review

- Implemented a new dark hero with white branding, a route-to-receipt
  illustration and a warm rounded action surface anchored toward the bottom.
- Guest storage consequences and returning-account guidance use separate
  scrollable bottom sheets. Legal links remain on the main page.
- UX review found the auth-error Guest action bypassed the new confirmation;
  the integrator routed it through the same guest disclosure.
- Focused source analysis passed. Final responsive/interaction test result is
  recorded after the run below.
- Reloaded the running iPhone 17 Pro Max simulator through Flutter hot reload;
  captured and inspected `tool/design_audit/login_captures/login_simulator.png`.
  The screenshot shows the new implementation, including native system bars.
- Initial redesigned run passed seven tests. Visual inspection then exposed
  a problem tests had missed: 2× text on a small display made the marketing
  headline consume the initial viewport. The hero now collapses to the brand
  on short screens or large text, prioritizing the actual sign-in controls.
  The final run regenerates captures and checks initial action visibility.
- Final post-compact run passed all **7 tests**, including the initial Apple
  visibility assertion on 320×568 at 2× text and the failed-auth guest path.
  Both safe-area PNGs were inspected. Final focused source analysis reported
  **No issues found**. Latest code was hot reloaded into the simulator.
