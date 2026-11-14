# Logbook UX elevation plan

วันที่ 6 พฤศจิกายน 2026 · ขอบเขต: Logbook method บน Flutter iOS/Android · สถานะ: แผนก่อน implementation

## เป้าหมายและขอบเขตหลักฐาน

ทำให้คนขับเปิดแอปแล้วรู้ว่าแอปพร้อมบันทึกหรือไม่ มีอะไรต้องตรวจ และต้องทำอะไรต่อจนส่งข้อมูลให้นักบัญชีได้ เป้าหมายด้านภาพคือเครื่องมือการเงินที่อ่านง่าย สุขุม และมีลำดับความสำคัญชัดเจน

ตรวจ source ปัจจุบันของ Home, Setup, Progress, Manual Entry, Hero และ Navigation รวมถึง PRODUCT.md / DESIGN.md และรายงานเดิม ตรวจภาพ `tool/design_audit/captures/13_logbook_progress.png` เป็นหลักฐานประวัติเท่านั้น ภาพนั้นไม่สะท้อน hero ที่เพิ่มใน source ปัจจุบัน ยังไม่ได้เดินแอปจริงหรือสัมภาษณ์ผู้ใช้ จึงไม่ให้คะแนน usability หรืออ้างว่าทดสอบกับผู้ใช้แล้ว

รายงานเดิมระบุว่า P0 ถูกแก้แล้ว แต่ไม่ถือเป็นหลักฐานรับรอง build ปัจจุบัน capture harness เดิมยัง import migration screen ที่ถูกลบ ต้องปรับให้ใช้ได้ก่อนสร้าง baseline ใหม่ แผนนี้ไม่แก้หรือ commit งานเดิมที่อยู่ใน working tree

## ข้อค้นพบที่กำหนดทิศทาง

| ความสำคัญ | หลักฐานใน source ปัจจุบัน | ผลต่อประสบการณ์ | แนวทาง |
|---|---|---|---|
| P0 | `tax_exemption_streak_hero.dart` ใช้ข้อความ `On Track` คงที่ และบอก `active & recording` เมื่อมีระยะสะสม | ผู้ใช้อาจเชื่อว่า tracking ทำงาน ทั้งที่ข้อความไม่ได้อิงสถานะ tracking | แยกสถานะ permission, tracking, review, sync และความครบถ้วน; แต่ละสถานะต้องมีแหล่งข้อมูลจริง |
| P0 | `logbook_trip_entry_screen.dart` เติมช่องว่างเลขไมล์เป็น personal อัตโนมัติ และอาจเปลี่ยน business เป็น personal ระหว่าง Save | ผู้ใช้อาจไม่รู้ว่ามีการสร้างหรือเปลี่ยนข้อมูล | แสดงผลที่จะบันทึกและเหตุผลก่อนยืนยัน; ช่องว่างไม่เท่ากับหลักฐานว่าเป็น personal; ให้ตรวจทานและคง provenance |
| P1 | `logbook_progress_screen.dart` วาง hero ตามด้วยวง business-use และตัวเลขที่ซ้ำกัน | สถานะช่วงเวลา สัดส่วนธุรกิจ และเลขไมล์แข่งกันเด่น; เลื่อนมากก่อนถึงงานค้าง | แยก period progress ออกจาก business-use; ลด hero ซ้ำ |
| P1 | Hero ใช้ `taxSummary`; หน้า Progress ใช้ยอดเดียวกัน แต่แสดงร่วมกับสัปดาห์ logbook | ยังไม่เห็นการกรอง vehicle/period ที่ระดับ view; ผู้ใช้อาจเข้าใจ scope ผิด | trace calculation ก่อนแก้ และระบุรถ/ช่วงวันที่กำกับทุกสรุป |
| P1 | `Log Logbook Drive (TR 97/11)`, `Save Audit Record`, `lock in 5 years` | ภาษาเพิ่มภาระและอาจสร้างความคาดหวังเกินสถานะข้อมูล | ใช้ `Add trip`, `Save trip`, `Review logbook`; ให้ผู้เชี่ยวชาญตรวจข้อความรับรองและเงื่อนไขก่อนเผยแพร่ |
| P1 | Home เรียง annual reminder, hero, readiness, recent activity, money opportunity | ความสำคัญถูกกำหนดตาม component มากกว่าสถานการณ์ผู้ใช้ | ใช้ state-based priority และมีงานสำคัญที่สุดเพียงหนึ่งจุด |
| P1 | Manual entry เริ่ม purpose เป็น `Client / Job` และเติมที่อยู่ทั่วไปเมื่อว่าง | ข้อมูลที่ผู้ใช้ยังไม่ยืนยันอาจดูเหมือนข้อมูลจริง | แยก suggested กับ confirmed; ไม่สร้างสถานที่เสมือนเป็นหลักฐาน |
| P2 | ปุ่ม Settings หน้า Progress เป็น `onPressed: () {}` | กดแล้วไม่มีผล ลดความเชื่อถือ | เชื่อมปลายทางที่เหมาะสมหรือเอาออก |
| P2 | มี AppColor/AppColors และ raw type/spacing/radius ในหน้าที่ตรวจ | ระบบ token ที่มีอยู่ยังไม่ถูกใช้เป็นมาตรฐานเดียว | map token เดิมและรวม component เฉพาะ flow ที่ปรับ |

P0 ในเอกสารนี้หมายถึงความเสี่ยงด้านความเข้าใจและการควบคุมข้อมูล ไม่ใช่ข้อวินิจฉัยทางภาษีหรือหลักฐานว่าเกิดความเสียหายแล้ว

## Journey และพฤติกรรมที่ควรได้

| ช่วง | คำถามผู้ใช้ | หน้าจอและ primary action | สถานะที่ต้องออกแบบ |
|---|---|---|---|
| เริ่มต้น | ต้องทำอะไรเพื่อเริ่ม? | Setup: รถ → วันที่เริ่ม/สิ้นสุด → เลขไมล์เริ่ม → `Start logbook` | ไม่มีรถ, เลขไมล์ไม่ถูกต้อง, camera denied, ออกกลางทาง |
| พร้อมใช้งาน | แอปพร้อมบันทึกไหม? | Home: ช่วง logbook + tracking status; ถ้ายังไม่พร้อมให้ `Fix tracking` | พร้อม, permission ไม่พอ, Bluetooth ไม่พร้อม, offline, ยังไม่มีทริป |
| จบทริป | ทริปนี้ถูกต้องไหม? | Review: เส้นทาง/วันที่/ระยะทาง → Business/Personal → purpose → `Save trip` | ตรวจพบอัตโนมัติ, manual, หลักฐานไม่ครบ, ค่าที่ระบบเสนอ, save failed |
| ปิดวัน | ยังมีอะไรค้าง? | Home แสดง `Review 3 trips`; รายการเรียงตามเวลาพร้อมแก้และย้อนกลับ | ไม่มีงานค้าง, หลายทริป, เลขไมล์ไม่ต่อเนื่อง |
| ระหว่างช่วง | เหลืออีกเท่าไรและข้อมูลครบไหม? | Progress: วัน/ช่วงวันที่ → งานค้าง → business-use ของช่วงนี้ → odometer | เปลี่ยนรถ, ข้อมูลข้ามช่วง, มีช่องว่าง, ไม่มีการเดินทาง |
| จบช่วง | ต้องยืนยันอะไรอีก? | Review summary: เลขไมล์ปลายช่วงและรายการที่ยังขาด → `Review logbook` | เวลาครบแต่ข้อมูลไม่ครบ, ข้อมูลครบ, การแก้ข้อมูลที่ปิดช่วงแล้ว |
| ส่งให้นักบัญชี | ส่งอะไร ช่วงไหน และเปิดเผยอะไร? | Report preview: รถ/วันที่/เนื้อหา/ข้อมูลส่วนตัว → `Export report` | draft, มีคำเตือน, export failed, offline, สร้างสำเร็จ |

โครง navigation ระยะแรกคง Home / Trips / Expenses / Tax เพื่อรักษาความคุ้นเคย ให้ Progress เข้าจากสรุป Logbook บน Home และปุ่มเพิ่มแสดงตัวเลือกชัดเจน `Add trip`, `Scan receipt`, `Record odometer` จะเปลี่ยน navigation หลักต่อเมื่อ task testing ชี้ว่าจำเป็น

## โครงหน้าหลักที่เสนอ

1. Header สั้น: รถที่เลือกและช่วง logbook ปัจจุบัน
2. สรุปหลัก: `Week 4 of 12` พร้อมวันเริ่ม–สิ้นสุดและแถบเวลา; business-use เป็นข้อมูลรองพร้อมระบุว่าเป็นค่าของช่วงใด
3. Next action หนึ่งรายการ: แก้ tracking ก่อนถ้าบันทึกไม่ได้ จากนั้นหลักฐานสำคัญที่ขาด แล้วงาน review; เมื่อไม่มีงานค้างให้ข้อความยืนยันสั้น ๆ
4. Today: ทริปล่าสุดพร้อมสถานะ reviewed / needs review และทางเข้า Trips
5. Expenses และ report เป็นข้อมูลรองตามบริบท; annual reminder แสดงเมื่อถึงกำหนด; opportunity card อยู่ต่ำกว่างานหลัก

Progress bar แสดงเวลาเท่านั้น ไม่ใช้เปอร์เซ็นต์ business-use เป็นความสำเร็จ ไม่สื่อว่า business-use ยิ่งสูงยิ่งดี สถานะ `ครบเวลา`, `ข้อมูลครบ`, `พร้อมสร้างรายงาน` ต้องแยกกัน

## แนวภาพและ design system

ใช้ navy / ink / neutral จากระบบเดิม มี accent เท่าที่จำเป็น เน้นเลขที่มีหน่วยและ context ลดข้อความตัวหนาหนักทุกบรรทัด ลดกรอบซ้อน และใช้ list/divider สำหรับข้อมูลที่สัมพันธ์กัน รักษา white space โดยไม่ทำให้ต้องเลื่อนผ่านการ์ดขนาดใหญ่เพื่อทำงานประจำวัน

ตรวจ token จริงก่อนปรับ DESIGN.md; ใช้ spacing 4/8, gutter และ radius ที่มีอยู่; tabular figures สำหรับตัวเลข; type ผ่าน semantic roles ห้ามเพิ่ม raw style รายหน้าจอ กฎ skill ทั่วไปที่กำหนด section spacing ใหญ่หรือฟอนต์เพียงสี่ขนาดไม่แทนข้อกำหนด mobile และระบบเดิมของโปรเจกต์

Component ที่ควรรวม: `LogbookPeriodSummary`, `TrackingStatusRow`, `NextActionCard`, `TripReviewRow`, `OdometerField`, `EvidenceStatusRow`, `ReportReadinessSummary` แต่ละตัวต้องมี loading / empty / error / disabled / success ตามความจำเป็น สถานะใช้ข้อความและไอคอนร่วมกับสี

พื้นที่กดขั้นต่ำ 48dp, contrast AA, text scaling 200%, VoiceOver/TalkBack, reduced motion และ keyboard-safe CTA ต้องเป็น acceptance criteria การขยายข้อความใช้ reflow เป็นหลัก ไม่ย่อข้อความจนอ่านยากเพื่อให้ผ่าน overflow

## Benchmark ที่ใช้เป็นหลักคิด

Driversnote แยก track → classify → report และมี trip inbox สำหรับตรวจและแก้รายละเอียด จึงใช้เป็น benchmark เรื่องการแยกงานประจำวันกับการออกรายงาน ไม่ใช่หลักฐานว่า UX ของแอปนี้ด้อยกว่าจากการทดสอบเปรียบเทียบ:
- https://driversnote.helpscoutdocs.com/article/406-what-can-i-do-with-driversnote
- https://driversnote.helpscoutdocs.com/article/106-how-to-edit-a-trip
- https://driversnote.helpscoutdocs.com/article/54-creating-a-report

MileIQ แนะนำการจัดหมวดเป็นกิจวัตรและมี report flow แยก ใช้สนับสนุนแนว daily review และรายงานที่เข้าถึงได้ชัดเจน ไม่คัดลอก swipe interaction โดยไม่ทดสอบ:
- https://support.mileiq.com/hc/en-us/articles/203798909-Drive-classification-best-practices
- https://support.mileiq.com/hc/en-us/articles/203531259-How-to-create-a-Report

## ลำดับส่งมอบ

### ระยะ 1 — Baseline และ state contract
สร้าง capture harness ที่ใช้ source ปัจจุบันได้ โดยเก็บภาพชุดใหม่แยกจากของเก่า เดิน journey จริงและบันทึกจำนวนขั้นตอน/จุดลังเล ตรวจการเข้าถึงแต่ละหน้าจอ Trace vehicle/period scope และแหล่งสถานะ tracking/sync/review จัดทำ state matrix รวม no period, active, elapsed with issues, complete, archived

ผลส่งมอบ: baseline screenshots, journey map, issue list ที่ระบุ observed/inferred และ state contract ก่อนออกแบบข้อความสถานะ

### ระยะ 2 — Wireframe และ prototype
ออกแบบ Home, Setup, Trip Review, Progress, Close Period และ Report Preview ครบเส้นทางเดียวก่อน เพิ่ม empty/error/offline/permissions/gap states ทำ prototype ที่กดจบได้ แล้วออกแบบภาพละเอียดด้วย token เดิม

ผลส่งมอบ: flow + annotated screens + component/state specifications พร้อมขอบเขตข้อมูลที่ใช้ในแต่ละตัวเลข

### ระยะ 3 — ตรวจความเข้าใจกับผู้ใช้
ทดสอบเชิงคุณภาพกับกลุ่มเป้าหมายประมาณ 5 คน ครอบคลุมผู้ใช้ใหม่และคนที่เคยเก็บ logbook; ให้นักบัญชีตรวจ report preview แยก งานทดสอบ: เริ่ม logbook, บอกว่า tracking พร้อมหรือไม่, ตรวจทริป, แก้ช่องว่างเลขไมล์, ค้นงานค้าง, ส่งรายงาน ใช้ข้อมูลจำลองและวัด first attempt, เวลา, จุดผิดพลาด และความเข้าใจสถานะ

เป้าหมายเบื้องต้นที่ต้องปรับจาก baseline: อย่างน้อย 4/5 คนทำงานหลักสำเร็จโดยไม่ช่วย; review ทริปปกติไม่เกิน 3 actions หลังเปิดทริป; ไม่มีใครเข้าใจว่าเวลาเดินครบเท่ากับข้อมูลผ่านการตรวจ ตัวอย่างนี้ใช้ค้นปัญหา ไม่อ้างนัยสำคัญทางสถิติ

### ระยะ 4 — Implement ทีละ journey
ลำดับ: shared status/component → Home/Setup → Review/Entry → Progress/period closing → Report preview/export ใช้ service และข้อมูลเดิมเมื่อถูกต้อง แยกการเปลี่ยน domain behavior เช่น gap classification ออกเป็นงานที่ระบุผลต่อข้อมูลชัดเจน ไม่แต่ง UI ให้ซ่อนปัญหาด้านข้อมูล

### ระยะ 5 — Verification และ release readiness
ทดสอบ state transitions ที่มีความเสี่ยงจริง: permission revoked, save failed, offline, gap, wrong period/vehicle, export failure พร้อม before/after screenshots ที่ 360/390/430dp และ text 100/130/200% ตรวจ tap targets, semantics และ keyboard บนอุปกรณ์จริง รัน targeted Flutter tests และ analyze ตามไฟล์ที่แก้ แล้วจึง regression suite ตามข้อกำหนด repository

## Definition of done

- ผู้ใช้เห็นสถานะจริงและ next action ที่สอดคล้องกับปัญหา; ไม่มีปุ่มกดแล้วเงียบ
- เวลา, business-use, completeness และ export readiness สื่อความหมายคนละอย่างชัดเจน
- ไม่มีการเพิ่ม/เปลี่ยนหลักฐานหรือ classification โดยผู้ใช้ไม่เห็นผลที่จะเกิดขึ้น
- ตัวเลขสรุปทุกจุดมี vehicle/date scope ถูกต้องและตรวจย้อนกลับได้
- งานหลักทำครบจาก Setup ถึง Export ทั้ง happy path และ recovery path
- ผ่าน accessibility และ task checks พร้อมรายงานผลจริง ไม่ใช้ความสวยหรือจำนวน tests เป็นตัวแทนความเข้าใจของผู้ใช้
- รอบวางแผนนี้เปลี่ยนเฉพาะเอกสาร ไม่มีการแก้ UI, business logic, schema หรือข้อมูลผู้ใช้
