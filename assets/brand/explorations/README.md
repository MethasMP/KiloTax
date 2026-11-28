# KiloClaim icon exploration

Three editable vector concepts, exported at 1024 px:

1. **K / route** — recommended: the name initial with a route endpoint.
2. **Route / record** — an abstract journey cut through a record.
3. **Reviewed trip** — a route leading to a review check.

`icon-comparison.png` and `.svg` compare the primary silhouettes, 60 / 40 / 29 px sizes, schematic Home Screen context and a K colour alternative. Context panels are drawings, not device screenshots. Review small icons at 100% zoom.

Colours: Obsidian `#18181B`, warm white `#FAF9F6`, orange `#EA580C`. The orange-background alternative uses `#C2410C`.

These are concept assets. Production iOS and Android launcher files have not been replaced. Once selected, refine optical balance and produce platform appearance and adaptive-icon variants.

Rebuild with `node tool/brand/build_icon_concepts.cjs` using the `sharp` package (local installation or Codex's bundled runtime). Geometry lives in the generator and exported SVGs.

## Welcome motion

The Flutter welcome illustration draws a route once, then completes a review check. Headline and supporting copy fade and translate by at most 8 logical pixels. Total entrance: 800 ms. The start/sign-in controls are available immediately. Reduce Motion shows the completed static state without an animation ticker, including when the preference changes while the entrance is running.

Preview: `tool/design_audit/motion_captures/onboarding-motion.gif`. The GIF replays for review; the app entrance plays once per welcome-screen mount. Captures are widget renders, not recordings from a device.
