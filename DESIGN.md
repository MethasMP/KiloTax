---
name: KiloClaim (DriveLog)
description: The Tax Evidence OS for Australian Tradies & Sole Traders
theme: Obsidian & Terracotta
colors:
  canvas: "#FAF9F6"
  surface: "#FFFFFF"
  surface-muted: "#F5F4F1"
  surface-sunken: "#E7E5E4"
  surface-navy: "#18181B"
  navy-raised: "#27272A"
  navy-line: "#3F3F46"
  ink: "#18181B"
  ink-muted: "#52525B"
  ink-subtle: "#71717A"
  on-navy: "#FFFFFF"
  on-navy-muted: "#D4D4D8"
  line: "#D6D3D1"
  hairline: "#E7E5E4"
  brand: "#C2410C"
  brand-bright: "#EA580C"
  brand-tint: "#FFF1E8"
  brand-tint-strong: "#FFDFC9"
  positive: "#15803D"
  positive-strong: "#166534"
  positive-tint: "#ECFDF5"
  positive-bright: "#10B981"
  positive-ink: "#065F46"
  attention: "#D97706"
  attention-strong: "#B45309"
  attention-tint: "#FEF3C7"
  attention-tint-soft: "#FFFBEB"
  attention-ink: "#92400E"
  critical: "#DC2626"
  critical-strong: "#B91C1C"
  critical-tint: "#FEF2F2"
  critical-ink: "#991B1B"
typography:
  metric-xl:
    fontSize: "72px"
    fontWeight: 700
    lineHeight: 1.0
  metric:
    fontSize: "44px"
    fontWeight: 700
    lineHeight: 1.05
  metric-small:
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.15
  title:
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.18
  title-small:
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.25
  section:
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.2
  card-title:
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
  secondary:
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  caption:
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.3
  eyebrow:
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.3
rounded:
  chip: "8px"
  control: "10px"
  card: "16px"
  sheet: "24px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  xxxl: "32px"
  huge: "48px"
components:
  touch-target-minimum:
    height: "48px"
    width: "48px"
---

# KiloClaim Design System (Obsidian & Terracotta)

## Overview
KiloClaim is the Tax Evidence OS purpose-built for Australian tradies, contractors, and sole traders.
The design theme is **Obsidian & Terracotta**:
- Warm linen canvas with neutral stone text hierarchy.
- Restrained terracotta orange (`#C2410C` / `#EA580C`) for primary CTAs and brand identity.
- High-contrast authoritative obsidian (`#18181B`) for telemetry hero cards and audit status.
- Ergonomically tuned for an exhausted tradie in a ute under harsh Aussie sun glare (tested at 320px viewport and 200% dynamic text scale).

---

## Color Palette & Token Mapping (`lib/core/theme/app_color.dart`)

### Surfaces & Backgrounds
- **Canvas (`#FAF9F6`)**: Warm off-white page background (`AppColor.canvas`).
- **Surface (`#FFFFFF`)**: Pure white card background (`AppColor.surface`).
- **Surface Muted (`#F5F4F1`)**: Soft contrast background for secondary blocks (`AppColor.surfaceMuted`).
- **Surface Sunken (`#E7E5E4`)**: Recessed areas and search/input container fills (`AppColor.surfaceSunken`).
- **Surface Navy / Obsidian (`#18181B`)**: Authoritative dark container for hero cards, summary meters, and compliance dossiers (`AppColor.surfaceNavy`).
- **Navy Raised (`#27272A`)**: Raised obsidian cards and audit pill backgrounds (`AppColor.navyRaised`).
- **Navy Line (`#3F3F46`)**: High-contrast borders within dark cards (`AppColor.navyLine`).

### Content & Typography Colors
- **Ink (`#18181B`)**: Primary text color meeting WCAG AA against linen canvas (`AppColor.ink`).
- **Ink Muted (`#3F3F46`)**: Secondary descriptive copy (`AppColor.inkMuted`).
- **Ink Subtle (`#52525B`)**: Captions, timestamps, and placeholder copy tuned for sunlight readability (`AppColor.inkSubtle`).
- **On Navy (`#FFFFFF`)**: Pure white text for dark hero cards (`AppColor.onNavy`).
- **On Navy Muted (`#D4D4D8`)**: Subdued metadata text on dark cards (`AppColor.onNavyMuted`).

### Brand & Accents (Terracotta)
- **Brand (`#C2410C`)**: High-contrast Terracotta action color with white text contrast (`AppColor.brand`).
- **Brand Bright (`#EA580C`)**: Vibrant accent for active indicators and selection states (`AppColor.brandBright`).
- **Brand Tint (`#FFF1E8`)**: Warm orange-tinted background for active navigation pills and chips (`AppColor.brandTint`).

### Semantic Compliance Colors
- **Positive (`#15803D`) / Positive Bright (`#10B981`)**: Verified ATO audit trails and confirmed deductions.
- **Attention (`#D97706`) / Attention Strong (`#B45309`)**: Actionable items (e.g. unreviewed trips, missing purpose).
- **Critical (`#DC2626`) / Critical Strong (`#B91C1C`)**: Statutory cap breaches (CPK 5,000 km) and invalid logbooks.

---

## Typography Scale (`lib/core/theme/app_typography.dart`)
Font Family: **Inter** throughout the application.

1. **`metricXL` (72px / w700 / -1.8 letter spacing)**: Full-bleed live odometer readout with tabular figures.
2. **`metric` (44px / w700 / -1.0 letter spacing)**: Chronograph hero deduction readout (`MoneyDisplay`).
3. **`metricSmall` (20px / w700 / -0.3 letter spacing)**: Compact metric readouts for telemetry and pills.
4. **`title` (28px / w700 / -0.5 letter spacing)**: Screen title and modal headline.
5. **`titleSmall` (22px / w700 / -0.3 letter spacing)**: Secondary headings and section titles.
6. **`section` (20px / w600 / -0.3 letter spacing)**: Section group headers inside lists.
7. **`cardTitle` / `cardNumeric` (17px / w600 / 0 letter spacing)**: Card headers and list primary text.
8. **`body` (16px / w400 / 0 letter spacing)**: Primary explanatory copy and form fields.
9. **`secondary` (14px / w400 / 0 letter spacing)**: Subtitle metadata, dates, and badges.
10. **`caption` / `eyebrow` (12px / w400 & w600 / 0 letter spacing)**: Footnotes and category tags.

> **Rule:** All numeric readouts carry `FontFeature.tabularFigures()` (`AppType.tabular`) to eliminate jitter during live tracking.

---

## Spacing & Elevation (`lib/core/theme/app_space.dart`)
- **Spacing Grid**: 4pt increments (`xxs: 2`, `xs: 4`, `sm: 8`, `md: 12`, `lg: 16`, `xl: 20`, `xxl: 24`, `xxxl: 32`, `huge: 48`).
- **Page Gutter**: `S.gutter` = 20px horizontal padding.
- **Card Padding**: `S.cardPad` = 20px uniform internal padding.
- **Corner Radii (`R`)**:
  - `R.chip` (8px): Badges and status pills.
  - `R.control` (10px): Buttons, text inputs, and segmented selectors.
  - `R.card` (16px): Content cards and evidence preview tiles.
  - `R.sheet` (24px): Bottom sheets and floating nav bars (`BorderRadius.circular(24)`).
- **Elevations (`AppElevation`)**:
  - `AppElevation.card`: Soft ambient cashmere shadow (`0x0C181B1F`, blur 18, offset y=4).
  - `AppElevation.floating`: High-floating shadow for the bottom nav bar and Quick Scan FAB.

---

## Iconography & Interactive Semantics (`lib/core/theme/app_icons.dart`)
- **Library**: Lucide outline iconography.
- **Standard Roles**:
  - Home: `AppIcons.home`
  - Trips: `AppIcons.trips`
  - Scan / Quick Action: Center floating scan button
  - Expenses / Receipts: `AppIcons.expenses`
  - Tax & Evidence: `AppIcons.tax`
- **Touch Target Floor**: Minimum **48x48dp** interactive area for all tappable controls.
- **Accessibility & Contrast**:
  - Never communicate status through color alone (always combine with icons and text labels).
  - Explicit `Semantics(button: true, label: ...)` on all custom ink touches.

## Folio brand identity

KiloClaim uses the approved Folio mark: three folded planes in vermilion `#E74716`, paired with an aubergine `#351329` wordmark. Assets and regeneration instructions live in `assets/brand/folio/README.md`.

Use `KiloClaimBrandLockup` for welcome and sign-in, and its compact variant on Home and root Settings. `KiloClaimBrandMark` supplies the standalone mark or app tile. Typography is centralized in `AppBrand`: bundled Inter Bold, restrained negative tracking, mixed-case `KiloClaim`, system text scaling. General UI typography remains in `AppType`; the brand palette does not replace semantic action/status colours.
