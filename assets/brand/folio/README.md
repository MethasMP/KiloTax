# KiloClaim / Folio

Approved direction: Folio (02), refined from the concept board into three solid folded planes. Open channels preserve the silhouette at small sizes. No gradients or shadows are baked into the mark.

- Vermilion mark and app tile: `#E74716`.
- Aubergine wordmark and monochrome mark: `#351329`.
- Wordmark: bundled Inter Bold; Flutter renders live text for accessibility and scaling.
- `folio-mark.svg`: transparent full-colour mark used by the welcome header.
- `folio-mono.svg`: single-colour mark.
- `folio-app-icon.svg`: opaque square master; iOS applies its own mask.
- `folio-preview.png`: identity preview, not a device screenshot.

Regenerate assets from the repository root with `node tool/brand/build_folio.cjs`. This also writes `assets/icon_master.png`, the 15 referenced iOS icon sizes and five Android launcher densities. Android exports include rounded transparent corners; iOS exports are opaque.

Figma header: https://www.figma.com/design/fE7xqIW6qjn1H2P95BBD16?node-id=1-2

## Product placement and typography

The shared `AppBrand` tokens define Inter Bold at 24px / -0.7 tracking (welcome and sign-in) and 20px / -0.5 tracking (Home and root Settings). Live text respects system text scaling. These are identity styles; body copy and controls retain the app's semantic type scale.

Use the full lockup on welcome, sign-in, Home and root Settings. Native launch screens use only the mark. Task screens retain their functional titles. Legacy animated logo widgets render the same vector app tile. Android tracking notifications use a dedicated monochrome Folio silhouette.

The generator also exports iOS launch marks at 1x/2x/3x and Android vector artwork for launch, adaptive launcher and notifications. Platform XML config lives in the native source folders.

## Welcome assembly motion

Only Welcome opts into the animated Folio mark. Three planes enter lower-to-upper at 0/80/160ms with 400ms eased fades and 6px upward travel, finishing at 560ms. The existing welcome timeline drives the painter. Wordmark and layout remain stationary; Reduce Motion shows the completed mark and does not replay after toggling back off. All other brand placements are static.

Plan, team ownership, review and verification: `docs/design/folio-welcome-motion.md`.
