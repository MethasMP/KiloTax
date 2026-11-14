# Menu remediation — 8 พฤศจิกายน 2026

แก้ presentation และ navigation ตาม F01–F18 ของ [audit ก่อนแก้](/Users/methas/Desktop/DriveLog/docs/design/04-menu-audit-2026-11-08.md) โดยใช้ EDE Tier 2: กำหนด invariants, เก็บ counterexamples, แก้ให้ผ่าน และตรวจ runtime/static evidence

## พฤติกรรมที่เปลี่ยน

| Finding | ผลหลังแก้ |
|---|---|
| F01 — สถานะ Tax/Compliance ขัดกัน | ใช้จำนวนงานจาก canonical evidence report; ไม่ใช้คะแนน setup เป็นคำรับรองว่าเอกสารพร้อม |
| F02 — Expense พร้อมทั้งที่ต้องตรวจ | แยก Amount entered / Review required และใช้ amber กับงานค้าง |
| F03 — คำรับรองเกินหลักฐาน | แก้ sign-in, onboarding, setup และ logbook copy; ลบยอดผลประโยชน์ตัวอย่างที่ไม่ได้อิงข้อมูลผู้ใช้และคำว่า certified/audit-proof |
| F04 — Review filter ไม่ตรงคิว | Trips และ Recent activity ใช้ canonical trip review IDs |
| F05 — View เปิดฟอร์มเพิ่ม | View พาไป ledger; Add trip ใช้คำและปลายทางที่ตรงงาน |
| F06 — แท็บเปลี่ยนความหมาย | เก็บ semantic destination; Expenses ที่ใช้ไม่ได้หลังสลับวิธีภาษีกลับ Home; ใช้ชื่อ Home เหมือนกันและมี Add trip บน toolbar ของรายการที่มีข้อมูล |
| F07 — ตัวอักษรใหญ่ล้น | ให้แถวข้อมูล reflow, Expenses เลื่อน header และรายการร่วมกัน, form/empty state ไม่ตรึงความสูงจนข้อมูลล้น |
| F08 — Contrast regression | LogbookFooter ใช้ onPrimary; back control ใช้สีข้อความเข้มบน toolbar สว่าง |
| F09 — Button role | ปุ่มหลักใช้ Material FilledButton พร้อม semantics/focus/disabled state ของ control มาตรฐาน |
| F10 — Scanner mental model | ใช้ Open camera scanner / Gallery / Manual; ไม่มีกรอบ preview จำลองหรือ flash toggle ที่ไม่ได้ควบคุมกล้อง |
| F11 — Context รถ/FY | Expenses และ Trips แสดงขอบเขต current vehicle/FY ที่ตรงกับ review |
| F12 — Recorded กับ deductible | แสดง Recorded expenses in this filter; ไม่สมมติ Payment method เป็น Business Account |
| F13 — Unclassified ดูเหมือน personal | ใช้ Unclassified trip แทน Personal Drive สำหรับรายการที่ยังไม่ได้จัดประเภท |
| F14 — Empty state เทคนิคมากเกิน | No trips yet + ขั้นตอนถัดไป; ไม่มี FY25 หรือคำรับรองที่ไม่อิงข้อมูล |
| F15 — เป้ากดเล็ก | เพิ่มพื้นที่กด review actions; ใช้ปุ่มมาตรฐานแทนข้อความ Review all ขนาดเล็ก |
| F16 — Draft/share ไม่ตรงกัน | Tax พาไปคิว review กลางที่ตรวจไฟล์ก่อนแชร์ ZIP; legacy pre-flight แยก Share draft for review จาก Share records |
| F17 — ฟอร์มไม่เป็นระบบ | CPK เริ่มจาก Trip distance, route และ work purpose; deduction เป็นข้อมูลรอง ใช้ field ที่เห็นชัดและ shared button/reflow patterns |
| F18 — Settings/notifications/ink | จัด Settings, Account & backup, Help & privacy; notification sheet ใช้ panel เดียวกับ dropdown; navigation จัดสองแถวเมื่อชื่อเมนูไม่พอดี; LogbookPanel ใช้ Material ให้ ink feedback แสดงได้ |

สูตรภาษี, tax rules, โมเดล record, persistence, auth และโค้ดสร้าง export ไม่ได้แก้ในงานนี้ การเปลี่ยน sharing เป็นการใช้ flow ที่มีอยู่แล้ว ไม่ใช่การเขียนระบบ export ใหม่

## หลักฐานตรวจ

- **Render gate:** 66/66 cases, 33 หน้าจอ/สถานะ × 2 profiles, ไม่มี overflow หรือ framework errors พร้อมตรวจ JSON error arrays แยกจาก exit code ของ capture harness
- Profiles: 390×844/text100% และ 320×844/text200%; มีทั้งหน้าปกติ, ข้อมูลว่าง, งานค้าง, onboarding, และรายการทริปที่มี floating navigation
- **Executable UI contracts:** 54/54 affected-flow tests และ 14/14 regression contracts ผ่าน (มีเคสซ้ำระหว่างสองชุด) รวม regression contracts ใน product suite ใน [menu_remediation_test.dart](/Users/methas/Desktop/DriveLog/test/menu_remediation_test.dart)
- คู่สีจริงของ LogbookFooter: ข้อความขาวบน terracotta ได้ประมาณ **5.18:1**; มีเทสต์ตรวจ back-control contrast และ Add trip บน toolbar
- **Static analysis:** No issues found (lib + regression test + audit harness)
- **Product suite รอบกว้าง:** 450 passed / 10 failed (รวมหนึ่งไฟล์ test ที่ compile ไม่ผ่านเพราะอ้าง API จำลองทริปที่ไม่มีแล้ว) เทสต์ที่ยังล้มเหลวทั้ง10ตรงกับ counterexamples ที่รันซ้ำได้ใน source ก่อนงานนี้ ไม่มี failure ใหม่ในรอบนั้น หลังจากนั้นตรวจซ้ำเฉพาะ UI contracts/เส้นทางและ renderer ที่เกี่ยวข้องกับการเก็บรายละเอียดท้ายงาน

หลักฐาน: [verification.json](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/verification.json), [product suite](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/product-tests.log), [baseline suite](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/baseline-tests.log), [focused suite](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/focused-tests.log), [analyzer](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/analyze.log), [render summary](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/after-evidence/summary.json)

## ภาพก่อน/หลัง

![Tax ก่อนและหลัง](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/before-after-tax.png)

![CPK form ก่อนและหลัง](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/before-after-trip.png)

ภาพแต่ละสถานะและ JSON อยู่ใน [after-evidence](/Users/methas/Desktop/DriveLog/.audit/menu-remediation-2026-11-08/after-evidence) ส่วน before-evidence และ before-source เก็บผลก่อนเริ่มแก้ไว้แยกกัน

## ข้อจำกัดที่ยังเปิด

- 10 failures เดิมได้รับการแก้ไขในรอบติดตามแล้ว ดู [ผลการแก้และหลักฐาน EDE](/Users/methas/Desktop/DriveLog/docs/design/06-test-failure-resolution-2026-11-08.md) ผล 450 passed / 10 failed ด้านบนเป็นหลักฐานประวัติของรอบ UI ก่อนติดตามแก้ ไม่ใช่สถานะปัจจุบัน
- ยังไม่ได้ทดสอบกล้อง, permission, auth, VoiceOver/TalkBack, keyboard หลายแบบ หรือแสงแดดบนอุปกรณ์จริง จึงไม่ประกาศ WCAG conformance ทั้งแอปหรือผลลัพธ์ usability กับผู้ใช้จริง
- การแก้ visual consistency รอบนี้ครอบคลุมปัญหาที่ audit ระบุ ไม่ใช่การแทนทุก raw TextStyle ด้วย token หรือการออกแบบหน้าจอใหม่ทุกหน้า

## ทำซ้ำ

```sh
flutter test --no-pub test/menu_remediation_test.dart
flutter test --no-pub tool/design_audit/menu_audit_test.dart
flutter analyze --no-pub lib test/menu_remediation_test.dart tool/design_audit/menu_audit_test.dart tool/design_audit/menu_contract_audit_test.dart
```

Capture harness บันทึก errors ลง JSON เพื่อให้ได้หลักฐานครบทุกสถานะ การตรวจว่าเสร็จต้องยืนยันทุก error array ว่างด้วย ไม่ใช้คำว่า All tests passed ของ harness เป็นตัวแทนผล UI
