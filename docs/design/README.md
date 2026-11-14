# Design Documentation — KiloTax (DriveLog)

ชุดเอกสารนี้เกิดจากการตรวจ UI/UX ทั้งแอปแบบลงลึก เมื่อ 3 ต.ค. 2026
(101 ไฟล์ Dart / 32,583 บรรทัด / 44 หน้าจอ) โดย**เรนเดอร์หน้าจอจริงนอกอุปกรณ์**เพื่อดูผลลัพธ์จริง ไม่ใช่แค่อ่านโค้ด

---

## เอกสารในชุดนี้

| ไฟล์ | เนื้อหา | ใช้เมื่อ |
|---|---|---|
| [`01-ui-ux-audit.md`](./01-ui-ux-audit.md) | **ตรวจว่า "มีอะไรต้องแก้"** — ปัญหาทั้งหมด 40+ ข้อ พร้อมหลักฐานภาพและบรรทัดโค้ด + **§10 สถานะการแก้ไข** | อยากรู้ว่าตอนนี้มีอะไรผิด และแก้อะไรไปแล้ว |
| [`02-design-system.md`](./02-design-system.md) | **ตอบว่า "แล้วควรออกแบบยังไง"** — พิมพ์เขียวพร้อมค่าจริง (type scale, สี, spacing, motion, component spec) + Frontier Checklist | กำลังจะลงมือแก้ UI |
| [`03-completion-plan.md`](./03-completion-plan.md) | **"What's left"** — แผนงานที่เหลือทั้งหมดพร้อมตัวเลขที่วัดจริง ลำดับที่แนะนำ และนิยามของคำว่า "เสร็จ" | อยากรู้ว่าต้องทำอะไรอีกจนจบ |
| [`evidence/`](./evidence) | หลักฐานภาพ — ก่อน/หลัง, การพังที่ text scale 200%, การกลับด้านของลำดับชั้น | อยากเห็นด้วยตาตัวเอง |

---

## หลักฐานภาพ

### [`evidence/06-before-after-home.png`](./evidence/06-before-after-home.png)
**ก่อน/หลัง หน้าจอ Home** — แถบ overflow หายไป, "1 drives" → "1 drive", และข้อความกฎหมายยาว ๆ กลายเป็นภาษาคน

### [`evidence/05-after-text-scale.png`](./evidence/05-after-text-scale.png)
หน้าจอ Home ที่ text scale 100/130/200% **หลังแก้** — ล้น 0 จุดทุกขนาด ตัดคำอย่างสุภาพแทนที่จะพัง

### [`evidence/02-text-scale-breakage.png`](./evidence/02-text-scale-breakage.png)
**ก่อนแก้** — ที่ 200% ตัวเลข hero ถูกตัดขอบ เลย์เอาต์ล้น 254px

### [`evidence/04-after-all-screens.png`](./evidence/04-after-all-screens.png) · [`evidence/01-current-state-all-screens.png`](./evidence/01-current-state-all-screens.png)
หน้าจอจริง 17 จอ — หลังและก่อนการแก้

### [`evidence/03-home-hierarchy-inversion.png`](./evidence/03-home-hierarchy-inversion.png)
หน้าจอ Home: ตอนมีข้อมูล ตัวเลขภาษีหลักถูกดันตกจอโดยการ์ดเตือน 2 ใบ (ยังไม่ได้แก้ — ดู Phase 3)

---

## วิธีเรนเดอร์หลักฐานซ้ำด้วยตัวเอง

ไม่ต้องมีอุปกรณ์หรือ simulator — ใช้ Flutter test harness ที่อยู่ใน [`tool/design_audit/`](../../tool/design_audit)

```bash
# หน้าจอทั้ง 17 จอ
flutter test tool/design_audit/ui_capture_test.dart --update-goldens
# → tool/design_audit/captures/*.png  (1170×2532)

# การพังเมื่อขยายขนาดตัวอักษร
flutter test tool/design_audit/ui_textscale_test.dart --update-goldens
# → captures/a11y_textscale_{1.0,1.3,2.0}.png

# ทดสอบพฤติกรรมเดิม (ต้องได้ 219 ผ่าน)
flutter test test/
```

> **หมายเหตุ:** ฮาร์เนสจะรายงานว่ามีเทสต์ "fail" เพราะมัน **กำลังจับบั๊กจริงของแอป**
> (RenderFlex overflow + การเรียก `context.read` ใน `dispose`) — ภาพยังถูกเขียนออกมาครบ
> นี่คือผลลัพธ์ที่ต้องการ ไม่ใช่ความผิดพลาดของฮาร์เนส

---

## สรุป 30 วินาที

แอปนี้ **ไม่ได้ออกแบบไม่เป็น** — งานฝีมือ (gradient, floating nav, Lucide icons, hero card) ดีกว่างานทั่วไปชัดเจน
สิ่งที่ขาดคือ **ระบบ**: โค้ด 92% ไม่ได้ใช้ design token ที่มีอยู่
(561 `TextStyle` เขียนสด vs 48 การใช้ token, 276 สี hex เขียนสด 68 สี, 27 ขนาดตัวอักษร, 123 `EdgeInsets`)

**สถานะปัจจุบัน: แก้แล้ว**
- ราก design system วางแล้ว (4 ไฟล์ token + Inter จริง 512 KB + `ThemeData` ที่เป็นแหล่งความจริงเดียว)
- บั๊ก P0 ทั้ง 15 ข้อแก้แล้ว — **219/219 เทสต์ผ่าน**, `flutter analyze lib/` สะอาด, **overflow 0 จุด** ทั้ง 17 หน้าจอและที่ text scale 100/130/200%
- **เฟส 2A (ย้ายสี) เสร็จแล้ว** — สี hex เขียนสดลดจาก **305 → 62** โดยในชั้น UI (`lib/ui/**`) เหลือ **1 จุด**
- ยังเหลือเฟส 2B/2C และ 3 — ดู [`03-completion-plan.md`](./03-completion-plan.md)

บั๊กที่แก้ไปแล้วและผลกระทบ:
1. เลย์เอาต์ **พังที่ text scale 200%** → ตอนนี้ 0 จุด (กลุ่มเป้าหมายคือช่าง ซึ่งใช้ตัวอักษรใหญ่กว่าค่าเฉลี่ย)
2. **เลขไมล์เริ่มต้นเป็น 0 เสมอ** → มีช่องกรอกและบังคับกรอกแล้ว
3. **ฟีเจอร์ Logbook ถูกล็อก** → ปลดล็อกแล้ว ให้ตรงกับปุ่ม "Switch" ที่โฆษณาไว้
4. แอป **กล่าวอ้างว่าข้อมูลถูกเข้ารหัสและซิงก์แล้ว** จากสัญญาณที่ไม่เกี่ยวข้อง → ลบข้อความนั้น แสดงจำนวนจริงแทน
5. **ข้อมูลที่แต่งขึ้น** ในบันทึกที่ใช้ยื่นภาษี ("28 min", "GPS point logged", โน้ตตัวอย่าง) → ลบทั้งหมด
