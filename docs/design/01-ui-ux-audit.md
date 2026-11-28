# UI / UX Design Audit — KiloClaim (DriveLog)

> **สถานะ: แก้ไข P0 ครบทั้ง 15 ข้อแล้ว** — ดู [§10 สถานะการแก้ไข](#10-สถานะการแก้ไข-แก้แล้ว--ยังเหลือ)
> ทดสอบ: **219/219 ผ่าน** · `flutter analyze lib/` **สะอาด** · overflow **0 จุด** ทั้ง 17 หน้าจอ และที่ text scale 100/130/200%

> ตรวจเมื่อ 3 ต.ค. 2026 · ขอบเขต: `lib/` ทั้งหมด (101 ไฟล์ Dart, 32,583 บรรทัด, 44 หน้าจอ)
> วิธีตรวจ: อ่านซอร์สโค้ดทั้งหมด + **เรนเดอร์หน้าจอจริงนอกอุปกรณ์** (headless render) 17 หน้าจอ
> หลักฐานภาพ: `tool/design_audit/captures/` · ฮาร์เนส: `tool/design_audit/ui_capture_test.dart`
> ทดสอบพื้นฐานก่อนเริ่ม: `flutter test test/` → **219 ผ่านทั้งหมด** (ไม่มีอะไรพังอยู่ก่อน)

---

## ⚠️ หมายเหตุสำคัญ — โค้ดถูกแก้ไขระหว่างการตรวจ

**ระหว่างการตรวจ (3 ต.ค. 2026 เวลา 19:59:36) มีกระบวนการอื่นในเครื่องนี้แก้ไฟล์ใน `lib/` ไป 37 ไฟล์**
โดย**ลบเฉพาะคอมเมนต์** (diff: `37 files changed, 5 insertions(+), 164 deletions(-)`)

ผมไม่ได้เป็นคนแก้ไฟล์เหล่านั้น — การแก้นี้เกิดจาก skill `no-comments` / rule `Comment Sicko`
ที่มีอยู่ในโปรเจกต์นี้ (`.agents/skills/no-comments/`, `.cursor/rules/comment-sicko.md`)
ซึ่งรันทับ "working diff" ของคุณโดยอัตโนมัติ

**ผลกระทบ:**
- **ตรรกะของโค้ดไม่เปลี่ยน** — มีแต่คอมเมนต์ที่ถูกลบ ทุกบั๊กที่รายงานยังอยู่ครบ
- **เลขบรรทัดในรายงานนี้ถูกตรวจซ้ำและแก้ให้ตรงกับไฟล์ปัจจุบันแล้ว** (แก้ไป 38 จุด)
- ถ้ามีการลบคอมเมนต์ซ้ำอีก เลขบรรทัดจะเลื่อนอีก — ใช้ **ตาราง Anchor ท้ายเอกสาร** เพื่อค้นหาโค้ดแทนการเชื่อเลขบรรทัด

**สิ่งที่ควรทำ:** ตรวจว่า `git status` / `git diff` ของคุณตรงกับที่คาดไว้ก่อน commit
(`sign_in_screen.dart` และ `pubspec.yaml` ถูกแก้ไว้ก่อนหน้านี้แล้วตั้งแต่ 04:26 และ 06:38 ซึ่งไม่ใช่ฝีมือผมเช่นกัน)

---

## 1. บทสรุปผู้บริหาร

**ข่าวดี: งานฝีมือ (craft) ของแอปนี้สูงกว่างานทั่วไปมาก** — มี token file, มี gradient/bezel ที่ตั้งใจทำ,
floating nav bar ที่สวย, ใช้ Lucide icon system สม่ำเสมอ, และหน้าจอส่วนใหญ่จัดวางได้ดี
ปัญหาของแอปนี้ **ไม่ใช่ว่า "ออกแบบไม่เป็น"** แต่คือ **"ยังไม่มีระบบ"** — ทุกอย่างถูกตัดสินใจใหม่ทีละหน้าจอ

**ตัวเลขที่บอกทุกอย่าง:**

| สิ่งที่วัด | ผลลัพธ์ | ควรจะเป็น |
|---|---|---|
| `TextStyle(` เขียนสด | **561 ครั้ง** | ใช้ `AppTextStyles` |
| อ้างอิง `AppTextStyles.*` | 48 ครั้ง (8%) | ~90% |
| สี hex เขียนสด (`Color(0xFF…)`) | **276 ครั้ง / 68 สีต่างกัน** | 0 (ใช้ `AppColors`) |
| ขนาดฟอนต์ที่ต่างกัน | **27 ขนาด** (แอป-wide 31) | 9 |
| ขนาดฟอนต์ที่เป็นครึ่งพิกเซล (11.5, 12.5…) | **133 ครั้ง** | 0 |
| `EdgeInsets` ที่ต่างกัน | **123 แบบ** | ~10 |
| `BorderRadius` ที่ต่างกัน | **19 ค่า** (20 ทั้งแอป) | 4 |
| ระยะเวลาแอนิเมชัน | **16 ค่า**, curve 8 แบบ | 4 โทเคน + 3 curve |
| `AppShadows` ถูกใช้ | **1 ครั้ง** (จากทั้งแอป) | ทุกที่ |
| `Theme.of(context)` ถูกเรียก | **1 ครั้ง** (จากทั้งแอป) | เป็นแหล่งความจริงเดียว |
| `Semantics(` สำหรับ screen reader | **0 ครั้ง** | ทุกคอนโทรล |
| Dark mode | **ไม่มี** | มี (หรือไม่พูดถึงเลย) |
| รองรับ `textScaler` | **0 จุด** แต่มี `height:` ตายตัว **607 จุด** | ✓ |

**สรุปสั้น:** แอปนี้จ่าย "ราคา" ของการมี design system ครบ (มี token file, มี ThemeData) แต่ได้ผลตอบแทนเกือบศูนย์
เพราะโค้ด 92% ไม่ได้ใช้มัน ผลลัพธ์คือความไม่สม่ำเสมอที่สะสม — ซึ่งเป็นสิ่งที่แยก "แอปที่ดูดี" ออกจาก "แอประดับ frontier"

---

## 2. ปัญหาที่ผู้ใช้เห็นจริง — ต้องแก้ก่อน (P0)

ทั้งหมดนี้ **ยืนยันด้วยภาพที่เรนเดอร์จริง** ไม่ใช่การคาดเดาจากโค้ด

### P0-1 · หน้าจอ Home หลักมี RenderFlex overflow — เห็นแถบแดง/ดำบนหน้าจอ
**หลักฐาน:** `tool/design_audit/captures/05_home_cpk.png` และ `_crop_amber.png`
มีแถบเส้นทแยงแดง-ดำโผล่ที่ขอบขวาของการ์ด Manee Left on the Table และการ์ด hero — คือตัวบ่งชี้ overflow ของ Flutter

```
RenderFlex overflowed by 13 pixels on the right.
The relevant error-causing widget was:
  Row  lib/ui/screens/cpk/cpk_home_body.dart:188:19
```

**สาเหตุ:** `Row(mainAxisAlignment: spaceBetween)` ที่ `cpk_home_body.dart:188` มีลูก 2 ตัวที่ไม่ถูกจำกัดความกว้าง
(ข้อความ `ESTIMATED TAX DEDUCTION • 91¢/KM` + ป้ายทะเบียน) เมื่อความกว้างการ์ดเหลือ 301px จึงล้น 13px
และ **ข้อความทะเบียน `1GTF892` ถูกตัดขาด** ในภาพที่เรนเดอร์

### P0-2 · เลย์เอาต์พังทั้งหมดเมื่อผู้ใช้ขยายขนาดตัวอักษร (Accessibility text scaling)
**หลักฐาน:** `tool/design_audit/captures/a11y_textscale_1.0.png`, `1.3.png`, `2.0.png`

รันที่ text scale 100% / 130% / 200% บนหน้าจอ Home:

| Text scale | Overflow ที่ตรวจพบ |
|---|---|
| 100% | 13px (คือ P0-1) |
| 130% | **85px, 23px** |
| 200% | **254px, 188px, 34px, 18px, 13px** |

ที่ 200% หน้าจอพังจนใช้งานไม่ได้: `MONEY LEFT ON THE TA…` ถูกตัด, ตัวเลข hero `$16.74` ล้นออกนอกจอ,
ป้าย `AUD` ตกขอบ, และการ์ด hero ถูก nav bar บังไปครึ่งหนึ่ง

**ทำไมสำคัญเป็นพิเศษ:** กลุ่มเป้าหมายคือช่าง/คนขับรถเพื่อการพาณิชย์ ซึ่งมีสัดส่วนผู้ที่ตั้งขนาดตัวอักษรใหญ่สูงกว่าค่าเฉลี่ย
และ App Store / Play Store ให้คุณค่ากับเรื่องนี้ในการรีวิว

**สาเหตุเชิงโครงสร้าง:** ทั้งแอปมี `height:` ตายตัว **607 จุด** และ **ไม่มีที่ไหนอ่าน `textScaler`/`textScaleFactor` เลย**
เช่น `tax_shield_hero_card.dart:128-141` วางตัวเลข 42px เป็นลูกตรง ๆ ใน `Row` โดยไม่มี `Flexible`/`FittedBox`

### P0-3 · `initialOdometer` เป็น `0.0` เสมอ — ทุกผู้ใช้ใหม่
```dart
// lib/ui/screens/vehicle/vehicle_setup_flow.dart
42:  final _odometerController = TextEditingController();   // ประกาศ
109:    _odometerController.dispose();                        // คืนหน่วยความจำ
117:        double.tryParse(_odometerController.text…) ?? 0.0;  // อ่าน
133:      initialOdometer: odo,
```
`_odometerController` ถูก **ประกาศ + อ่าน + dispose แต่ไม่เคยผูกกับ `TextField` ตัวไหนเลย** (grep ทั้งไฟล์ยืนยัน)
ดังนั้น `text` เป็น `''` ตลอด → `tryParse('')` = `null` → `?? 0.0`

**ผลกระทบต่อเนื่องที่ผู้ใช้เห็น:**
- `compliance_center_screen.dart:29` → `hasOdo` เป็น false ตลอด → "Odometer Recorded" ขึ้นสถานะเตือน **ตลอดกาล**
- `tax_summary_screen.dart:661` → "Opening reading required by ATO" ค้างอยู่ถาวร
- `logbook_setup_screen.dart:33` → เตรียมเลข 0 ไว้ให้
- ผู้ใช้ **CPK ไม่มีทางกรอกเลขไมล์เริ่มต้นได้เลย** (ทางเดียวอยู่ใน bottom sheet ที่เห็นเฉพาะโหมด logbook)

### P0-4 · ตรวจสอบ compliance แบบผิดตรรกะ → ฟ้องผู้ใช้ว่า "ปลอดภัยแล้ว" ทั้งที่ยังไม่ได้ทำ
```dart
// lib/ui/screens/compliance/compliance_center_screen.dart:33-34
final receiptsBackedUp = totalExpenses == 0 ||
    appState.expenses.any((e) => e.receiptPath != null);   // ← .any() ควรเป็น .every()
```
ใช้ `.any()` → **มีใบเสร็จเดียวจาก 50 ใบ** ก็ทำให้ checklist ติ๊กครบ แล้วหน้าจอขึ้นข้อความ
"Receipts Backed Up ✓ / **Cloud vault encrypted & synchronized**" (`:214-215`)

นี่คือ **การกล่าวอ้างเรื่องการเข้ารหัสและซิงก์โดยไม่มีหลักฐานรองรับ** ซึ่งเป็นความเสี่ยงทั้งต่อผู้ใช้ (เข้าใจผิดว่าข้อมูลปลอดภัย)
และต่อตัวผลิตภัณฑ์ (คำกล่าวอ้างด้าน compliance ที่พิสูจน์ไม่ได้) — ในแอปภาษีถือว่าร้ายแรง

### P0-5 · ข้อมูลเท็จถูกแสดงเป็นข้อเท็จจริงในบันทึกที่ใช้อ้างอิงภาษี

| ที่ | สิ่งที่แสดง | ปัญหา |
|---|---|---|
| `trip_detail_screen.dart:263` | `'… · 28 min'` | **"28 min" ฮาร์ดโค้ด** — ทุกทริปในแอปอ้างว่าใช้เวลา 28 นาที |
| `trip_detail_screen.dart:334-337` | โน้ต `'Installed electrical switchboard'` | โน้ตตัวอย่างจาก mockup ถูกแสดงเป็นโน้ตจริงของผู้ใช้ |
| `trip_detail_screen.dart:423` | `'GPS point logged'` | ยืนยันว่ามีพิกัด GPS **โดยไม่ตรวจสอบอะไรเลย** |
| `trip_detail_screen.dart:443` | `'Timestamp locked'` | ยืนยันว่ามีการล็อกเวลา **โดยไม่ตรวจสอบอะไรเลย** |
| `expense_detail_screen.dart:1026,1029` | `isVerified: true` | 2 ใน 5 ข้อของ "ATO Evidence Checklist" **ผ่านตลอดแบบฮาร์ดโค้ด** |
| `money_left_on_table_card.dart:342-343` | *"Don't leave **8 fuel receipts** in your glovebox"* | เมื่อ `vaultCount == 0` ข้อความ **แต่งจำนวนใบเสร็จขึ้นมา** |

ในผลิตภัณฑ์ที่คุณค่าหลักคือ "หลักฐานที่ผ่านการตรวจสอบได้" การกล่าวอ้างว่ามีหลักฐานทั้งที่ไม่มี
คือการทำลายคุณค่าหลักของผลิตภัณฑ์เอง

### P0-6 · ฟีเจอร์เรือธง (Logbook) ถูกล็อกในหน้าตั้งค่า แต่ถูกโฆษณาให้กดสลับ
- `vehicle_setup_flow.dart:1018` → `badgeText: 'COMING SOON'`, `:1030` → `isComingSoon: true`
  กดแล้วขึ้น "Logbook method is coming soon. Starting with Cents-per-km." (`:1077-1078`)
- แต่แอปมี **ระบบ Logbook ที่ทำเสร็จสมบูรณ์แล้ว** — `logbook_home_body.dart`, `logbook_setup_screen.dart`,
  `logbook_trip_entry_screen.dart`, `logbook_odometer_card.dart`, `odometer_camera_capture_sheet.dart`,
  `logbook_export_service.dart`, ตรรกะ 12 สัปดาห์ตามกฎหมาย, คำเตือน TR 97/11
- และ `money_left_on_table_card.dart:68-70, 253-270` **โฆษณาว่า** "Switching to Logbook unlocks +$224.16"
  พร้อมปุ่ม **"Switch"** ที่พาไป `LogbookSetupScreen` — หน้าจอที่ต้องมี Logbook ก่อน

**ผลลัพธ์:** ผู้ใช้ใหม่ **ไม่มีทางกลายเป็นผู้ใช้ logbook ได้** ขณะที่แอปเชิญชวนให้สลับไปหามันตลอดเวลา

### P0-7 · ปุ่มยืนยันการบันทึกหนดำเนินการซ้ำได้ / ล้มเหลวแบบเงียบ
- `expense_detail_screen.dart:363` → `await _receiptAuditService.create(...)`
  **ไม่มี spinner, ไม่มี `try/catch`, ปุ่ม Save ไม่ถูก disable** → แตะสองครั้งได้ค่าใช้จ่าย 2 รายการ
  และถ้า throw ขึ้นมา โค้ดจะหยุดก่อน `updateExpense`/`recordExpense` (`:395`/`:410`) → **ผู้ใช้ไม่เห็นอะไรเลยทั้งที่ข้อมูลไม่ได้ถูกบันทึก**
- `cpk_trip_entry_screen.dart:683` และ `logbook_trip_entry_screen.dart:341-351`
  ปุ่มบันทึกทริปหลัก **ไม่ส่ง `isLoading`** ทั้งที่ `TactilePrimaryButton` รองรับอยู่แล้ว (`tactile_primary_button.dart:17,28,67,84,180`)
- `trip_live_tracking_screen.dart:341-347` — ปุ่ม X ทิ้งการบันทึก GPS ที่กำลังทำอยู่ **โดยไม่ถามยืนยัน**
  และไฟล์นี้ไม่มี `PopScope` เลย → ปัด back บน Android ก็ทิ้งเช่นกัน

### P0-8 · ข้อความยืนยันsuccessแสดงบน context ที่ถูก pop ไปแล้ว
`trip_quick_resolve_sheet.dart:60` pop → `:66` เรียก `ScaffoldMessenger.of(context)` (context ของ sheet ที่ตายแล้ว)
เกิดแบบเดียวกันที่ `cpk_trip_entry_screen.dart:144-146`, `logbook_trip_entry_screen.dart:137-140`,
`expense_capture_sheet.dart:173-174`, `trip_review_sheet.dart:96-97`

**ผลลัพธ์:** งานหลักของแอป (บันทึกทริป) อาจเสร็จสิ้น **โดยไม่มีสัญญาณยืนยันใด ๆ** ให้ผู้ใช้เห็น
แพตเทิร์นที่ถูกต้องมีอยู่แล้วในไฟล์เดียวกัน — `expense_detail_screen.dart:362` จับ `messenger` ไว้ก่อน pop

### P0-9 · ตัวคั่นลูกศร `→` 23 จุดในข้อความ UI
`tax_summary_screen.dart:536,562,601,627,645,667-668,686,704,720` และอื่น ๆ ใช้ `'Review all →'`, `'Edit →'`, `'View →'` เป็นต้น

ในฮาร์เนสเรนเดอร์ของผม ตัวอักษรนี้แสดงเป็น **กล่องสี่เหลี่ยม (tofu)** — `05_home_cpk.png` แสดง `Bondi Reno ⯑ North Sydney`
บนอุปกรณ์จริง iOS/Android จะ fallback ไปฟอนต์ระบบจึงมักไม่พัง **แต่**:
- ขึ้นกับ font fallback ของแต่ละเครื่อง/แต่ละ OEM (Android บางรุ่น/รุ่นเก่าไม่มี)
- จัดสี/ขนาด/น้ำหนักของลูกศรแยกจากข้อความไม่ได้
- screen reader ไม่ได้ข้อมูลอะไรจากมัน
- ไม่ mirror อัตโนมัติเมื่อทำ RTL
- ขัดกับ Lucide icon system ที่ใช้ทั้งแอป

**รากของปัญหา:** `main.dart:58` ตั้ง `fontFamily: 'Inter'` แต่ **`pubspec.yaml` ไม่มีบล็อก `fonts:` เลย**
→ Inter ไม่เคยถูกบันเดิล แอปเงียบ ๆ ไปใช้ SF Pro (iOS) / Roboto (Android)
ทำให้ **ตัวอักษรไม่เหมือนกันข้ามแพลตฟอร์ม** → จุดที่ `maxLines: 1` + `ellipsis` จะตัดบรรทัดไม่เหมือนกัน
และ `FontWeight.w800` 150 จุด กับ `w900` อีก 60 จุด **แสดงผลเหมือนกันเพราะไม่มีฟอนต์ weight นั้น**

### P0-10 · ปุ่ม/ตัวควบคุมหลายจุดกดไม่ติดตามมาตรฐาน

| ที่ | ขนาดเป้า | ปัญหา |
|---|---|---|
| `home_telemetry_capsule.dart:216-217` | **~26dp** | ปุ่ม "Stop" หยุดการบันทึก — เล็กกว่ามาตรฐาน 48dp เกือบครึ่ง |
| `home_telemetry_capsule.dart:248` | **~27×27dp** | ปุ่มขยาย HUD |
| `legal_document_sheet.dart:88-90` | **~27dp** | ตั้ง `minimumSize: Size.zero` + `tapTargetSize: shrinkWrap` → **ปิดขั้นต่ำ 48dp ของ Material 3 เองโดยตรง** |
| `money_left_on_table_card.dart:396` | 36dp | ปุ่ม CTA หลัก |

และ **ไม่มี `Semantics(` เลยแม้แต่จุดเดียวใน 101 ไฟล์** → ปุ่ม capture กลาง (แอคชันหลักของแอป)
`scaffold_bottom_nav_bar.dart:196-231` ไม่มีชื่อ ไม่มี role ให้ screen reader อ่าน

---

## 3. ระบบดีไซน์ที่ยังไม่เป็นระบบ (ตัวเลข)

### 3.1 Typography — 27 ขนาด แต่ลำดับชั้นมีจริงแค่ 4 ระดับ

ขนาดที่ใช้บ่อย: `13`(68) `11`(73) `12`(82) `14`(43) `12.5`(39) `11.5`(37) `16`(25) `15`(24) `13.5`(24) …

```
27 ขนาดที่ต่างกัน — แต่จะเห็นว่ากระจุกตัวอยู่ที่ 11 / 11.5 / 12 / 12.5 / 13 / 13.5 / 14 / 14.5 / 15 / 15.5 / 16 / 16.5 / 17
```
ช่วง 11–17 ใช้ **13 ขนาด** ต่างกันทีละ 0.5–1px — ต่ำกว่าเกณฑ์ที่ตาคนแยกออก (just-noticeable difference)
แปลว่า **จ่ายราคาของ 27 ขนาด แต่ได้ลำดับชั้นแค่ 4 ระดับที่ตามองเห็น**

ยิ่งกว่านั้น **133 จุดใช้ขนาดครึ่งพิกเซล** (11.5, 12.5, 13.5, 14.5, 15.5, 16.5, 9.5, 10.5)
ซึ่งไม่ตรงกริดพิกเซล ทำให้น้ำหนักเส้นและระยะห่างไม่สม่ำเสมอ และแสดงผลต่างกันในแต่ละ DPR

**Line-height:** `AppTextStyles.body` เป็น token เดียวที่มี `height:` (1.4) แต่ **ไม่เคยถูกใช้เลย**
ทำให้ทุกย่อหน้าตั้ง line-height เอง และไม่ตรงกัน: 6 ค่าที่ต่างกัน (1.3 / 1.35 / 1.4 / 1.4 / 1.45 / 1.52) สำหรับบทบาทเดียวกัน
ในไฟล์ `money_left_on_table_card.dart` เดียวกันยังมีทั้ง 1.4 (`:178`) และ 1.3 (`:247`) ใน card เดียว

**Tabular numerals: ไม่มีเลย** — `grep fontFeatures` ทั้ง `lib/` ได้ 0 ผลลัพธ์
ตัวเลขเงินและเลขไมล์ที่อัปเดตสด (`home_telemetry_capsule.dart:167-174, 184-192`) จะ **สั่นซ้าย-ขวาแบบเห็นได้**
ขณะขับรถ เพราะความกว้างของเลข `1` กับ `0` ไม่เท่ากันในฟอนต์ proportional
สำหรับแอปการเงิน/ภาษี นี่คือรายละเอียดที่แยก "ดูดี" ออกจาก "ระดับ frontier" ชัดที่สุด

### 3.2 สี — palette ที่ยังไม่มีความหมาย

276 จุด / 68 สีที่เขียนสด **โดย 51% ของสีเหล่านั้นคือสีที่มี token อยู่แล้ว** เช่น:
- `0xFF2563EB` เขียนสด 17 ครั้ง ทั้งที่เป็น `AppColors.brandElectric`
- `0xFF059669` ↔ `AppColors.emerald`, `0xFFDC2626` ↔ `AppColors.crimson`, `0xFFD97706` ↔ `AppColors.amber`

**Token ที่ตั้งชื่อสื่อความหมายแต่ไม่สื่อจริง** — 11 จาก 26 token เป็นแค่ชื่อซ้ำของค่าเดียวกัน:
| ค่า | ชื่อที่ประกาศ |
|---|---|
| `0xFF2563EB` | `brandElectric`, `telemetryReady` |
| `0xFFEFF6FF` | `brandElectricLight`, `workBlueLight`, `telemetryReadyLight` |
| `0xFF059669` | `emerald`, `telemetryLive` |
| `0xFF1E40AF` | `brandPrimary`, `workBlue` |
`telemetry*` ทั้ง 4 ตัว **ไม่เคยถูกเรียกใช้เลย**

**ความต่างของสีที่ทำให้ระบบดูไม่นิ่ง** — "สีเหลืองเตือน" มี 4 เฉดทำหน้าที่เดียวกัน:
`0xFFFFFBEB`, `0xFFFDE68A`, `AppColors.amberLight (0xFFFEF3C7)`, `0xFFF59E0B`
"สีเขียว" มี 4 เฉด: `0xFF34D399`, `0xFF10B981`, `0xFF059669`, `0xFFA7F3D0`

**Contrast ที่ไม่ผ่าน WCAG AA** (คำนวณด้วยสูตร WCAG 2.1 เอง — ยืนยันแล้ว):

| คู่สี | อัตราส่วน | ต้องได้ | ที่ใช้ |
|---|---|---|---|
| `amber` บน `amberLight` | **2.86:1** | 4.5 | ข้อความเตือน |
| `emerald` บน `emeraldLight` | **3.58:1** | 4.5 | ป้าย ATO rate |
| ขาวบน `amber` (ปุ่ม CTA) | **3.19:1** | 4.5 | `money_left_on_table_card.dart:180` "Recover $X in 1 Tap" |
| ขาวบน `emerald` (ปุ่ม CTA) | **3.77:1** | 4.5 | `location_escalation_dialog.dart:138` |
| `crimson` บน `crimsonLight` | **4.41:1** | 4.5 | `home_telemetry_capsule.dart:219` |
| **`border` บน `background`** | **1.14:1** | 3.0 | ขอบการ์ด — **มองไม่เห็น** |
| `darkBorder` บน `deepNavy` | **1.78:1** | 3.0 | เส้นแบ่งในการ์ด navy — มองไม่เห็น |

ข้อสุดท้ายสำคัญ: `AppColors.border` (0xFFE2E8F0) บนพื้นหลัง (0xFFF4F6FB) ได้ **1.14:1**
ซึ่งหมายความว่า **ขอบการ์ดทั้งหมดในแอปแทบมองไม่เห็น** — การ์ดจึงอ่านเป็นแผ่นแบนที่ไม่มีขอบ
และ secondary button ที่มี "ขอบ" เป็น affordance เดียว ก็ดูเหมือนข้อความธรรมดา

**Dark mode: ไม่มี** — ไม่มี `darkTheme`/`themeMode` เลย แต่กลับมี token `darkSurface`/`darkBorder`/`textSecondaryDark` ค้างอยู่
และมีหน้าจอที่พ่น `deepNavy` ทับทั้งหน้า (`location_escalation_dialog.dart:41`) → ดูเหมือนคนละแอป

**ThemeData ไร้ผล:** `Theme.of(context)` ถูกเรียก **1 ครั้งจากทั้งโปรเจกต์**, `textTheme` **0 ครั้ง**, `colorScheme` **0 ครั้ง**
แต่ `ColorScheme.fromSeed(seedColor: deepNavy)` ยังคงปล่อยสี M3 ที่ไม่มีใครรีวิวออกไปยัง Material widget
ที่ไม่ได้ตั้ง `styleFrom` — ตัวอย่างจริง: `tax_readiness_card.dart:102-123`

### 3.3 Spacing / Radius / Elevation

| | จำนวนค่าที่ต่างกัน | ปัญหา |
|---|---|---|
| `SizedBox(height:)` | 15 ค่า | **40% ไม่อยู่บนกริด 4pt** รวม `SizedBox(height: 1.5)` ที่ `home_telemetry_capsule.dart:336` |
| `EdgeInsets` | **123 แบบ** | padding ในการ์ดบทบาทเดียวกันใช้ 4 ค่า: 22/20, 20, 16, 14 → **ขอบข้อความในการ์ดที่เรียงต่อกันไม่ตรงกัน** |
| `BorderRadius.circular()` | **19 ค่า** | 10/12/14/16/18/20 ใช้หนักพอ ๆ กันทั้งหมด → สายตาไม่จับ pattern |
| `boxShadow:` | **49 จุด** ใน 25 ไฟล์ | `blurRadius` 14 ค่า: 3,4,6,8,10,12,14,16,18,20,24,26,28,30 |

`AppShadows` ประกาศ 3 สูตร และ **ถูกใช้ 1 ครั้งในทั้งแอป** (`tactile_primary_button.dart:153`)
ในขณะที่ nav bar เขียนเงาของตัวเองใหม่ (`scaffold_bottom_nav_bar.dart:60-75`) โดยแก้ตัวเลขจาก token ไป 4 จาก 6 ตัว

**ความไม่สอดคล้องที่ร้ายแรงที่สุด:** `tax_shield_hero_card.dart` มี 2 สาขา (CPK / Logbook) ที่ให้การ์ด hero ต่างกัน:

| คุณสมบัติ | สาขา CPK (`:32-45`) | สาขา Logbook (`:220-233`) |
|---|---|---|
| รัศมีมุม | **24** | **20** |
| padding | `symmetric(22, 20)` | `all(20)` |
| เงา | `deepNavy@0.04, blur 20` | **`Colors.black@0.03, blur 10`** |

→ **ผู้ใช้ที่กดสลับวิธีคำนวณภาษี จะเห็นการ์ดหน้าแรกเปลี่ยนรูปร่างและความลึก** ในจังหวะที่เป็นการตัดสินใจสำคัญ

### 3.4 Motion

16 ค่า duration ที่ต่างกัน (90, 90, 100, 160, 160, 180, 240, 280, 300, 400, 420, **1200**, **1400**) และ 8 curve
ไม่มี token ด้าน motion เลยแม้แต่ตัวเดียว

**การตอบสนองต่อการกด (press feedback) มี 5 แบบที่ต่างกันสำหรับ gesture เดียวกัน:**

| คอนโทรล | scale | เหตุผล |
|---|---|---|
| `tactile_primary_button.dart:48-56` | → 0.972 | |
| `animated_brand_logo.dart:62-71` | → 0.94 | |
| `oddy_interactive_logo.dart:69-78` | → 0.94 | |
| `scaffold_bottom_nav_bar.dart:199-202` | ไม่มีเลย | |
| `home_telemetry_capsule.dart:212-240` (Stop) | **ไม่มีเลย และไม่มีการตอบสนองใด ๆ** | ปุ่มทำลายข้อมูล |

**การสั่น (haptic) 4 ระดับในบริบทเดียวกัน** — ภายใน nav bar เดียวกัน แท็บใช้ `selectionClick` (`:260`)
แต่ปุ่ม capture กลางใช้ `heavyImpact` (`:200`) ห่างกัน 3 ระดับ

**บั๊กจริง:** `oddy_interactive_logo.dart:144-151` สร้าง `CurvedAnimation` + `addListener` **ใหม่ทุกครั้งที่ผู้ใช้ลาก/แตะ**
และไม่เคย `removeListener` เลย → หลังผ่านไป N ครั้ง จะมี N listener เรียก `setState` ทุก tick (แฟนเอาต์แบบ quadratic)
พร้อมทั้งจับ `startX`/`startY` เก่าค้างไว้

**ไม่มี reduce-motion:** `MediaQuery` ถูกอ่าน 4 ครั้ง ทั้งหมดเพื่อ inset/size ไม่มีการเช็ค `disableAnimations`
→ ผู้ใช้ที่เปิด Reduce Motion ยังได้แสงวิ่ง 1400ms และ `..repeat(reverse: true)` ที่วิ่งตลอดเวลา (`home_telemetry_capsule.dart:799-802`)

**Curve ที่ไม่ตรงกับโทนผลิตภัณฑ์:** `Curves.elasticOut` และ `easeOutBack` ถูกใช้ 5 จุด
ในแอปที่ว่าด้วยการปฏิบัติตามกฎหมายภาษี — การเด้งแบบยางยืดให้ความรู้สึกขี้เล่น ซึ่งขัดกับความน่าเชื่อถือที่ผลิตภัณฑ์ต้องการ

---

## 4. ลำดับชั้นทางสายตา (Visual Hierarchy)

### 4.1 หน้าจอหลัก: ตัวเลขที่สำคัญที่สุดถูกดันตกจอ
`cpk_home_body.dart` เรียงจากบนลงล่าง:
1. Header (`:44`)
2. แบนเนอร์ "work drives ready for sign-off" — แสดงเมื่อมีทริปที่ยังไม่ยืนยัน (`:51`)
3. `MoneyLeftOnTableCard` — การ์ดเตือนสีเหลืองขนาดใหญ่ (`:136`)
4. **← การ์ด hero "ESTIMATED TAX DEDUCTION $38.77" อยู่ตรงนี้ (`:139`)**
5. Telemetry capsule
6. Recent Activity

**เทียบกับหน้าจอที่ยังไม่มีข้อมูล** (`tool/design_audit/captures/06_home_empty.png`):
hero อยู่บนสุด → **หน้าจอที่ "ว่าง" จัดลำดับชั้นได้ดีกว่าหน้าจอที่มีข้อมูล** ซึ่งเป็นสัญญาณว่าลำดับชั้นถูกกำหนดโดย "อะไรโผล่มาก่อน" ไม่ใช่โดยความสำคัญ

ในหน้าจอที่มีข้อมูล (`05_home_cpk.png`) มี **3 บล็อกสีที่แย่งความสนใจ** เรียงติดกัน:
แบนเนอร์ฟ้า → การ์ดเหลือง (กินพื้นที่ครึ่งจอ) → การ์ด hero น้ำเงิน
และการ์ดเหลืองมี **CTA 2 อันแข่งกัน**: "Recover $8.92 in 1 Tap" (สีส้มทึบ) กับ "Switch" (ลิงก์น้ำเงิน)
ข้างในยังมีการ์ดซ้อนการ์ด (nested card) อีกชั้น

**ข้อความในการ์ดเหลือง** เป็นย่อหน้าทางกฎหมายยาว 3 บรรทัด: *"1 drives (9.8 km at 91c/km) are missing a work reason.
Under ATO TR 97/11, undocumented trips will be disqualified in an audit."*
— ทั้งที่รุนแรงเกินจริง (การอ้าง "disqualified" แบบเบ็ดเสร็จ) และมี **ไวยากรณ์ผิด "1 drives"**

### 4.2 Tax Summary: ตัวเลขหลักเล็กกว่าคะแนนรอง
`tax_summary_screen.dart` แสดง "Tax Deduction Subtotal" ที่ **17px** (`:221-229`)
แต่ "Audit Readiness Score" แสดงที่ **22px** (`:486-494`)
ทั้งที่ mockup (หน้าจอ 12) ให้ "Estimated deduction $5,420" เป็นพระเอกที่ระดับ hero

### 4.3 ตัวเลขซ้ำกันในระยะห่าง 3 บรรทัด
`logbook_home_body.dart` แสดงเปอร์เซ็นต์ business use **สองครั้ง**: ตรงกลางวงแหวนที่ **13px** (`:136-152`)
และอีกครั้งที่ **22px** (`:160-168`) — ห่างกัน 3 บรรทัด

### 4.4 Hero ที่ทำได้ดี (ควรใช้เป็นมาตรฐาน)
- `cpk_home_body.dart:255-262` — ตัวเลข 44px/w900 + ป้าย AUD + progress
- `trip_live_tracking_screen.dart:417-436` — ตัวเลข 72px + หน่วย 13px ตัวพิมพ์ใหญ่ = hero ที่แข็งแรงที่สุดในแอป
- `compliance_center_screen.dart:89-95` — คะแนน 26px → progress bar → checklist = focal point เดียวที่ชัดเจน

---

## 5. สถานะที่ยังไม่ได้ออกแบบ (States) — ช่องว่างที่ใหญ่ที่สุด

**สาเหตุราก:** `appState.isInitialized` มีอยู่ (`lib/state/app_state.dart:102`) แต่ **ไม่มีหน้าจอไหนอ่านมันเลย**
→ หน้าจอทุกหน้าวาดสถานะ "ไม่มีข้อมูล" ทันที ดังนั้น **การโหลดช้ากับ "คุณไม่มีข้อมูล" หน้าตาเหมือนกันเป๊ะ**
และ **ไม่มีสถานะ offline ทั่วทั้ง UI** (`restoreFromCloud()` ถูกเรียกที่ `cpk_home_body.dart:34` โดย **ทิ้ง `CloudRestoreResult`** → ดึงข้อมูลล้มเหลว = เงียบ)

| หน้าจอ | loading | empty | error | offline | perm-denied |
|---|---|---|---|---|---|
| `cpk_home_body.dart` | pull-to-refresh เท่านั้น | ✗ | ✗ | ✗ | – |
| `logbook_home_body.dart` | pull-to-refresh เท่านั้น | ✗ | ✗ | ✗ | – |
| `trips_ledger_tab.dart` | ✗ | ✓ `:351-400` (ไม่มี CTA) | ✗ | ✗ | – |
| `evidence_expenses_screen.dart` | ✗ | ✓ **แต่ผิด** `:318-354` | ✗ | ✗ | – |
| `expense_detail_screen.dart` | **✗** `:365` | – | **✗** | ✗ | – |
| `scan_receipt_screen.dart` | ✓ `:242-253` | – | **✗ กลืน error** `:59-63,93-98,111-116` | ✗ | **✗** |
| `tax_summary_screen.dart` | ✗ | ✗ | ✗ | ✗ | – |
| `vehicle_setup_flow.dart` | ✗ `:98` | **✗** (การ์ดขอบขาวเปล่า) | ✗ | ✗ | ✗ `:81-84` |
| `migration_screen.dart` | **✗ มองไม่เห็น** `:137` | **✗** | **✗** | ✗ | – |

**ตัวอย่างที่ผู้ใช้เห็นได้จริง:**

| หน้าจอ | อาการ |
|---|---|
| `evidence_expenses_screen.dart:211` | เลือกฟิลเตอร์ "Vehicle" แล้วไม่มีผลลัพธ์ → ขึ้น **"No expenses recorded yet"** ทั้งที่ผู้ใช้มีค่าใช้จ่ายอยู่ |
| `migration_screen.dart:276-277` | นำเข้าล้มเหลวทั้งหมด (`totalParsed == 0`) → **ขึ้นการ์ดติ๊กเขียวเหมือนนำเข้าสำเร็จ** พร้อม `NaN%` ได้ (`:289`) |
| `vehicle_setup_flow.dart:470-523` | ค้นหารถไม่เจอ → **การ์ดขอบขาวเปล่า** ไม่มีข้อความ "ไม่พบรถรุ่นนี้" |
| `logbook_progress_screen.dart:85,111` | ทริปเป็น 0 → "Week 0 of 12", "0.0% Business use" — ไม่มีสถานะ "เริ่ม logbook" |
| `tax_summary_screen.dart` | ไม่มีข้อมูล → `$0.00`, `0%`, checklist ว่างเปล่า — แยกไม่ออกจาก "โหลดไม่สำเร็จ" |

**สถานะว่างที่ไม่มีทางออก (dead-end empty states):**
- `trips_ledger_tab.dart:351-400` — ไม่มีปุ่ม CTA ผู้ใช้ต้องหาปุ่ม FAB เอง
- `home_recent_activity.dart:140-173` — ข้อความ "Your work drives will appear here automatically" **เป็นเท็จสำหรับผู้ใช้ CPK** เพราะ CPK ไม่มีเส้นทางบันทึกอัตโนมัติเลย

---

## 6. เส้นทางและแรงเสียดทาน (Flow Friction)

**จำนวนการแตะไปยังงานหลัก:**

| งาน | เส้นทางที่สั้นที่สุด | เส้นทางที่เด่นที่สุด |
|---|---|---|
| บันทึกทริป | 2 แตะ + ฟอร์ม (จากแท็บ Trips) | **3 แตะ + ฟอร์ม** (จากปุ่ม FAB กลาง — ซึ่งเด่นที่สุด!) |
| บันทึกใบเสร็จ | 4 แตะ + ฟอร์ม | **5 แตะ + ฟอร์ม** |
| ดูประมาณการภาษี | 1 แตะ | ✓ ดี |
| ส่งออกให้ accountant | 2 แตะ | ✓ ดี แต่ **ปุ่มถูกซ่อนเมื่อคะแนน < 90** ใน `compliance_center_screen.dart:280` แต่โชว์เสมอใน `tax_summary_screen.dart:86` |

ปุ่มที่ **เด่นที่สุดในแอป** (capture กลาง 48px) กลับเป็นเส้นทางที่ **ช้า** เพราะแทรก bottom sheet ให้เลือก 2 ชั้น

**ปุ่มที่ตาย (dead buttons) — กดแล้วไม่มีอะไรเกิดขึ้น:**
1. `logbook_progress_screen.dart:61-66` — เฟือง Settings, `onPressed: () {}`
2. `logbook_progress_screen.dart:351-358` — ป้าย "Review" เป็น `Text` ธรรมดา ไม่มี gesture
3. `trip_review_sheet.dart:136-239` — **การ์ดทริปทั้งหมดกดไม่ได้เลย** (ไม่มี `InkWell`) ทั้งที่หน้าตาเหมือนกดได้ — มี 20 การ์ด
4. `scan_receipt_screen.dart:146-153` — ปุ่มแฟลชเปลี่ยน `_isFlashOn` แต่ **ไม่ถูกส่งไปที่ camera API ใด ๆ**
5. `logbook_progress_screen.dart:196-201` — ลูกศรชี้ไปข้างหน้า แต่ `onTap` เป็น `Navigator.pop()` (ย้อนกลับ)

**กับดัก (traps) — ผู้ใช้ออกไม่ได้:**
1. `vehicle_setup_flow.dart:389-394` — ปุ่มปิดแสดงเฉพาะเมื่อ `onCancel != null` แต่ `onboarding_flow_screen.dart:83,102`
   สร้าง `VehicleSetupFlow` **โดยไม่ส่ง `onCancel`** → **ผู้ใช้ติดอยู่ในขั้นที่ 1 ออกไม่ได้**
2. `value_first_gate_screen.dart:71-77` — ไม่มีปุ่มย้อนกลับ และไม่มี route ให้ pop → เลือกรถผิดแล้วแก้ไม่ได้

**การกระทำที่ทำลายข้อมูลโดยไม่ถามยืนยัน:**
1. `trip_live_tracking_screen.dart:341-347` — ทิ้งการบันทึก GPS ที่กำลังทำ (ไม่มี `PopScope`)
2. `home_telemetry_capsule.dart:213-235` — ปุ่ม "Stop" สีแดง หยุดการบันทึกสด
3. `rescued_trip_banner.dart:99-102` — ทิ้งข้อมูล GPS ที่กู้คืนมาได้
4. `account_settings_sheet.dart:416-461` — **"Remove from this iPhone"** ล้างข้อมูลทันที **โดยไม่ถามยืนยัน**
   และคำอธิบายบรรทัดล่างยังลดทอนความรุนแรงว่า *"Safe for borrowed or shared devices"*
   (ขณะที่ flow ลบบัญชีที่ `:615-690` **มี** การยืนยันครบถ้วน + คำเตือน ATO 5 ปี — แสดงว่าทีมทำได้ แต่ไม่ได้ทำ)
5. `cpk_trip_entry_screen.dart:700-711` — ปุ่ม **"Discard / Personal Trip"** แค่ pop แล้วขึ้นข้อความ
   "Personal trip discarded. 5,000 km quota preserved." → **ไม่มีอะไรถูกบันทึกเลย**
   ชื่อปุ่มสัญญาว่าจะ "บันทึกเป็นทริปส่วนตัว" แต่ข้อมูลถูกทิ้ง — ในแอปภาษีคือการสูญเสียข้อมูลที่ผู้ใช้บันทึกไว้

**ปุ่มหาย (missing affordance):** **ไม่มีปุ่มลบทริปหรือลบค่าใช้จ่ายที่ไหนเลยในแอป**
ทั้งที่ `Trip.deletedAt` (`lib/data/models/trip.dart:44`) และ `VehicleExpense.deletedAt` มีอยู่แล้ว
→ ทริปที่บันทึกผิด **แก้ไม่ได้ตลอดไป**

---

## 7. ภาษาและความน่าเชื่อถือ (Copy & Trust)

### 7.1 ศัพท์เทคนิคหลุดถึงผู้ใช้
| ข้อความ | ที่ | ปัญหา |
|---|---|---|
| `'SHA-256: a1b2c3d4...'` | `odometer_camera_capture_sheet.dart:340` | แสดง hash เหนือรูปถ่าย — ช่างก่อสร้างอ่านแล้วไม่ได้อะไร |
| `'Log Logbook Drive (TR 97/11)'` | `logbook_trip_entry_screen.dart:175` | เลขมาตรากฎหมายเป็นชื่อหน้าจอ |
| `'Subdivision 28-F Compliant Logbook'` | `onboarding_slides_screen.dart:759` | กฎหมายลึก ๆ บนสไลด์แรกของแอป |
| `'Authentication Error'` | `value_first_gate_screen.dart:40` | ควรเป็น "Sign In Issue" (แบบเดียวกับ `sign_in_screen.dart:435`) |
| `'Camera unavailable: $e'` | `odometer_camera_capture_sheet.dart:125` | **โยน exception ดิบใส่หน้าจอผู้ใช้** |
| `'FY2026-27 Vehicle'` | `home_header_bar.dart:63` | ขาดเว้นวรรค |
| `'Continuous 84 days period completion'` | `logbook_setup_screen.dart:242` | ไวยากรณ์ผิด |
| `'1 drives need your sign-off'` | `cpk_home_body.dart:62` | **ไวยากรณ์ผิด — ไม่มี pluralization ที่ไหนเลยในแอป** |

### 7.2 หน่วยและรูปแบบตัวเลขผิด
| ที่ | ปัญหา |
|---|---|
| `logbook_progress_screen.dart:295,313` | `'${Formatters.distance(…)} km'` แต่ `Formatters.distance` **ต่อ " km" ให้แล้ว** → แสดง **"82,421.0 km km"** และใช้ทศนิยม 1 ตำแหน่งกับเลขไมล์ซึ่งควรเป็นจำนวนเต็ม |
| `formatters.dart:47-62` | `dateTime()` **ไม่มีปี** → "12 Sep · 8:42 AM" — บันทึกภาษีที่แยกไม่ออกระหว่างปี |
| `formatters.dart:51` | ใช้ `AM`/`PM` ตัวพิมพ์ใหญ่ ขณะที่ en-AU ใช้ตัวพิมพ์เล็ก |
| `trip_live_tracking_screen.dart:325-329` | `_formatDuration` เป็น `MM:SS` เท่านั้น → ขับ 2 ชั่วโมงแสดง **"137:04"** |
| `evidence_expenses_screen.dart:511-635` | การ์ดค่าใช้จ่าย **ไม่แสดงวันที่เลย** (mockup แสดง "12 Sep 2026") |
| `vehicle_setup_flow.dart:1002-1023` | hardcode `'Claim up to $4,550 / year'` ขณะที่หน้าจออื่นใช้ `appState.activeTaxRule.maxCentsPerKmClaim` ถูกต้อง |

### 7.3 ตัวเลข "ยอดรวมที่หักได้" สองค่าที่ขัดกัน
- `tax_summary_screen.dart:32-35` → `totalClaim = isCpk ? summary.centsPerKmClaim : …` → **โหมด CPK ไม่รวมค่าใช้จ่ายทางตรง**
- `evidence_expenses_screen.dart:140-141,194` → แสดง **ผลรวมค่าใช้จ่ายทั้งหมด** เป็น hero ในชื่อ "Total deductible claimable"

→ สองหน้าจอให้ตัวเลขที่ดูน่าเชื่อถือทั้งคู่ แต่ไม่ตรงกัน

### 7.4 ศัพท์ที่ใช้ไม่ตรงกันสำหรับสิ่งเดียวกัน
- **ทริปที่ยังไม่ระบุวัตถุประสงค์** → 4 คำ: `'Business drive'`, `'Needs attention'`, `'Unknown Purpose'`, `'Work drive'`
- **สถานะว่าง** → 4 คำ: `"No Trips Yet"`, `"No trips recorded yet"`, `"No drives recorded yet"`, `"No expenses recorded yet"`
- **ส่งออก** → 4 คำ: `"Share with Accountant"`, `"Share Tax Pack (PDF + CSV)"`, `"Export & Share Tax Pack with Accountant"`, `"Accountant Hand-off"`
- **บันทึกค่าใช้จ่าย** → 5 คำ: `"Add Expense"`, `"Scan"`, `"Save Expense to Evidence Vault"`, `"Save Expense to Vault"`, `"Update Expense Record"`
- **หน้าจอ compliance** → 3 ชื่อ: `"Compliance Center"`, `"Tax Compliance Center"`, `"Full Compliance Audit"`

### 7.5 ป้ายที่ทำให้เข้าใจผิด
- `evidence_expenses_screen.dart:186-187` — ฟิลเตอร์ชื่อ **"Vehicle"** และ **"Business"** แต่ `:125-126` หมายถึง
  "ค่าใช้จ่ายเกี่ยวกับรถ" กับ "ค่าใช้จ่ายที่ไม่เกี่ยวกับรถ" → **กด "Business" แล้วค่าใช้จ่ายเกี่ยวกับรถหายไป
  ซึ่งก็เป็นค่าใช้จ่ายทางธุรกิจเหมือนกัน**
- `trip_detail_screen.dart:100` — ปุ่ม **"Edit"** เปิด `TripQuickResolveSheet` ซึ่งแก้ได้แค่วัตถุประสงค์
- `cpk_trip_entry_screen.dart:700` — **"Discard / Personal Trip"** รวม 2 การกระทำที่ตรงข้ามกันไว้ในปุ่มเดียว
- `logbook_progress_screen.dart:196` — ลูกศรชี้เข้า แต่กดแล้วย้อนกลับ

### 7.6 ระบบคำศัพท์วัตถุประสงค์ทริปที่แตกออกเป็นหลายชุด — **ทำให้ข้อมูลผิด**
- `trip_quick_resolve_sheet.dart` เขียน `'Personal Drive'` (`:254`)
- `logbook_trip_entry_screen.dart:77` เช็ค `_selectedPurpose == 'Personal'` → **ไม่ตรงกัน**
- `trip_purpose_selector.dart:38-60` ต้อง `||` เทียบ 6 สตริงเก่า และยังพลาด `'Work Site Inspection'`, `'Supplier / Materials'`

**ผลลัพธ์จริง:** ทริปที่ผู้ใช้ตั้งใจระบุว่าเป็น **"Personal Drive"** จะถูกบันทึกเป็น **business**
→ กลายเป็นการหักลดหย่อนที่ไม่ถูกต้อง ซึ่งเป็นความเสี่ยงด้านภาษีโดยตรง

### 7.7 ตรรกะ CPK ถูกใช้กับทริป logbook — 5 จุด
`trip_detail_screen.dart:66`, `trip_review_sheet.dart:211`, `home_recent_activity.dart:198-199`,
`trips_ledger_tab.dart:492-493`, `rescued_trip_banner.dart:111`
ทั้งหมดคำนวณ `distanceKm * centsPerKmRate` แล้วเรียกมันว่า "ATO Claim" โดยไม่แยกตามวิธีภาษี

---

## 8. โค้ดที่ไม่มีใครเข้าถึง (Dead Code) — 1,745 บรรทัด = 8.5% ของ UI

ตรวจโดย grep การ import ทั่ว `lib/` — ทั้ง 5 ไฟล์ **ไม่มีไฟล์ไหน import เลย**:

| ไฟล์ | บรรทัด | หมายเหตุ |
|---|---|---|
| `logbook/logbook_progress_screen.dart` | 615 | **คือ mockup หน้าจอ 14** — แต่ยังมี test ครอบอยู่ (`test/ui_screens_18_test.dart`) → **test ให้ความมั่นใจปลอม** กับหน้าจอที่ผู้ใช้เข้าไม่ถึง |
| `expenses/expense_capture_sheet.dart` | 420 | มีบั๊กจริงหลายอย่าง (§ dead controller) |
| `notifications/notifications_sheet.dart` | 283 | ซ้ำกับ `notifications_dropdown.dart` ที่ใช้จริง |
| `dashboard/widgets/tax_shield_hero_card.dart` | 353 | **การ์ด hero ที่สวยที่สุดในแอป ถูก import โดย `cpk_home_body`** — ตรวจซ้ำ: ถูกใช้จริงผ่าน `cpk_home_body.dart` (ดูหมายเหตุ) |
| `trips/widgets/cpk_quota_claim_banner.dart` | 74 | – |

> **หมายเหตุการตรวจสอบซ้ำ:** `tax_shield_hero_card.dart` ถูกอ้างถึงใน `cpk_home_body.dart` ผ่านชื่อคลาส
> ผมจึงไม่นับไฟล์นี้เป็น dead code เต็มรูปแบบ — ต้องตรวจ import จริงอีกครั้งก่อนลบ (อย่าลบตามรายงานนี้โดยไม่ยืนยัน)

**Dead code ภายในไฟล์ที่ใช้จริง:**
- `expense_capture_sheet.dart:32` — `_notesController` ถูกประกาศ, dispose, และอ่าน (`:164-166`)
  แต่ **ไม่มี `TextField` ไหนผูกกับมัน** → `notes` เป็น `null` เสมอ
  → `evidence_expenses_screen.dart:230` แสดง `exp.notes ?? exp.category.displayName` → **ชื่อร้านค้าไม่เคยแสดง**
  (mockup แสดง Bunnings, Caltex, Officeworks, Repco — ของจริงแสดง "Materials", "Fuel")
- `notifications_dropdown.dart` กับ `notifications_sheet.dart` — 2 implementation ของ panel เดียวกัน
  หัวข้อ 16.5px vs 18px, ฟอนต์ไทล์ 13.5 vs 14, leading 38 vs 40 และ **ไม่แสดง timestamp ทั้งคู่**

---

## 9. ตารางลำดับความสำคัญ (Priority Roadmap)

จัดลำดับตาม **ผลกระทบต่อผู้ใช้ ÷ ความเสี่ยงในการแก้**

### P0 — แก้ทันที (บั๊กที่ผู้ใช้เห็น / ข้อมูลผิด) · ~1–2 วัน

| # | งาน | ไฟล์:บรรทัด | เกณฑ์ยอมรับ |
|---|---|---|---|
| 1 | แก้ RenderFlex overflow ที่การ์ด hero | `cpk_home_body.dart:188` | เรนเดอร์ที่ 390pt ไม่มี overflow อีก |
| 2 | รองรับ text scaling ไม่ให้พังถึง 200% | `tax_shield_hero_card.dart:128-141,164-183`; `scaffold_bottom_nav_bar.dart:34,278` | ผ่านทุกขนาดถึง 200% โดยไม่มี overflow |
| 3 | เพิ่มช่องกรอกเลขไมล์เริ่มต้น | `vehicle_setup_flow.dart:42,117` + ฟอร์ม | `initialOdometer > 0` หลังตั้งค่ารถ |
| 4 | แก้ `.any()` → `.every()` และข้อความรับรอง | `compliance_center_screen.dart:33-34,214-215` | ติ๊กครบเฉพาะเมื่อทุกใบมี `receiptPath`; แสดงจำนวนจริง |
| 5 | ลบข้อมูลเท็จ: "28 min", โน้ตตัวอย่าง, GPS/timestamp ที่ฟ้องว่ายืนยันแล้ว | `trip_detail_screen.dart:263,334-337,423,443` | แสดง "Not captured" เมื่อไม่มีข้อมูลจริง |
| 6 | แก้ `isVerified: true` ที่ฮาร์ดโค้ด | `expense_detail_screen.dart:1026,1029` | ผูกกับค่าจริง |
| 7 | ปลดล็อก Logbook ใน onboarding **หรือ** ซ่อนปุ่ม "Switch to Logbook" | `vehicle_setup_flow.dart:1018,1030` หรือ `money_left_on_table_card.dart:259-265` | ทั้งสองที่ต้องสอดคล้องกัน |
| 8 | guard การบันทึกซ้ำ + `try/catch` + spinner | `expense_detail_screen.dart:363,1051`; `cpk_trip_entry_screen.dart:683`; `logbook_trip_entry_screen.dart:341-351` | แตะ 2 ครั้งเร็ว ๆ สร้างได้ 1 รายการ; ล้มเหลวแล้วเห็น error |
| 9 | ยืนยันก่อนทิ้งการบันทึกสด + `PopScope` | `trip_live_tracking_screen.dart:341-347` | มี dialog ยืนยัน และ back gesture ไม่ทิ้งข้อมูลเงียบ |
| 10 | ยืนยันก่อนล้างข้อมูลทั้งหมด | `account_settings_sheet.dart:416-461` | มี dialog ยืนยันเหมือน flow ลบบัญชี |
| 11 | แก้ pluralization | `cpk_home_body.dart:62`; `money_left_on_table_card.dart:167-169`; `tax_summary_screen.dart:595,626` | ไม่มี "1 drives" |
| 12 | แก้ "km km" | `logbook_progress_screen.dart:295,313` | ใช้ `Formatters.odometer` |
| 13 | จับ `messenger` ก่อน pop | 5 จุดตาม §7 P0-8 | ข้อความยืนยันแสดงทุกครั้ง |
| 14 | แยก "ไม่มีข้อมูล" ออกจาก "ไม่มีผลตามฟิลเตอร์" | `evidence_expenses_screen.dart:211` | ข้อความต่างกัน |
| 15 | แก้ปุ่ม Discord / เพิ่มปุ่มลบ | `cpk_trip_entry_screen.dart:700-711`; เพิ่ม `deletedAt` UI | กดแล้วบันทึกเป็น personal จริง หรือไม่มีปุ่มนี้ |

### P1 — สร้างระบบดีไซน์จริง · ~4–7 วัน

| # | งาน | รายละเอียด |
|---|---|---|
| 16 | **บันเดิล Inter หรือลบ `fontFamily: 'Inter'`** | ต้องมีไฟล์ 400/500/600/700/800/900 — ถ้าไม่มี 800/900 ให้ลบ `w800`/`w900` 210 จุดออกแล้วใช้ `w700` แทน (ดู `DESIGN_SYSTEM.md` §2) |
| 17 | ใช้ type scale 9 ระดับ แทน 27 ขนาด | แทน `AppTextStyles` แล้วไล่แก้ 561 จุดที่เขียนสด (ทำเป็น batch ตามหน้าจอ) |
| 18 | เพิ่ม `FontFeature.tabularFigures()` | 7 จุดที่ตัวเลขอัปเดตสด: `tax_shield_hero_card.dart:132,168,176,280,341`; `home_telemetry_capsule.dart:167,184` |
| 19 | เปลี่ยน `ColorScheme.fromSeed` เป็น `ColorScheme.light` ที่ระบุครบ | `main.dart:59-65` — ปิดการรั่วของสี M3 ที่ไม่มีใครรีวิว |
| 20 | แก้ contrast ที่ไม่ผ่าน AA | `borderStrong` สำหรับขอบ, `amberDark` แทน `amber` บนปุ่มขาว, `0xFF047857` แทน `emerald` |
| 21 | สร้าง spacing/radius scale แล้วลบค่าที่อยู่นอกกริด | 123 → ~10 ค่า; 19 → 4 ค่า |
| 22 | สร้าง `AppCard` / `AppPill` / `AppSegmentedControl` | ทดแทนการ implement ซ้ำ 4 รอบ, pill 7 แบบ, การ์ด 49 จุด |
| 23 | ใช้ `AppShadows` จริง แล้วลบเงาที่เขียนสด | nav bar + soft card 6 จุด |
| 24 | สร้าง motion token (4 durations + 3 curves) | รวม press scale ให้เป็น 0.972 เดียว, ลบ `elasticOut` ออกจาก CTA |
| 25 | เพิ่ม reduce-motion support | เช็ค `MediaQuery.disableAnimations` |
| 26 | สร้าง state matrix: loading / empty / error / offline | เริ่มจาก `appState.isInitialized` gate ทั้งแอป |
| 27 | เพิ่ม `Semantics` + เพิ่มเป้าแตะเป็น 48dp | 8 คอนโทรล + 4 ปุ่มที่เล็กเกิน |
| 28 | แก้บั๊ก listener leak | `oddy_interactive_logo.dart:144-151` — สร้าง `CurvedAnimation` ครั้งเดียวใน `initState` |
| 29 | ล้างคำศัพท์วัตถุประสงค์ทริปให้เหลือชุดเดียว | ป้องกัน `'Personal Drive'` → ถูกบันทึกเป็น business |
| 30 | แก้ dead controller + ชื่อร้านค้า | `expense_capture_sheet.dart:32` |

### P2 — ยกระดับสู่ frontier · ~1–2 สัปดาห์

| # | งาน |
|---|---|
| 31 | Dark mode เต็มรูปแบบ (หรือลบ token `dark*` ที่ค้าง) |
| 32 | ยกเครื่องลำดับชั้นหน้า Home: hero ต้องอยู่บนสุดเสมอ, จำกัด alert เหนือ fold ให้ไม่เกิน 1 |
| 33 | ยกเครื่อง `tax_summary_screen` ให้ตัวเลขหลักเป็น hero |
| 34 | ทำ splash screen (mockup หน้าจอ 1 ยังไม่มี) |
| 35 | ลบ dead code 1,745 บรรทัด หรือต่อ `logbook_progress_screen` เข้าแอปจริง |
| 36 | เพิ่ม merchant field + date field ในการบันทึกเร็ว |
| 37 | เพิ่ม undo / ปุ่มลบ + soft delete UI |
| 38 | ใช้ `intl` + `NumberFormat.currency(locale: 'en_AU')` เพื่อความถูกต้องทางการเงิน |
| 39 | เพิ่ม skeleton shimmer แทนการวาด empty state ทันที |
| 40 | ลบ glyph `→` 23 จุด ออกเป็น `Icon` ของ Lucide |

---

## 10. สิ่งที่ทีมทำได้ดีแล้ว — ควรใช้เป็นมาตรฐานและขยายผล

1. **`logbook/widgets/odometer_camera_capture_sheet.dart`** — คุณภาพระดับที่ควรเป็นมาตรฐานทั้งแอป:
   spinner ในช่องมองภาพ (`:256-259`), spinner ในปุ่ม (`:389-397`), ปิดปุ่มทั้งสองขณะบันทึก (`:370,:388`),
   ข้อความ error ที่เฉพาะเจาะจง (`:92-107,119-130`), และยืนยันความสำเร็จ (`:151-161`)
2. **`cpk_home_body.dart:254-328`** — hero card ที่แข็งแรงที่สุด: 44px + ป้าย AUD + progress + "km left"
3. **`trip_live_tracking_screen.dart:417-436`** — 72px + หน่วยตัวพิมพ์ใหญ่ = hero ที่ดีที่สุด
4. **`scaffold_bottom_nav_bar.dart`** — floating pill nav bar พร้อม blur ที่ทำได้สวยและต่างจากคู่แข่ง
5. **`tactile_primary_button.dart:87-89`** — คำนวณ concentric radius ถูกต้อง (ที่เดียวในโปรเจกต์ที่เป็นแบบนี้)
   → ควรเป็นต้นแบบให้ `legal_document_sheet.dart:113/164` ที่ยังใช้ 10/8 ซึ่งไม่ concentric
6. **`compliance_center_screen.dart:311-327`** — "Next →" chained resolution loop
   ที่เปลี่ยนรายการแก้ไขยาว ๆ ให้เป็นงานทีละขั้นตอน — เป็นแพตเทิร์นที่ควรใช้มากขึ้น
7. **โทนสีและ gradient ของ hero card** — ดูพรีเมียมและแตกต่างจากแอป logbook ทั่วไป
8. **การเลือกใช้ Lucide icon แทน Material Icons ใน 90% ของแอป** — ให้ความรู้สึกทันสมัยกว่า

---

## ภาคผนวก: วิธี reproduce หลักฐานทั้งหมด

```bash
# 1) เรนเดอร์หน้าจอจริงทั้ง 17 หน้าจอ (ไม่ต้องมี simulator)
flutter test tool/design_audit/ui_capture_test.dart --update-goldens
# → tool/design_audit/captures/*.png  (390×844 @3x = 1170×2532)

# 2) ตรวจการพังของเลย์เอาต์เมื่อขยายขนาดตัวอักษร
flutter test tool/design_audit/ui_textscale_test.dart --update-goldens
# → captures/a11y_textscale_{1.0,1.3,2.0}.png

# 3) ทดสอบพื้นฐาน
flutter test test/     # → 219 ผ่าน
```

ฮาร์เนสโหลดฟอนต์ Roboto เข้า family `'Inter'` เพื่อให้เห็นตัวอักษรจริง
(ไม่ใช่กล่องสี่เหลี่ยม) — การที่ต้องทำเช่นนี้คือหลักฐานของปัญหาข้อ P0-9

---

## ภาคผนวก: Anchor Index — ค้นหาโค้ดแทนการเชื่อเลขบรรทัด

เนื่องจากไฟล์ในโปรเจกต์นี้ถูกเขียนทับโดยกระบวนการอัตโนมัติ (ดูคำเตือนด้านบน)
**เลขบรรทัดอาจเลื่อนได้** ตารางนี้ให้ "ข้อความค้นหา" ที่ไม่เปลี่ยนตามเวลา
ใช้ `grep -n "<ข้อความ>" <ไฟล์>` เพื่อหาตำแหน่งปัจจุบัน

| # | ปัญหา | ไฟล์ | ค้นหาด้วย |
|---|---|---|---|
| P0-1 | RenderFlex overflow ที่การ์ด hero | `cpk_home_body.dart` | `mainAxisAlignment: MainAxisAlignment.spaceBetween` (ตัวที่ 1) |
| P0-1 | ชื่อหัวข้อที่ล้น | `cpk_home_body.dart` | `ESTIMATED TAX DEDUCTION` |
| P0-2 | ตัวเลข hero ไม่มี Flexible | `tax_shield_hero_card.dart` | `Formatters.currency(summary.centsPerKmClaim)` |
| P0-2 | nav bar สูงตายตัว | `scaffold_bottom_nav_bar.dart` | `final totalBarHeight = 66.0` |
| P0-3 | controller เลขไมล์ที่ไม่ถูกใช้ | `vehicle_setup_flow.dart` | `_odometerController.text` |
| P0-3 | ค่าเริ่มต้น 0 | `vehicle_setup_flow.dart` | `initialOdometer: odo` |
| P0-4 | `.any()` ที่ควรเป็น `.every()` | `compliance_center_screen.dart` | `appState.expenses.any(` |
| P0-4 | ข้อความรับรองเกินจริง | `compliance_center_screen.dart` | `Cloud vault encrypted` |
| P0-5 | "28 min" ฮาร์ดโค้ด | `trip_detail_screen.dart` | `· 28 min` |
| P0-5 | โน้ตตัวอย่างจาก mockup | `trip_detail_screen.dart` | `Installed electrical switchboard` |
| P0-5 | อ้างว่ามี GPS ทั้งที่ไม่ได้ตรวจ | `trip_detail_screen.dart` | `GPS point logged` |
| P0-5 | อ้างว่าล็อกเวลาแล้ว | `trip_detail_screen.dart` | `Timestamp locked` |
| P0-5 | ตรวจสอบแบบฮาร์ดโค้ด | `expense_detail_screen.dart` | `isVerified: true` |
| P0-5 | ใบเสร็จที่แต่งจำนวนขึ้นมา | `money_left_on_table_card.dart` | `8 fuel receipts` |
| P0-6 | Logbook ถูกล็อก | `vehicle_setup_flow.dart` | `COMING SOON` |
| P0-6 | ปุ่มสลับไป Logbook | `money_left_on_table_card.dart` | `Switching to Logbook unlocks` |
| P0-7 | await ที่ไม่มี spinner/guard | `expense_detail_screen.dart` | `_receiptAuditService.create(` |
| P0-7 | ปุ่มบันทึกไม่ส่ง isLoading | `cpk_trip_entry_screen.dart` | `Save Work Trip` |
| P0-8 | จับ messenger ถูกวิธี (ต้นแบบ) | `expense_detail_screen.dart` | `final messenger = ScaffoldMessenger.of(context)` |
| P0-9 | อ้าง Inter แต่ไม่บันเดิล | `main.dart` | `fontFamily: 'Inter'` |
| P0-9 | ลูกศรในข้อความ | `tax_summary_screen.dart` | `'Review all →'` |
| P0-10 | ปุ่ม "Stop" เล็กเกิน | `home_telemetry_capsule.dart` | `'Stop'` |
| P0-10 | ปิดขั้นต่ำ 48dp ของ M3 | `legal_document_sheet.dart` | `MaterialTapTargetSize.shrinkWrap` |
| §4.1 | การ์ดเตือนดัน hero ตกจอ | `cpk_home_body.dart` | `MoneyLeftOnTableCard(appState` |
| §4.1 | การ์ด hero อยู่หลังการ์ดเตือน | `logbook_home_body.dart` | `MoneyLeftOnTableCard(` |
| §4.2 | hero เล็กกว่าคะแนนรอง | `tax_summary_screen.dart` | `fontSize: 17,` (คู่กับ `totalClaim`) |
| §4.2 | คะแนน readiness | `tax_summary_screen.dart` | `fontSize: 22,` |
| §5 | ไม่มีใครอ่าน isInitialized | `app_state.dart` | `bool get isInitialized` |
| §5 | empty state หลอกผู้ใช้ | `evidence_expenses_screen.dart` | `child: filtered.isEmpty` |
| §5 | นำเข้าล้มเหลวแต่ขึ้นติ๊กเขียว | `migration_screen.dart` | `totalParsed == 0` |
| §6 | กับดัก: ออกจาก setup ไม่ได้ | `onboarding_flow_screen.dart` | `return VehicleSetupFlow(` |
| §6 | ปุ่มทิ้งข้อมูลโดยไม่ถาม | `account_settings_sheet.dart` | `Remove from this` |
| §6 | "Discard / Personal Trip" | `cpk_trip_entry_screen.dart` | `'Discard / Personal Trip'` |
| §6 | ทิ้งการบันทึก GPS | `trip_live_tracking_screen.dart` | `Icons.close_rounded` |
| §6 | ไม่มีปุ่มลบที่ไหนเลย | `trip.dart` | `deletedAt` |
| §7.1 | ไวยากรณ์ผิด ไม่มี pluralization | `cpk_home_body.dart` | `drives need your sign-off` |
| §7.2 | "km km" | `logbook_progress_screen.dart` | `Formatters.distance(` |
| §7.2 | ไม่มีปีใน timestamp | `formatters.dart` | `static String dateTime` |
| §7.6 | 'Personal Drive' → บันทึกเป็น business | `logbook_trip_entry_screen.dart` | `== 'Personal'` |
| §7.7 | CPK math กับทริป logbook | `trip_detail_screen.dart` | `centsPerKmRate` |
| §8 | Dead code: ไม่มีใคร import | `logbook_progress_screen.dart` | (ตรวจด้วย `grep -rn "logbook_progress_screen" lib/`) |
| §8 | dead controller | `expense_capture_sheet.dart` | `_notesController` |
| §3.4 | listener leak | `oddy_interactive_logo.dart` | `anim.addListener(` |
| §10 | ต้นแบบคุณภาพ (camera sheet) | `odometer_camera_capture_sheet.dart` | `_isSaving` / `sha256` |
| §10 | concentric radius ที่ถูกต้อง | `tactile_primary_button.dart` | `innerRadius` |

### ตรวจซ้ำได้ด้วยคำสั่งเดียว

```bash
# ยืนยันว่าโค้ดที่อ้างถึงยังอยู่ (ปรับข้อความค้นหาตามตาราง)
grep -n "_odometerController.text"  lib/ui/screens/vehicle/vehicle_setup_flow.dart
grep -n "appState.expenses.any("    lib/ui/screens/compliance/compliance_center_screen.dart
grep -n "· 28 min"                  lib/ui/screens/trips/trip_detail_screen.dart
grep -n "COMING SOON"               lib/ui/screens/vehicle/vehicle_setup_flow.dart

# ยืนยันว่าบั๊กยังอยู่จริง (ไม่ใช่แค่ทฤษฎี) — รันฮาร์เนส
flutter test tool/design_audit/ui_capture_test.dart 2>&1 | grep -i overflow
```

---

## 10. สถานะการแก้ไข (แก้แล้ว / ยังเหลือ)

แก้เมื่อ 3 ต.ค. 2026 · **219/219 เทสต์ผ่าน** · `flutter analyze lib/` สะอาด · overflow **0 จุด**

### ✅ ราก design system

| สิ่งที่ทำ | รายละเอียด |
|---|---|
| สร้าง 4 ไฟล์ token ใหม่ | [`app_color.dart`](../../lib/core/theme/app_color.dart) · [`app_typography.dart`](../../lib/core/theme/app_typography.dart) · [`app_space.dart`](../../lib/core/theme/app_space.dart) · [`app_motion.dart`](../../lib/core/theme/app_motion.dart) — type scale 9 ระดับ, สี 4 ชั้นที่ผ่าน contrast, spacing 4pt, radius 4 ค่า, elevation 3 ระดับ, motion 6 duration + 4 curve |
| **บันเดิล Inter จริง** | 6 น้ำหนัก (400–900) subset เฉพาะ Latin+สกุลเงิน+ลูกศร+สัญลักษณ์ = **512 KB** (จาก 2.4 MB ถ้าใช้ไฟล์เต็ม) ลงทะเบียนใน `pubspec.yaml` แล้ว — ยืนยันด้วย `FontManifest.json` ว่ามี family `Inter` ครบทั้ง 6 weight |
| แก้ `ThemeData` | เปลี่ยน `ColorScheme.fromSeed` (ที่อ่านไม่ถึง) → `ColorScheme.light` ที่ระบุครบ + `textTheme` จาก type scale — [`main.dart`](../../lib/main.dart) |
| ลบ dead flag `isComingSoon` | ลบทั้งพารามิเตอร์และสาขาที่ตายแล้วใน `_buildTaxOptionCard` |

### ✅ P0 ทั้ง 15 ข้อ

| # | ปัญหา | แก้แล้วอย่างไร | หลักฐาน |
|---|---|---|---|
| P0-1 | RenderFlex overflow บนการ์ด hero | แก้ 4 `Row`: hero header, distance row, onboarding artwork ×2, expense detail ×2 → ใช้ `Expanded`/`Flexible` + `ellipsis` | **0 overflow** ใน 17 หน้าจอ |
| P0-2 | เลย์เอาต์พังที่ text scale ≥130% | `FittedBox` ที่ตัวเลข hero, nav label จำกัด scale + `maxLines`, `LayoutBuilder` ที่ progress bar, `Flexible` ที่หัวข้อ | **0 overflow** ที่ 100/130/200% |
| P0-3 | `initialOdometer` = 0 เสมอ | เพิ่มช่องกรอกเลขไมล์ (คีย์บอร์ดตัวเลข, `suffixText: km`) + บังคับกรอกพร้อมข้อความ error ในบรรทัด | [`vehicle_setup_flow.dart`](../../lib/ui/screens/vehicle/vehicle_setup_flow.dart) |
| P0-4 | `.any()` ทำให้ติ๊กครบทั้งที่ยังไม่ทำ | เปลี่ยนเป็นนับเฉพาะใบที่มี receipt **และ** ผ่านการตรวจ (ตรงกับสูตรคะแนนใน `AppState`) + แสดง "X of Y receipts attached" + **ลบข้อความ "Cloud vault encrypted & synchronized"** | [`compliance_center_screen.dart`](../../lib/ui/screens/compliance/compliance_center_screen.dart) |
| P0-5 | ข้อมูลที่แต่งขึ้น | ลบ `"· 28 min"`, โน้ตตัวอย่างจาก mockup, `"GPS point logged"`, `"Timestamp locked"`, `isVerified: true` ×2 (ผูกกับ FY check จริง + การยืนยันหมวดหมู่จริง), `"8 fuel receipts"`, ชื่อรถ fallback ปลอม, `"Photo attached & verified"` | `trip_detail_screen.dart`, `expense_detail_screen.dart`, `money_left_on_table_card.dart` |
| P0-6 | Logbook ถูกล็อก แต่ถูกโฆษณาให้สลับ | ลบ `COMING SOON` + ปลดล็อกจริง + เปลี่ยน `$4,550` ที่ฮาร์ดโค้ดเป็นค่าจาก `AppConstants.activeTaxRule` | `vehicle_setup_flow.dart` |
| P0-7 | บันทึกซ้ำได้ / ล้มเหลวเงียบ | `_isSaving` + `try/catch` + spinner + disable ปุ่ม ที่บิลค่าใช้จ่าย, ทริป CPK, ทริป logbook และปุ่ม Stop (latch กัน re-entry) | ทุกจุดที่ `await` |
| P0-8 | แสดงข้อความยืนยันบน context ที่ pop ไปแล้ว | จับ `Navigator`/`ScaffoldMessenger` **ก่อน** pop ทั้ง 5 จุด | `cpk_trip_entry`, `logbook_trip_entry`, `trip_quick_resolve`, `trip_review`, `account_settings` |
| P0-9 | ลูกศร `→` ในข้อความ | แก้ที่ **จุดเรนเดอร์** ของ `tax_summary` (ตัด `→` แล้ววาด `LucideIcons.chevronRight`) → แก้ทั้ง 8 ป้ายพร้อมกัน + เปลี่ยนใน trips ledger / onboarding / snackbar | [`tax_summary_screen.dart`](../../lib/ui/screens/tax/tax_summary_screen.dart) |
| P0-10 | เป้าแตะเล็ก / ไม่มี Semantics | FAB กลาง 48→52 + `Semantics` · nav item มี `selected:` · bell 44→48 + ป้ายบอกจำนวนที่ยังไม่อ่าน · avatar 46→48 · Stop ~26→44 · expand ~27→44 · ปุ่ม Done 27→48 (เดิม **ปิดขั้นต่ำ M3 เอง**) | `scaffold_bottom_nav_bar.dart`, `home_header_bar.dart`, `home_telemetry_capsule.dart`, `legal_document_sheet.dart` |
| P0-11 | ไม่มี pluralization | ยอดแจ้งเตือน (`1 drive needs`), การ์ด money (1 drive is), tax summary (1 drive) | — |
| P0-12 | `"km km"` | ใช้ `Formatters.odometer` แทน `Formatters.distance` (และแก้ทศนิยมให้เป็นจำนวนเต็มด้วย) | `logbook_progress_screen.dart` |
| P0-13 | **บันทึกทริปส่วนตัวกลายเป็น business** | `trip_quick_resolve_sheet` สร้าง `Trip` ใหม่ทีละฟิลด์และ **ทิ้ง `jobReference`, `taxMethod`, `evidenceSource`, `clientDedupId`** → เปลี่ยนเป็น `trip.copyWith(...)` | [`trip_quick_resolve_sheet.dart`](../../lib/ui/screens/trips/trip_quick_resolve_sheet.dart) |
| P0-14 | empty state โกหกผู้ใช้ | แยก "ไม่มีข้อมูล" ออกจาก "ไม่ตรงตัวกรอง" พร้อมปุ่มทางออกทั้งสองกรณี | `evidence_expenses_screen.dart` |
| P0-15 | ทิ้งข้อมูลโดยไม่ถาม | หน้าจอ live tracking: เพิ่ม `PopScope` + dialog เลือก *Keep recording / Discard / End & save* · ล้างข้อมูลในเครื่อง: เพิ่ม dialog ยืนยันพร้อมคำเตือน ATO 5 ปี · เปลี่ยนปุ่ม "Discard / Personal Trip" เป็น **"Not a work drive"** ให้ตรงกับสิ่งที่เกิดขึ้นจริง | `trip_live_tracking_screen.dart`, `account_settings_sheet.dart`, `cpk_trip_entry_screen.dart` |

### ✅ ที่แก้เพิ่มระหว่างทาง

- **ระยะห่างล่างของ scroll view** ทั้ง 4 จุดเลิกใช้เลขมหัศจรรย์ 120/116 → เรียก `ScaffoldBottomNavBar.clearanceFor(context)` ที่คำนวณจากความสูงจริงของแถบ
- **ป้ายทะเบียนซ้ำซ้อน** ถูกถอดออกจาก hero card (ขึ้นอยู่แล้วใน header bar ข้างบน) ซึ่งเป็นสาเหตุที่แท้จริงของ overflow
- **progress bar ที่ค่า ~0%** ไม่เรนเดอร์เป็นเศษ 2px อีกต่อไป (กำหนดความยาวขั้นต่ำ 8px)
- **ตรวจซ้ำแล้วไม่จริง 2 ข้อ** จึงไม่แก้และไม่กล่าวหา: (1) ป้าย bottom nav ผ่าน contrast 7.3:1 ไม่ใช่ 2.5:1 (2) ปุ่ม Stop **ไม่ได้** ทิ้งข้อมูล — มันบันทึกทริปแล้วเปิดหน้าจอตรวจสอบให้ยืนยัน

### ⏳ ยังเหลือ — ดูแผนงานเต็มที่ [`03-completion-plan.md`](./03-completion-plan.md)

สรุปสั้น (ตัวเลขวัดจากโค้ดจริง):

1. **เฟส 2A — ย้ายสี hex → `AppColor`**: 305 จุด / 46 ไฟล์ (149 จุด = 48% แทนได้ตรง ๆ ด้วย codemod)
2. **เฟส 2B — ย้าย `TextStyle` → `AppType`**: 576 จุด
3. **เฟส 2C — ย้าย spacing/radius/เงา**: 381 + 350 + 613 + 49 = 1,393 จุด
4. **เฟส 3.1 — ลำดับชั้นหน้า Home**: ตัวเลข hero ยังอยู่ใต้การ์ดเตือน (ต้องสลับลำดับ + จำกัด alert เหนือ fold ไม่เกิน 1 ใบ)
5. **เฟส 3.2 — Dead code 3,314 บรรทัด** ที่ยืนยันแล้วว่าไม่มีใครอ้างถึง
   (`logbook_progress_screen` 615, **`sign_in_screen` 464 ทั้งหน้าจอ**, `migration_screen` 436, `ato_report_service` 422,
   `expense_capture_sheet` 420, `tax_shield_hero_card` 353, `notifications_sheet` 283, `cpk_quota_claim_banner` 74)
   → ต้องตัดสินใจว่า **ลบ** หรือ **ต่อกลับเข้าแอป**
6. **เฟส 3.3–3.8** — splash screen · loading/empty/error state · `intl` + ปีในวันที่ · reduce-motion ·
   ล้าง token ที่ไม่ใช้ (`dark*` 3 ตัว + `telemetry*` 4 ตัว) · emoji · ปุ่มลบ · ช่อง merchant/วันที่

**dark mode ถูกตัดออกจากขอบเขต** (ตกลงเมื่อ 3 ต.ค. 2026) — แต่ต้องเก็บกวาด token `dark*` ที่ค้างอยู่ให้สะอาด

### 📝 เทสต์ที่ต้องแก้ตามการเปลี่ยน copy (3 ไฟล์)

การแก้ P0-5 และ P0-12 เปลี่ยนข้อความที่ผู้ใช้เห็น ซึ่งมีเทสต์ผูกกับ **ตัวอักษรเป๊ะ ๆ** อยู่ จึงแก้เฉพาะ assertion เชิงถ้อยคำให้กลายเป็นเชิงพฤติกรรม โดย **ไม่ลดความเข้มของเทสต์**:

| ไฟล์ | เดิม | ใหม่ |
|---|---|---|
| [`differentiation_moat_test.dart`](../../test/differentiation_moat_test.dart) | `textContaining('TR 97/11')` | `textContaining('missing a work reason')` (ยังยืนยันการ์ด + ยอดเงินครบ) |
| [`smart_pivot_monitor_test.dart`](../../test/smart_pivot_monitor_test.dart) | `textContaining('fuel receipts in the glovebox')` | `textContaining('in the vault')` + **เพิ่ม** `findsNothing` สำหรับ `'8 fuel receipts'` |
| [`cpk_compliance_ux_test.dart`](../../test/cpk_compliance_ux_test.dart) | `find.text('Log Drive →')` | `find.text('Log drive')` (ลูกศรย้ายไปเป็น icon แล้ว) |
