# KiloClaim Design System — พิมพ์เขียวสู่ระดับ Frontier

> เอกสารนี้คือ **คำตอบของคำถาม "แล้วควรออกแบบยังไง"**
> ไม่ใช่ทฤษฎี — ทุกค่าที่ระบุที่นี่คือค่าที่คัดมาแล้วสำหรับแอปนี้โดยเฉพาะ
> ใช้คู่กับ [`01-ui-ux-audit.md`](./01-ui-ux-audit.md) (สิ่งที่ต้องแก้ และหลักฐาน)

---

## 0. ปรัชญาการออกแบบ 6 ข้อ

หลักการเหล่านี้ใช้ตัดสินทุกครั้งที่ลังเลว่า "ควรทำแบบไหน" — ไม่ต้องมีทักษะออกแบบก็ตัดสินได้

### 1. หนึ่งจอ มีพระเอกหนึ่งเดียว
ทุกหน้าจอต้องมี **ตัวเลขหรือการกระทำหนึ่งอย่าง** ที่เด่นกว่าอย่างอื่นชัดเจน
ถ้าทุกอย่างเด่นเท่ากัน = ไม่มีอะไรเด่น
> ใช้กับ: Home (hero ต้องอยู่บนสุดเสมอ), Tax Summary (ยอดหักลดหย่อนต้องเป็น hero)

### 2. หลักฐานมาก่อนความตื่นตระหนก
ผลิตภัณฑ์นี้ขาย "ความมั่นใจว่าจะผ่านการตรวจสอบ" ดังนั้นโทนต้อง **นิ่ง มืออาชีพ แม่นยำ**
ไม่ใช่ "เตือนตลอดเวลา" — เตือนมากเกินไปทำให้ผู้ใช้ชินและเลิกอ่าน
> กติกา: **การ์ดเตือน (amber/red) เหนือ fold ได้ไม่เกิน 1 ใบ** และต้องมี **CTA เดียว**

### 3. ตัวเลขคืออินเทอร์เฟซ
ในแอปภาษี ตัวเลขคือผลิตภัณฑ์ ตัวเลขต้อง:
- ใช้ **tabular figures** (ความกว้างเท่ากันทุกหลัก) → ไม่สั่นเมื่ออัปเดต
- จัดตำแหน่งทศนิยมตรงกันในคอลัมน์
- มีหน่วยติดเสมอ (`km`, `AUD`, `¢/km`)
- ใช้ `intl` + `NumberFormat.currency(locale: 'en_AU')` ไม่ใช่ regex เอง

### 4. Chrome เงียบ ข้อมูลดังก์
gradient, bezel, เงานุ่ม, เงาวิ่ง — ใช้เฉพาะที่ **สื่อความหมาย**
(เช่น hero card ที่เป็น "พระเอก" ได้ gradient ได้ ส่วนการ์ดข้อมูลธรรมดาไม่ต้อง)
ของตกแต่งที่ไม่สื่ออะไร = ตัดออก

### 5. ทุกสถานะถูกออกแบบ
`loading` / `empty` / `partial` / `error` / `offline` / `permission-denied` / `success`
**การไม่มีข้อมูล ≠ การโหลดไม่สำเร็จ** และทั้งสองอย่างต้องหน้าตาต่างกัน
> นี่คือช่องว่างที่ใหญ่ที่สุดของแอปในตอนนี้ (ดู audit §5)

### 6. เข้าถึงได้ตั้งแต่โครงสร้าง ไม่ใช่ของแถม
- เป้าแตะ ≥ 48×48dp
- ทุกคอนโทรลมี `Semantics` label
- เลย์เอาต์ต้องไม่พังถึง **text scale 200%**
- ห้ามใช้ "สี" เป็นตัวบอกข้อมูลอย่างเดียว ต้องมีข้อความ/ไอคอนกำกับ

---

## 1. Typography

### 1.1 ปัญหาที่ต้องเข้าใจก่อน
ตอนนี้แอปมี **27 ขนาดตัวอักษร** และ **133 จุดที่เป็นครึ่งพิกเซล** (11.5, 12.5, 13.5…)
ปัญหาคือขนาด 11 ถึง 17 ห่างกันทีละ 0.5–1px ซึ่ง **ตาก็แยกไม่ออก** → จ่ายราคาของ 27 ขนาด แต่ได้ลำดับชั้นแค่ 4 ระดับ

**เป้าหมาย: 9 ระดับ ที่ตามองเห็นความต่างได้จริง**

### 1.2 Scale ที่แนะนำ — แทนที่ `AppTextStyles` ทั้งบล็อก

```dart
// lib/core/theme/app_typography.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 9-tier role-based type scale. Replaces the previous 15-token / 27-size sprawl.
///
/// Rules:
///  - Never write a raw `fontSize:` in a screen file. If nothing fits, add a tier.
///  - All numeric styles carry [tabular] so live values never jitter.
///  - Every paragraph style sets `height` — otherwise vertical rhythm drifts.
class AppType {
  AppType._();

  /// Tabular figures: digit glyphs share one advance width, so a live
  /// odometer/dollar value does not shift horizontally as digits change.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// 44 / w700 / -1.2 / 1.05 — the single hero number on a screen.
  /// Use once per screen. Examples: home tax deduction, live drive distance.
  static const TextStyle metric = TextStyle(
    fontSize: 44, height: 1.05, fontWeight: FontWeight.w700,
    letterSpacing: -1.2, fontFeatures: tabular, color: AppColors.deepNavy,
  );

  /// 28 / w700 / -0.6 / 1.15 — screen title (AppBar) and modal headline.
  static const TextStyle title = TextStyle(
    fontSize: 28, height: 1.15, fontWeight: FontWeight.w700,
    letterSpacing: -0.6, color: AppColors.ink,
  );

  /// 20 / w600 / -0.4 / 1.2 — section heading inside a scroll view.
  static const TextStyle section = TextStyle(
    fontSize: 20, height: 1.2, fontWeight: FontWeight.w600,
    letterSpacing: -0.4, color: AppColors.ink,
  );

  /// 17 / w600 / -0.2 / 1.3 — card headline / list-row primary text.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 17, height: 1.3, fontWeight: FontWeight.w600,
    letterSpacing: -0.2, color: AppColors.ink,
  );

  /// 15 / w400 / -0.1 / 1.45 — body copy, paragraphs, helper text.
  static const TextStyle body = TextStyle(
    fontSize: 15, height: 1.45, fontWeight: FontWeight.w400,
    letterSpacing: -0.1, color: AppColors.ink,
  );

  /// 15 / w600 / -0.1 / 1.3 — inline emphasis within body copy.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15, height: 1.3, fontWeight: FontWeight.w600,
    letterSpacing: -0.1, color: AppColors.ink,
  );

  /// 13 / w500 / 0 / 1.35 — secondary/meta text, list-row subtitle.
  static const TextStyle secondary = TextStyle(
    fontSize: 13, height: 1.35, fontWeight: FontWeight.w500,
    letterSpacing: 0, color: AppColors.muted,
  );

  /// 11 / w700 / +0.6 / 1.1 — ALL-CAPS eyebrow above a value.
  /// Positive tracking is required: uppercase letters need optical space.
  static const TextStyle eyebrow = TextStyle(
    fontSize: 11, height: 1.1, fontWeight: FontWeight.w700,
    letterSpacing: 0.6, color: AppColors.muted,
  );

  /// 11 / w600 / 0 / 1.0 — bottom navigation label. Set `maxLines: 1`
  /// + `overflow: ellipsis` at the call site so 200% text scale cannot overflow.
  static const TextStyle navLabel = TextStyle(
    fontSize: 11, height: 1.0, fontWeight: FontWeight.w600,
    letterSpacing: 0, color: AppColors.muted,
  );

  /// Numeric variant of [cardTitle] — for aligned money column values.
  static const TextStyle cardNumeric = TextStyle(
    fontSize: 17, height: 1.3, fontWeight: FontWeight.w600,
    letterSpacing: -0.2, fontFeatures: tabular, color: AppColors.ink,
  );
}
```

**การแมปจากของเดิม:**

| ของเดิม (มีปัญห) | ใช้ตัวใหม่ | หมายเหตุ |
|---|---|---|
| `AppTextStyles.heroNumber` (42/w600) | `AppType.metric` (44/w700) | +tabular |
| `AppTextStyles.pageTitle` (28/w600) | `AppType.title` (28/w700) | เพิ่ม `height` |
| `AppTextStyles.greeting` (26/w600) — **ไม่เคยถูกใช้** | `AppType.title` | ใช้ `title` ที่เด่นกว่า |
| `AppTextStyles.sectionTitle` (20/w600) | `AppType.section` | |
| `AppTextStyles.cardPrimary` (16/w500-600) | `AppType.cardTitle` (17/w600) | |
| `AppTextStyles.body` (15/w400) — **ไม่เคยถูกใช้** | `AppType.body` | บังคับใช้จริง |
| `AppTextStyles.secondary` (14/w400) | `AppType.secondary` (13/w500) | |
| `AppTextStyles.caption` (12/w400) | `AppType.secondary` | ลบขนาด 12 ออก |
| `AppTextStyles.bottomNav` (12/w500) — **ไม่เคยถูกใช้** | `AppType.navLabel` | |
| `AppTextStyles.labelBold`, `heroTitle` — **ไม่เคยถูกใช้** | ลบ | |
| `AppTextStyles.button` (15/w600) | `AppType.bodyStrong` | |

**ลบขนาดเหล่านี้ออกทั้งหมด:** 9.5, 10, 10.5, 11.5, 12, 12.5, 13.5, 14, 14.5, 15.5, 16, 16.5, 18, 19, 22, 24, 26, 32, 34, 36, 42, 72
(เหลือ 44, 28, 20, 17, 15, 13, 11 — และ 72 ใช้เฉพาะ live tracking ที่เป็น hero เต็มจอ ซึ่งให้เป็น tier พิเศษ `metricXL` ได้ถ้าจำเป็น)

### 1.3 กติกา w800 / w900
ตอนนี้มี `FontWeight.w800` 90 จุด และ `w900` 60 จุด
ถ้าไม่บันเดิลฟอนต์ที่มี weight เหล่านี้ **ทั้งสองจะแสดงเหมือนกัน** (ฟอนต์สังเคราะห์)
→ **เลือกหนึ่ง:**
- **ทาง A (แนะนำ):** บันเดิล Inter ครบ 400/500/600/700/800/900
- **ทาง B:** ลด `w800`/`w900` ทั้งหมดเป็น `w700` แล้วใช้ *ขนาด* + *สี* สร้างความเด่นแทนน้ำหนัก

อย่าเก็บ `w800`/`w900` ไว้โดยไม่มีฟอนต์รองรับ — มันคือการโกหกในโค้ด

### 1.4 ฟอนต์: บันเดิล Inter (หรือเลิกอ้างว่าใช้ Inter)

ปัจจุบัน `main.dart:58` ตั้ง `fontFamily: 'Inter'` แต่ `pubspec.yaml` **ไม่มีบล็อก `fonts:` เลย**
→ Inter ไม่เคยถูกใช้จริง แอปไปใช้ SF Pro (iOS) / Roboto (Android) แทน
→ ตัวอักษร **ไม่เหมือนกันข้ามแพลตฟอร์ม** → จุดที่ `maxLines: 1` + ellipsis ตัดบรรทัดไม่เหมือนกัน → เป็นบั๊ก ไม่ใช่แค่ความสวย

**วิธีแก้:**

```yaml
# pubspec.yaml — ต่อท้ายบล็อก flutter:
flutter:
  uses-material-design: true
  assets:
    - google.svg
    - apple.svg
    - assets/icon_master.png
    - assets/vehicles/
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf      # w400
        - asset: assets/fonts/Inter-Medium.ttf       # w500
        - asset: assets/fonts/Inter-SemiBold.ttf     # w600
        - asset: assets/fonts/Inter-Bold.ttf         # w700
        - asset: assets/fonts/Inter-ExtraBold.ttf    # w800
        - asset: assets/fonts/Inter-Black.ttf        # w900
```

วางไฟล์ไว้ที่ `assets/fonts/` (ดาวน์โหลดจาก https://fonts.google.com/specimen/Inter — OFL license ใช้เชิงพาณิชย์ได้)
**ตรวจสอบว่าได้ผล:** หลัง build ให้เปิด `build/ios/.../FontManifest.json` ต้องเห็น `"Inter"` อยู่ในรายการ

> **ทางเลือกถ้าไม่อยากเพิ่มขนาดแอป (~600KB):** ลบ `fontFamily: 'Inter'` ออกแล้ว **ยอมรับ** ฟอนต์ระบบ
> แต่ต้องเปลี่ยน `letterSpacing` ทั้งหมดให้เหมาะกับ SF Pro/Roboto และลบ `w800`/`w900` ออก
> **ห้ามทำครึ่งทาง** (อ้าง Inter แต่ไม่บันเดิล) — นั่นคือสถานะปัจจุบันที่เป็นปัญหา

### 1.5 ตัวเลขต้องเป็น tabular — จุดที่ต้องแก้

```dart
// ตัวอย่าง: hero card
Text(
  Formatters.currency(total),
  style: AppType.metric,   // มี tabular ติดมาแล้ว
)
```

7 จุดที่ตัวเลขอัปเดตสดและ **ต้อง** มี tabular:
- `tax_shield_hero_card.dart:132, 168, 176, 280, 341`
- `home_telemetry_capsule.dart:167, 184`

---

## 2. Color

### 2.1 หลักการ: ชื่อ token ต้องบอก *บทบาท* ไม่ใช่ *ค่า*
ตอนนี้ 11 จาก 26 token เป็นชื่อซ้ำของค่าเดียวกัน (`brandElectric` = `telemetryReady` = `0xFF2563EB`)
ชื่อแบบนี้ไม่ให้ข้อมูลอะไร และทำให้คนเขียนโค้ดต้องเดาว่าจะใช้ตัวไหน

### 2.2 โครงสร้างสีที่แนะนำ

```dart
// lib/core/theme/app_color.dart
import 'package:flutter/material.dart';

/// Four layers, in order of authority:
///   1. Surface   — backgrounds and containers
///   2. Content   — text and icons ON a surface
///   3. Line      — borders and dividers
///   4. Semantic  — meaning-carrying accents
class AppColor {
  AppColor._();

  // ── 1. SURFACES ──────────────────────────────────────────────
  static const canvas   = Color(0xFFF4F6FB); // page background
  static const surface  = Color(0xFFFFFFFF); // card / sheet
  static const surfaceMuted = Color(0xFFF1F5F9); // inset well, segmented track
  static const surfaceNavy  = Color(0xFF0B132B); // dark hero / dark sheet

  // ── 2. CONTENT (contrast-verified against canvas) ────────────
  static const ink        = Color(0xFF090E1A); // 17.8:1 on canvas  ✓ AAA
  static const inkMuted   = Color(0xFF4B5565); //  7.0:1 on canvas  ✓ AAA
  static const inkSubtle  = Color(0xFF64748B); //  4.8:1 on canvas  ✓ AA
  static const onNavy     = Color(0xFFFFFFFF); // 18.4:1 on surfaceNavy ✓ AAA
  static const onNavyMuted= Color(0xFFBFDBFE);

  // ── 3. LINES ─────────────────────────────────────────────────
  /// Internal separators only. 1.14:1 on canvas — NOT a card edge.
  static const hairline = Color(0xFFE2E8F0);
  /// Any edge that must be *seen*: card outlines, input borders,
  /// secondary-button borders. 3.0:1 on canvas ✓ WCAG 1.4.11.
  static const line = Color(0xFF94A3B8);

  // ── 4. SEMANTIC (each has a light tint + a text-safe dark) ───
  // Brand
  static const brand      = Color(0xFF1E40AF); // 8.7:1 vs white ✓  primary CTA
  static const brandBright= Color(0xFF2563EB); // 4.8:1 on canvas ✓ active state
  static const brandTint  = Color(0xFFEFF6FF);

  // Positive — tax-ready, verified, savings
  static const positive      = Color(0xFF047857); // 5.4:1 vs white ✓  (was 059669 = 3.8:1 ✗)
  static const positiveStrong= Color(0xFF059669); // for text/dots, never white-on
  static const positiveTint  = Color(0xFFECFDF5);
  static const positiveInk   = Color(0xFF065F46); // 8.1:1 on positiveTint ✓

  // Attention — needs review, at risk
  static const attention      = Color(0xFFB45309); // 5.0:1 vs white ✓  (was D97706 = 3.2:1 ✗)
  static const attentionStrong= Color(0xFFD97706); // for text/icons only
  static const attentionTint  = Color(0xFFFEF3C7);
  static const attentionInk   = Color(0xFF78350F); // 9.6:1 on attentionTint ✓

  // Critical — duplicate, invalid, destructive
  static const critical     = Color(0xFFB91C1C); // 6.4:1 vs white ✓
  static const criticalTint = Color(0xFFFEF2F2);
  static const criticalInk  = Color(0xFF991B1B); // 7.6:1 on criticalTint ✓
}
```

### 2.3 กติกาการใช้สี

| สถานการณ์ | ใช้ |
|---|---|
| พื้นหน้า | `canvas` |
| การ์ด/ชีท | `surface` + ขอบ `line` + เงา `AppElevation.card` |
| ตัวเลข/หัวข้อ | `ink` |
| คำอธิบายรอง | `inkMuted` |
| meta เล็ก ๆ | `inkSubtle` |
| เส้นคั่นใน card | `hairline` |
| **ขอบ card / ขอบ input / ปุ่มรอง** | **`line`** ← อย่าใช้ `hairline` |
| ปุ่มหลัก | พื้น `brand` + ตัวอักษรขาว |
| ปุ่มรอง | พื้น `surface` + ขอบ `line` + ตัวอักษร `ink` |
| สำเร็จ / ประหยัด / พร้อม | `positive` (ปุ่ม) หรือ `positiveInk` (ข้อความบนพื้นอ่อน) |
| ต้องตรวจสอบ | `attention` / `attentionInk` |
| อันตราย / ลบ | `critical` / `criticalInk` |

### 2.4 กติกาสีที่ห้ามละเมิด

1. **ห้ามเขียน `Color(0xFF…)` ในไฟล์หน้าจอ** — ถ้าจำเป็นต้องมีสีใหม่ ให้เพิ่มที่ `AppColor` ก่อน
   (ปัจจุบันมี **276 จุด** กระจายอยู่ 68 สี โดย 51% ซ้ำกับ token ที่มีอยู่แล้ว)

2. **ห้ามใช้ขาวบนพื้น `attentionStrong` / `positiveStrong` / `brandBright`** สำหรับข้อความปกติ
   ```
   ขาวบน #D97706 = 3.19:1  ✗     ขาวบน #B45309 = 5.02:1  ✓
   ขาวบน #059669 = 3.77:1  ✗     ขาวบน #047857 = 5.40:1  ✓
   ```
   ถ้าต้องการพื้นส้ม/เขียวสด ให้ใช้พื้นอ่อน + ตัวอักษรเข้ม (`attentionTint` + `attentionInk`)

3. **สีต้องไม่ใช่ตัวบอกข้อมูลอย่างเดียว** ต้องมีข้อความหรือไอคอนกำกับเสมอ
   (ตัวอย่างที่ผิด: badge แจ้งเตือนที่ `home_header_bar.dart:261-275` เป็นสี่เหลี่ยมสีเหลือง 8×8 ไม่มีตัวเลข)

4. **หนึ่งความหมาย = หนึ่งสี** — ตอนนี้ "เตือน" มี 4 เฉด (`0xFFFFFBEB`, `0xFFFDE68A`, `amberLight`, `0xFFF59E0B`)
   ให้เหลือ `attentionTint` / `attention` / `attentionInk` เท่านั้น

### 2.5 Contrast — สรุปคู่ที่ต้องแก้

| ที่ | คู่ปัจจุบัน | อัตราส่วน | เปลี่ยนเป็น | ผลลัพธ์ |
|---|---|---|---|---|
| `money_left_on_table_card.dart:180` ปุ่ม "Recover $X" | ขาวบน `#D97706` | 3.19 ✗ | พื้น `#B45309` (`attention`) | **5.02 ✓** |
| `location_escalation_dialog.dart:138` ปุ่มหลัก | ขาวบน `#059669` | 3.77 ✗ | พื้น `#047857` (`positive`) | **5.40 ✓** |
| ขอบการ์ดทุกใบ | `#E2E8F0` บน `#F4F6FB` | 1.14 ✗ | `#94A3B8` (`line`) | **3.02 ✓** |
| ขอบปุ่มรอง | `#E2E8F0` | 1.14 ✗ | `#94A3B8` (`line`) | **3.02 ✓** |
| ข้อความบนพื้น `amberLight` | `#D97706` | 2.86 ✗ | `#78350F` (`attentionInk`) | **9.6 ✓** |
| ข้อความบนพื้น `emeraldLight` | `#059669` | 3.58 ✗ | `#065F46` (`positiveInk`) | **8.1 ✓** |

> **หมายเหตุที่ตรวจแล้วว่าถูกต้อง ไม่ต้องแก้:** ป้าย bottom nav ที่ไม่ถูกเลือกใช้ `AppColors.muted` (#4B5565)
> บนพื้นขาว = **7.3:1 ผ่านสบาย** (ผมเคยสงสัยว่าไม่ผ่าน — ตรวจซ้ำแล้วไม่จริง)

### 2.6 Dark mode — **ตัดออกจากขอบเขต**
ตัดสินใจเมื่อ 3 ต.ค. 2026: ยังไม่ทำ dark mode

แต่ต้องเก็บกวาดให้สะอาด เพราะตอนนี้มี "dark mode แอบแฝง" อยู่:
- ลบ token `darkSurface` / `darkBorder` / `textSecondaryDark` ออกจาก `AppColors` (และแก้ 9 จุดที่เรียกใช้)
- เปลี่ยน `location_escalation_dialog.dart:41` ที่พ่น `deepNavy` ทับทั้งหน้า ให้เป็นพื้นสว่าง
- ลบ token `telemetry*` ทั้ง 4 ตัวที่ซ้ำกับ `brandElectric`/`emerald` เป๊ะและไม่เคยถูกใช้

สถานะครึ่งทาง (มี token มืดแต่ไม่มี dark mode) แย่กว่าไม่มีเลย — ดู [แผนงาน §3.7](./03-completion-plan.md)

### 2.7 ThemeData — ซ่อมหรือลบ
`main.dart:59-65` สร้าง `ColorScheme.fromSeed(seedColor: deepNavy)` แต่ **ไม่มีใครอ่าน `Theme.of` เลย (1 ครั้งทั้งโปรเจกต์)**
ทำให้ Material widget ที่ไม่ได้ตั้ง `styleFrom` รับสี M3 ที่ไม่มีใครรีวิว (ตัวอย่างจริง: `tax_readiness_card.dart:102-123`)

```dart
// ทางที่แนะนำ — ระบุครบทุก role ที่แอปใช้จริง
colorScheme: const ColorScheme.light(
  primary: AppColor.brand,
  onPrimary: Colors.white,
  surface: AppColor.surface,
  onSurface: AppColor.ink,
  onSurfaceVariant: AppColor.inkMuted,
  outline: AppColor.line,
  outlineVariant: AppColor.hairline,
  error: AppColor.critical,
  onError: Colors.white,
),
textTheme: const TextTheme(
  displayLarge: AppType.metric,
  headlineMedium: AppType.title,
  titleMedium: AppType.section,
  bodyLarge: AppType.body,
  bodySmall: AppType.secondary,
  labelSmall: AppType.eyebrow,
),
```

---

## 3. Spacing · Radius · Elevation

### 3.1 Spacing — กริด 4pt
ตอนนี้มี `EdgeInsets` **123 แบบ** และค่า padding ในการ์ดบทบาทเดียวกันใช้ 4 ค่า (22/20, 20, 16, 14)
→ **ขอบข้อความในการ์ดที่เรียงต่อกันไม่ตรงกัน** ซึ่งตามองเห็นได้ทันที

```dart
// lib/core/theme/app_space.dart
class S {
  S._();
  static const xxs = 2.0;
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 20.0;   // ← ค่ามาตรฐาน padding ใน card
  static const xxl = 24.0;
  static const xxxl= 32.0;
  static const huge= 48.0;

  /// Standard horizontal page gutter. Every screen uses this.
  static const gutter = EdgeInsets.symmetric(horizontal: xl);

  /// Standard card interior. One value for one role.
  static const cardPad = EdgeInsets.all(xl);

  /// Standard vertical gap between stacked cards.
  static const cardGap = 16.0;

  /// Standard gap between a label and its value.
  static const labelGap = 4.0;
}
```

**กติกา:**
- ห้ามใช้ `SizedBox(height: 1.5)`, `5`, `3`, `18`, `22` — ใช้ค่าจาก `S` เท่านั้น (ปัจจุบัน 40% ของ spacer ไม่อยู่บนกริด)
- **padding ใน card = `S.cardPad` (20) เท่านั้น** — นี่คือสิ่งที่ทำให้ขอบข้อความตรงกันทั้งแอป
- ระยะห่างระหว่าง card = `S.cardGap` (16) เท่านั้น

### 3.2 Radius — 4 ค่า
ตอนนี้มี **19–20 ค่า** โดย 10/12/14/16/18/20 ใช้หนักพอกันหมด → ตาไม่จับ pattern

```dart
class R {
  R._();
  /// ป้าย (pill), chip, avatar — ใช้ `.circular(999)` สำหรับ pill เต็ม
  static const chip    = 8.0;
  /// ปุ่ม, input, ป้ายเล็ก
  static const control = 10.0;
  /// การ์ดทั่วไป — ค่ามาตรฐาน
  static const card    = 16.0;
  /// bottom sheet, hero card, dialog
  static const sheet   = 24.0;

  static BorderRadius get chipR    => BorderRadius.circular(chip);
  static BorderRadius get controlR => BorderRadius.circular(control);
  static BorderRadius get cardR    => BorderRadius.circular(card);
  static BorderRadius get sheetR   => BorderRadius.circular(sheet);

  /// Concentric inner radius: NEVER guess. inner = outer − padding.
  /// (pattern ที่ถูกต้องมีอยู่แล้วที่ tactile_primary_button.dart:87-89)
  static double inner(double outer, double padding) => outer - padding;
}
```

**กติกา concentric radius:** element ที่ซ้อนใน element อื่นต้องใช้ `R.inner(outer, padding)` เสมอ
ตัวอย่างที่ผิด: `legal_document_sheet.dart:113` track radius 10, `:164` chip radius 8 ทั้งที่ padding 3 → ที่ถูกคือ 7

### 3.3 Elevation — 3 ระดับ
ตอนนี้มี `boxShadow:` **49 จุด** และ `blurRadius` 14 ค่า (3,4,6,8,10,12,14,16,18,20,24,26,28,30)

```dart
class AppElevation {
  AppElevation._();

  /// การ์ดนอนบนพื้น — เกือบแบน ใช้ "ขอบ" เป็นตัวบอกขอบเขต ไม่ใช่เงา
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0B132B), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// องค์ประกอบลอย: nav bar, FAB, popover
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1F0B132B), blurRadius: 30, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 8,  offset: Offset(0, 2), spreadRadius: -1),
  ];

  /// องค์ประกอบที่ถูกยกขึ้นชั่วคราว: dialog, bottom sheet, drag
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x240B132B), blurRadius: 40, offset: Offset(0, 16), spreadRadius: -8),
  ];
}
```

**กติกา:** เงาทุกจุดในแอปต้องมาจาก 3 ตัวนี้
**จุดที่ต้องแก้ทันทีเพราะไม่สอดคล้อง:** `tax_shield_hero_card.dart` มี 2 สาขาที่การ์ด hero radius 24 vs 20, padding 22/20 vs 20, เงา navy vs `Colors.black`
→ ผู้ใช้กดสลับวิธีภาษีแล้ว **การ์ดหน้าแรกเปลี่ยนรูปร่าง** ต้องรวมเป็น shell เดียว

---

## 4. Motion

### 4.1 Tokens
ตอนนี้มี 16 durations และ 8 curves ไม่มี token เลย และ **press feedback มี 5 แบบที่ต่างกัน**

```dart
class AppMotion {
  AppMotion._();

  // Durations
  static const instant = Duration(milliseconds: 90);   // press-in, ripple
  static const press   = Duration(milliseconds: 100);  // press forward
  static const release = Duration(milliseconds: 220);  // press release
  static const state   = Duration(milliseconds: 160);  // toggle, chip select
  static const enter   = Duration(milliseconds: 400);  // screen/element entrance
  static const ambient = Duration(milliseconds: 1400); // sheen, pulse (background only)

  // Curves
  static const Curve pressIn = Curves.easeOutCubic;
  static const Curve settle  = Curves.easeOut;
  static const Curve toggle  = Curves.easeInOut;
  static const Curve enterC  = Curves.easeOutCubic;

  /// ONE press scale for every pressable control in the app.
  static const double pressScale = 0.972;
}
```

### 4.2 กติกา
1. **ทุกคอนโทรลที่กดได้ต้องมี press feedback** — ใช้ `AppMotion.pressScale` (0.972) เหมือนกันหมด
   ปัจจุบันมี 0.972 / 0.94 / 0.94 และ **2 คอนโทรลไม่มีเลย** (รวมปุ่ม "Stop" ที่ทำลายข้อมูล)
2. **ห้ามใช้ `Curves.elasticOut` / `easeOutBack` กับปุ่มหรือ CTA**
   การเด้งแบบยางยืดให้ความรู้สึกขี้เล่น ซึ่งขัดกับผลิตภัณฑ์ด้านภาษี/กฎหมาย
   อนุญาตเฉพาะ animation ของโลโก้ (`animated_brand_logo`, `oddy_interactive_logo`)
3. **ต้องรองรับ Reduce Motion**
   ```dart
   final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
   final d = reduceMotion ? Duration.zero : AppMotion.enter;
   ```
   ปัจจุบัน **ไม่มีที่ไหนเช็คเลย** ขณะที่มี animation วิ่งวนตลอดเวลา (`home_telemetry_capsule.dart:799-802`)
4. **ระยะเวลา `ambient` (1400ms) ใช้ได้เฉพาะกับเอฟเฟกต์พื้นหลัง** ห้ามใช้กับ feedback ของผู้ใช้
5. **Haptic ต้องสม่ำเสมอ** — แนะนำ 3 ระดับเท่านั้น:
   - `selectionClick` — เลือกแท็บ, เลือก chip, toggle
   - `lightImpact` — ปุ่มรอง, เปิด sheet
   - `mediumImpact` — บันทึกสำเร็จ, ยืนยัน
   (ปัจจุบันใช้ `heavyImpact` กับปุ่ม capture กลางขณะที่แท็บข้าง ๆ ใช้ `selectionClick` — ห่างกัน 3 ระดับบนคอนโทรลที่อยู่ติดกัน)

### 4.3 บั๊ก motion ที่ต้องแก้
`oddy_interactive_logo.dart:144-151` สร้าง `CurvedAnimation` + `addListener` ใหม่ **ทุกครั้งที่ผู้ใช้ลาก/แตะ** และไม่เคยลบ
→ หลัง N ครั้ง มี N listener เรียก `setState` ทุก tick (แฟนเอาต์ quadratic) + จับค่า `startX`/`startY` เก่าค้าง

**แก้:** สร้าง `CurvedAnimation` ครั้งเดียวใน `initState` หรือเปลี่ยนไปใช้ `ValueNotifier<Offset>` ป้อน `AnimatedBuilder` ที่มีอยู่แล้ว (`:158`)
(วิธีหลังดีกว่า เพราะเลิก `setState` ทุก `onPanUpdate` ที่ `:95,:119`)

---

## 5. Component Specs

ตอนนี้ไม่มี primitive เลย → `ElevatedButton` 66 จุด, `TextButton` 51 จุด, `InkWell` 30 จุด,
การ์ดเขียนมือ 49 จุด, และ segmented control ถูก implement 4 รอบด้วยกัน

### 5.1 `AppButton` — 3 variants, 2 ขนาด

| Variant | พื้น | ขอบ | ตัวอักษร | ใช้เมื่อ |
|---|---|---|---|---|
| `primary` | `brand` | — | ขาว + `w600` | การกระทำหลักของจอ — **มีได้จอละ 1** |
| `secondary` | `surface` | `line` (1px) | `ink` | การกระทำรอง |
| `text` | โปร่งใส | — | `brandBright` | ลิงก์, "ดูทั้งหมด" |

**สเปก:**
```
ความสูง     : 52 (ขนาด md), 44 (ขนาด sm)
ระยะห่าง    : S.lg (16) แนวนอน
Radius      : R.control (10)
ตัวอักษร    : AppType.bodyStrong (15/w600)
Press       : scale → AppMotion.pressScale, AppMotion.press / AppMotion.release
Loading     : ต้องมี prop `isLoading` — ปุ่มต้อง disable ตัวเองและแสดง spinner แทน label
เป้าแตะ     : ต้อง ≥ 48dp เสมอ (ถ้าสูง 44 ให้เพิ่ม hit area ด้วย padding)
Semantics   : ต้องมี label และ role button
```

**ต้องใช้ `isLoading` ทุกที่ที่มี `await`** — ปัจจุบัน `TactilePrimaryButton` รองรับแล้ว (`:17,28,67,84,180`)
แต่ถูกส่งค่าแค่ 2 จุด ขณะที่ปุ่มบันทึกทริปหลัก (`cpk_trip_entry_screen.dart:683`) ไม่ส่ง
→ แตะรัว ๆ สร้างทริปซ้ำได้

### 5.2 `AppCard` — 1 รูปร่าง

```
พื้น        : surface
ขอบ        : line, 1px          ← ต้องมองเห็นได้ (3:1) ห้ามใช้ hairline
Radius      : R.card (16)
Padding     : S.cardPad (20)    ← ค่าเดียวสำหรับทุกการ์ด
เงา         : AppElevation.card
ระยะห่างจาก card ข้างเคียง : S.cardGap (16)
```

**ห้ามซ้อน card ใน card** — ตอนนี้ `money_left_on_table_card` มีการ์ดซ้อนการ์ด (แบนเนอร์ "Switching to Logbook" อยู่ในการ์ด "Money left on the table")
ถ้าต้องแยกส่วน ให้ใช้ **เส้นคั่น `hairline`** หรือ **พื้น `surfaceMuted`** แทนการซ้อนการ์ด

### 5.3 `AppPill` — 1 รูปร่าง
ตอนนี้มี 6 radius × 6 padding สำหรับบทบาทเดียว (แย่สุด: radius 20 กับ radius 6 อยู่ในการ์ดเดียวกัน)

```
ความสูง    : 22
ระยะห่าง   : symmetric(horizontal: 8, vertical: 3)
Radius     : 999 (pill เต็ม) หรือ R.chip (8)
ตัวอักษร   : AppType.eyebrow
สี         : ใช้คู่ tint + ink ของ semantic (เช่น positiveTint + positiveInk)
```

### 5.4 `AppAlert` — 1 ใบต่อจอ

**นี่คือ component ที่สำคัญที่สุดที่ต้องสร้าง** เพราะ Home ในปัจจุบันมี 3 บล็อกเตือนเรียงกัน ดัน hero ตกจอ

```
โครงสร้าง (บังคับ):
  [ไอคอน] [หัวข้อสั้น ≤ 6 คำ]           [ป้ายตัวเลข]
  [คำอธิบาย ≤ 2 บรรทัด — ไม่มีศัพท์กฎหมาย]
  [CTA เดียว]

ข้อจำกัด:
  - ในการจอ มี AppAlert สูงสุด 1 ใบ
  - ห้ามมี CTA 2 อันในใบเดียว (ปัจจุบันมีการ์ดที่มีทั้ง "Recover" และ "Switch")
  - ห้ามซ้อน card ใน alert
  - คำอธิบายต้องเป็นภาษาคน ไม่ใช่ "Under ATO TR 97/11, undocumented trips
    will be disqualified in an audit."
    → ใช้ "1 ทริปยังไม่มีเหตุผลทางธุรกิจ — เพิ่มเหตุผลเพื่อรักษาสิทธิหักลดหย่อน"
```

### 5.5 `AppListRow` — แถวรายการ

```
ความสูงขั้นต่ำ : 64
โครงสร้าง      : [ไอคอน/avatar 40] [ชื่อ 17/w600][บรรทัดรอง 13/w500] [ค่า/chevron]
เส้นคั่น       : hairline, เยื้องซ้าย 56 (ให้ตรงกับจุดเริ่มข้อความ)
Press          : ทั้งแถวกดได้ (InkWell เต็มแถว) — ห้ามมีแถวที่ "ดูเหมือนกดได้แต่กดไม่ได้"
```

> **ข้อห้ามที่ต้องบังคับใช้:** `trip_review_sheet.dart:136-239` มี **20 การ์ดที่หน้าตาเหมือนกดได้ แต่กดไม่ได้เลย**
> นี่คือความผิดพลาดที่ทำลายความเชื่อใจผู้ใช้มากที่สุดในลิสต์

### 5.6 `AppSheet` — bottom sheet

```
Radius  : R.sheet (24) เฉพาะมุมบน
Padding : S.xl (20)
Drag handle: แสดง, กว้าง 36 สูง 4, R 999, สี line
ปุ่มปิด : ต้องมีทุกครั้ง
ความสูง : ปรับตามเนื้อหา (ไม่ยืดเต็มจอโดยไม่มีเหตุผล)
```

### 5.7 `AppEmptyState` — ต้องมี CTA ทุกครั้ง

```
[ไอคอน 40, inkSubtle]
[หัวข้อ 17/w600]        ← ประโยคบอกสถานะ ไม่ใช่คำถาม
[คำอธิบาย 15/body, inkMuted, ≤ 2 บรรทัด]
[ปุ่ม primary — การกระทำถัดไปที่ถูกต้อง]
```

**ต้องแยก 2 กรณีให้ชัด:**
- ไม่มีข้อมูลเลย → "ยังไม่มีทริปที่บันทึกไว้" + ปุ่ม "บันทึกทริปแรก"
- มีข้อมูลแต่ไม่ตรงตัวกรอง → "ไม่พบทริปในหมวดนี้" + ปุ่ม "ล้างตัวกรอง"

> ปัจจุบัน `evidence_expenses_screen.dart:211` แสดง "No expenses recorded yet" (แปลว่าไม่มีข้อมูลเลย)
> เมื่อผู้ใช้แค่เลือกตัวกรองแล้วไม่เจอ — เป็นข้อความที่ **โกหกผู้ใช้**

### 5.8 `AppSkeleton` — shimmer ที่มีรูปทรงตรงกับเนื้อหา
แทนการที่หน้าจอวาด empty state ทันทีขณะโหลด (`appState.isInitialized` มีอยู่แล้วแต่ไม่มีใครอ่าน)
Skeleton ต้องมี **รูปทรงเดียวกับเนื้อหาจริง** ไม่ใช่ spinner กลางจอ

---

## 6. State Matrix — ทุกจอต้องมี

| สถานะ | ต้องแสดง | ห้าม |
|---|---|---|
| **Loading** (ครั้งแรก) | Skeleton ที่มีรูปทรงตรงกับเนื้อหา | spinner กลางจอ / วาด empty state |
| **Empty** (ไม่มีข้อมูลจริง) | Empty state + CTA | ตัวเลข 0 ทุกช่องโดยไม่มีคำอธิบาย |
| **Partial** (มีข้อมูลบางส่วน) | ข้อมูลที่ได้ + แถบเตือนว่ายังโหลดไม่ครบ | แสดงเสมือนโหลดเสร็จ |
| **Error** | ข้อความเข้าใจได้ + ปุ่ม "ลองอีกครั้ง" + ไม่มีศัพท์เทคนิค | กลืน error เงียบ / `Text('Camera unavailable: $e')` |
| **Offline** | แบนเนอร์ "บันทึกไว้ในเครื่อง จะซิงก์เมื่อออนไลน์" | เงียบ (ปัจจุบันเงียบทุกที่) |
| **Permission denied** | อธิบายว่าทำไมต้องใช้ + ปุ่มไปตั้งค่า | ปิด sheet เงียบ ๆ |
| **Success** | Snackbar / dialog บน **context ที่ยังอยู่** | เรียก `ScaffoldMessenger` บน context ที่ pop ไปแล้ว |

**ประตูโหลดเริ่มต้น:** ใช้ `appState.isInitialized` เป็น gate ระดับแอป
ถ้ายังโหลดไม่เสร็จ **ห้าม**วาด empty state — เพราะตอนนี้ "โหลดช้า" กับ "ไม่มีข้อมูล" หน้าตาเหมือนกันเป๊ะ

---

## 7. Frontier Checklist — สิ่งที่แยก "ดี" ออกจาก "frontier"

ใช้เป็นรายการตรวจก่อน merge ทุกครั้ง

### Typography
- [ ] ไม่มี `fontSize:` เขียนสดในไฟล์หน้าจอ (ใช้ `AppType` เท่านั้น)
- [ ] ไม่มีขนาดครึ่งพิกเซล
- [ ] ข้อความทุกย่อหน้ามี `height` จาก token
- [ ] ตัวเลขที่อัปเดตสดใช้ `fontFeatures: tabular`
- [ ] ป้ายที่ยาวได้มี `maxLines` + `overflow: ellipsis` (โดยเฉพาะใน nav)

### Color
- [ ] ไม่มี `Color(0xFF…)` เขียนสดในหน้าจอ
- [ ] ขอบที่ต้องมองเห็นใช้ `line` ไม่ใช่ `hairline`
- [ ] ข้อความบนพื้นสีผ่าน 4.5:1 (ตรวจจริง ไม่ใช่เดา)
- [ ] ไม่มีข้อมูลที่สื่อด้วย "สี" อย่างเดียว
- [ ] หนึ่งความหมาย = หนึ่งสี

### Layout
- [ ] ค่า spacing มาจาก `S` เท่านั้น (ไม่มี 1.5, 3, 5, 18, 22)
- [ ] padding ใน card = `S.cardPad` เหมือนกันทุกการ์ด
- [ ] radius มาจาก `R` เท่านั้น (4 ค่า)
- [ ] element ที่ซ้อนกันใช้ concentric radius
- [ ] เงามาจาก `AppElevation` (3 ระดับ)
- [ ] padding ล่างของ scroll view คำนวณจากความสูง nav bar จริง **ไม่ใช่เลข 120 ฮาร์ดโค้ด**

### Motion
- [ ] duration/curve มาจาก `AppMotion`
- [ ] ทุกคอนโทรลที่กดได้มี press feedback
- [ ] ไม่มี `elasticOut`/`easeOutBack` บนปุ่ม
- [ ] รองรับ reduce motion
- [ ] haptic มี 3 ระดับสม่ำเสมอ

### Accessibility
- [ ] เป้าแตะ ≥ 48×48dp (ไม่นับ slop ที่เขียนในคอมเมนต์แต่ไม่มีจริง)
- [ ] ทุกคอนโทรลมี `Semantics` label + role
- [ ] เลย์เอาต์ไม่พังที่ text scale **200%** (ทดสอบจริงด้วยฮาร์เนส)
- [ ] ลำดับโฟกัสถูกต้อง และมี focus state
- [ ] ไอคอนที่สื่อความหมายมี `semanticLabel`

### States
- [ ] จอนี้มี loading / empty / error ครบ
- [ ] ถ้ามีการกรอง: empty state แยก "ไม่มีข้อมูล" กับ "ไม่ตรงตัวกรอง"
- [ ] ทุก `await` มี loading state และ disable ปุ่มระหว่างทำ
- [ ] `await` ที่อาจ throw มี `try/catch` + ข้อความ error ที่เข้าใจได้
- [ ] success message แสดงบน context ที่ยังอยู่

### Trust (สำคัญที่สุดสำหรับผลิตภัณฑ์นี้)
- [ ] ไม่มีข้อมูลตัวอย่าง/ค่า fallback จาก mockup รั่วเข้าไปในบันทึกจริง
- [ ] ไม่มีการอ้างว่าตรวจสอบแล้ว (`verified`, `locked`, `encrypted`, `synced`) โดยไม่มีข้อมูลรองรับ
- [ ] ไม่มีตัวเลขที่คำนวณจากข้อมูลผิดชุด (เช่น hero ที่ไม่สนใจตัวกรอง)
- [ ] ไวยากรณ์ถูกต้อง รวม pluralization (`1 drive` ไม่ใช่ `1 drives`)
- [ ] ไม่มีศัพท์เทคนิค/เลขมาตรากฎหมายในข้อความ UI ปกติ

---

## 8. วิธีลงมือ — ลำดับที่ไม่ทำให้แอปพัง

การเปลี่ยน design system ทั้งแอปพร้อมกันจะพัง 219 เทสต์ที่มีอยู่ ทำตามลำดับนี้:

### ขั้น 0 — เตรียมความปลอดภัย (0.5 วัน)
1. รัน `flutter test test/` ให้ผ่าน 219/219 (ยืนยันแล้วว่าผ่าน)
2. เพิ่ม golden test จากฮาร์เนส `tool/design_audit/ui_capture_test.dart` เป็น **visual regression gate**
   → ทุกครั้งที่แก้ UI จะเห็นทันทีว่าจอไหนเปลี่ยน

### ขั้น 1 — วางราก (1 วัน) — **เพิ่ม ไม่ลบ**
สร้างไฟล์ใหม่ 4 ไฟล์ โดย **ไม่แตะโค้ดเดิม**:
- `lib/core/theme/app_color.dart`
- `lib/core/theme/app_typography.dart`
- `lib/core/theme/app_space.dart` (รวม `R` และ `AppElevation`)
- `lib/core/theme/app_motion.dart`

แอปยังทำงานเหมือนเดิมทุกอย่าง — ยังไม่มีความเสี่ยง

### ขั้น 2 — แก้ ThemeData (0.5 วัน)
- `main.dart:59-65` → `ColorScheme.light` ที่ระบุครบ + `textTheme` จาก `AppType`
- บันเดิล Inter (หรือลบ `fontFamily` แล้วลด `w800`/`w900`)
- **รันเทสต์ + เทียบภาพ** → ตรวจว่าไม่มีจอไหนพัง

### ขั้น 3 — แก้บั๊ก P0 ทั้ง 15 ข้อ (1–2 วัน)
ทำตามตารางใน [`01-ui-ux-audit.md`](./01-ui-ux-audit.md) §9 P0
งานเหล่านี้ **ไม่ต้องรอ design system** และให้ผลกระทบต่อผู้ใช้สูงสุด
แต่ละข้อมีเกณฑ์ยอมรับชัดเจนและทดสอบได้

### ขั้น 4 — สร้าง primitive 5 ตัว (2 วัน)
`AppButton`, `AppCard`, `AppPill`, `AppAlert`, `AppEmptyState` (+ `AppListRow`, `AppSheet`)
พร้อม golden test ของแต่ละตัว

### ขั้น 5 — ทยอยเปลี่ยนหน้าจอ (3–5 วัน)
เรียงตามผลกระทบ:
1. `cpk_home_body.dart` / `logbook_home_body.dart` (จอที่ผู้ใช้เห็นบ่อยสุด)
2. `tax_summary_screen.dart` (จอที่ hierarchy กลับด้านมากสุด)
3. `trips_ledger_tab.dart`, `evidence_expenses_screen.dart`, `trip_detail_screen.dart`
4. ที่เหลือ

**กติกาต่อหน้าจอ:** เปลี่ยนเสร็จ → รันเทสต์ → เทียบภาพ → commit แยกทีละจอ
**ห้าม**แก้หลายจอพร้อมกันใน commit เดียว

### ขั้น 6 — เก็บกวาด (1 วัน)
- ลบ dead code 1,745 บรรทัด (หรือต่อ `logbook_progress_screen` เข้าแอปจริง)
- ลบ token ที่ไม่ใช้ (`telemetry*` 4 ตัว และ `dark*` ทั้ง 3 ตัว เนื่องจากไม่ทำ dark mode)
- ลบ `AppTextStyles` เดิมหลังย้ายครบแล้ว
- เพิ่ม lint rule ห้าม `Color(0x` และ `fontSize:` ใน `lib/ui/screens/**`

### ขั้น 7 — ยกระดับ (1–2 สัปดาห์)
- ~~Dark mode~~ — **ตัดออกจากขอบเขต** (ดู [แผนงาน](./03-completion-plan.md) §3.7 สำหรับการเก็บกวาด token)
- ยกเครื่องลำดับชั้น Home ให้ hero อยู่บนสุดเสมอ
- Splash screen (mockup หน้าจอ 1 ยังไม่มี)
- Skeleton loading แทน empty state ทันที
- `intl` + `NumberFormat.currency(locale: 'en_AU')`
- Merchant field + date field ในการบันทึกเร็ว
- ปุ่มลบ/undo (soft delete มี field อยู่แล้วแต่ UI ไม่มี)

---

## 9. สรุปหนึ่งหน้า — ถ้าจำได้แค่ 10 ข้อ

1. **บันเดิล Inter** (หรือเลิกอ้าง) — ตอนนี้ตัวอักษรไม่เหมือนกันข้ามแพลตฟอร์ม
2. **tabular figures** ให้ตัวเลขทุกตัว — ปัจจุบันสั่นขณะขับรถ
3. **9 ขนาดตัวอักษร** แทน 27 — และเลิกใช้ครึ่งพิกเซล
4. **ห้ามเขียน `Color(0xFF…)`** ในหน้าจอ — มี 276 จุด / 68 สี
5. **ขอบการ์ดต้องมองเห็นได้** — `#E2E8F0` บนพื้นอ่อน = 1.14:1 มองไม่เห็น
6. **4 spacing / 4 radius / 3 elevation** — ปัจจุบัน 123 / 19 / 49
7. **ทุกจอมี loading / empty / error** — และแยก "ไม่มีข้อมูล" จาก "ไม่ตรงตัวกรอง"
8. **ทุก `await` ต้องมี spinner + disable ปุ่ม + `try/catch`**
9. **ทุกคอนโทรลต้องมี `Semantics` + เป้าแตะ 48dp + รอดถึง text scale 200%**
10. **ห้ามแสดงข้อมูลที่แต่งขึ้น** — "28 min", "GPS point logged", "encrypted & synchronized"
    ล้วนเป็นคำกล่าวอ้างที่ทำลายคุณค่าหลักของผลิตภัณฑ์

> ข้อ 10 สำคัญที่สุด ถ้าทำได้แค่ข้อเดียว **ให้ทำข้อนี้**
> เพราะ KiloClaim ขาย "ความมั่นใจว่าจะผ่านการตรวจสอบ" — ถ้าแอปโกหกเรื่องหลักฐาน ผู้ใช้ก็ไม่เหลืออะไรที่จะเชื่อ
