---
name: KiloTax (DriveLog)
description: The Tax Evidence OS for Australian Tradies & Sole Traders
colors:
  surface-navy: "#0A1628"
  navy-raised: "#132338"
  navy-line: "#1E3452"
  brand: "#1E3A8A"
  brand-bright: "#2563EB"
  positive-bright: "#10B981"
  positive-tint: "#ECFDF5"
  attention: "#EA580C"
  attention-strong: "#C2410C"
  attention-tint: "#FFF7ED"
  critical: "#DC2626"
  critical-strong: "#B91C1C"
  critical-tint: "#FEF2F2"
  ink: "#0F172A"
  muted: "#64748B"
  line: "#E2E8F0"
  surface: "#FFFFFF"
  surface-muted: "#F8FAFC"
typography:
  metric-xl:
    fontSize: "72px"
    fontWeight: 700
    lineHeight: 1.0
  metric:
    fontSize: "44px"
    fontWeight: 700
    lineHeight: 1.05
  title:
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.18
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
  huge: "48px"
components:
  touch-target-minimum:
    height: "48px"
    width: "48px"
---

# KiloTax Design System

## Iconography

- Use Lucide for application icons. Shared meanings live in `lib/core/theme/app_icons.dart`; prefer `AppIcons` semantic names over per-screen choices.
- Size roles: `AppIconSize.inline` 16dp, `control` 20dp, `navigation` 24dp, `feature` 32dp. Glyph size is independent of the minimum 48dp interactive area.
- Consistent meanings: Home = house, Trips = route, vehicle = car front, Logbook = book, Expenses = receipt, Tax = document, odometer = gauge, photo capture = camera.
- Keep the same navigation glyph for selected and unselected states. Selection uses an orange-tinted background, dark content and the existing selected semantics; do not mix Material filled glyphs with Lucide outlines.
- Green check states describe saved or confirmed evidence. Attention states use a labelled alert icon. Never communicate status through color alone.
- Applied to Logbook and the shared navigation, header, recent activity, quick capture, Trips, Expenses and Tax surfaces. Other legacy screens can adopt these aliases as they are revised.

## Overview
KiloTax is the tax evidence OS purpose-built for Australian tradies, contractors, and sole traders.
Ergonomics are designed for an exhausted driver sitting in a ute at 5:00 PM with dirty hands under harsh Aussie sun glare.

## Colors
- **Surface Navy (`#0A1628`)**: Primary authoritative background for hero cards, speedometer telemetry, and summary pills.
- **Emerald Green (`#10B981`)**: Positive tax claim accumulation and audit readiness indicators.
- **Attention Amber (`#EA580C`)**: Actionable items requiring 1-tap review (missing trip purpose).
- **Critical Crimson (`#DC2626`)**: Severe compliance risks (exceeded 5,000 km statutory CPK cap).

## Typography
- **Strict 9-tier Type Scale**: Defined in `lib/core/theme/app_typography.dart`. Raw `TextStyle` with off-grid half-pixel sizes (`.5`) are strictly prohibited.
- **Tabular Figures Required**: All financial metrics, odometer km, and timers must carry `fontFeatures: [FontFeature.tabularFigures()]` to eliminate horizontal text jitter.

## Layout
- **Gutter**: Screen horizontal padding follows `S.gutter` (20px).
- **Card Padding**: Standard card internal padding is `S.cardPad` (20px).
- **Hero Priority**: Exactly one hero metric or primary CTA per viewport.

## Elevation & Depth
- Subtle Old-Money ambient elevations with `AppColor.scrimSoft/scrimMedium`. No harsh or noisy shadows.

## Shapes
- `R.chip`: 8px for status pills and category badges.
- `R.control`: 10px for input fields, buttons, and segmented controls.
- `R.card`: 16px for data cards and alert containers.
- `R.sheet`: 24px for modal bottom sheets.

## Components
- **Touch Target Floor**: Minimum **48x48dp** interactive area for all buttons, chips, icons, and list tiles.
- **Quick Resolve Grid**: 2x2 grid (maximum 4 options) for trip classifications.

## Do's and Don'ts
- **DO** use `AlertDialog.adaptive` before destructive actions like discarding rescued in-flight trips.
- **DO** provide `Semantics(button: true, label: ...)` on all custom `InkWell` and `GestureDetector` widgets.
- **DO** prioritize alerts: show 1 primary alert + compact secondary rows to prevent alert stacking fatigue.
- **DON'T** write raw hex `Color(0x...)` or raw `TextStyle` in screen files.
- **DON'T** let hero numbers overflow at 200% dynamic text scale; always wrap in `FittedBox`.

## Typography usage

Use Inter throughout. Reserve 700 for page titles and primary metrics; use 600 for card titles and actions, 400 for body and supporting text, and 500 for compact metadata when needed. Body text uses 16 logical pixels with normal tracking; essential supporting text uses 14. Keep negative tracking on large titles and metrics only. Numeric columns and live metrics use tabular figures. Use sentence case for descriptive labels and reserve uppercase for short status badges. Navigation labels use 12 with content-driven height.
