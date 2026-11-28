# KiloClaim Deep-Dive Specification: PDF & CSV Architecture for Australian Tax Accountants
**Classification:** Core Regulatory & Interface Architecture
**Target Domain:** Australian CPAs, Chartered Accountants (CA ANZ), Registered Tax Agents (TPB)
**Governing Legislation:** *ITAA 1997 Division 28 (Subdiv 28-C, 28-F, 28-G)*; *TR 2021/1*; *TR 97/11*; *ATO Practitioner Lodgment Service (PLS) DDCTNS Schema*

---

## 1. รู้เขา รู้เรา: ความเป็นจริงของสำนักงานบัญชีออสเตรเลีย (The Ground Truth)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    THE TAX AGENT EOFY COMPRESSION MATRIX                        │
│                                                                                 │
│  July - October: Tax Season Crunch • Average 300 - 800 Tradie Clients per Firm   │
│                                                                                 │
│  [Tradie Problem]                  [Accountant Pain]       [KiloClaim Solution]   │
│  Crumpled dockets in ute cabin ──► 2 hrs manual typing ──► Fast-Fill Pack (8 min)│
│  Vague "Work" trip entries     ──► Audit penalty risk  ──► Pre-flight ATO Checks│
│  Lost receipts upon phone swap ──► Disallowed deductions──► Cryptographic Index │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 โปรแกรมบัญชีที่นักบัญชีออสเตรเลียใช้จริง (Software Landscape)
นักบัญชีกว่า 95% ในออสเตรเลียส่งภาษีผ่านระบบ **ATO Practitioner Lodgment Service (PLS)** โดยใช้ซอฟต์แวร์ 4 ค่ายหลัก:
1. **The Access Group HandiTax (HandiSoft):** ครองส่วนแบ่ง ~40-45% ของสำนักงานบัญชีอิสระ (โดยเฉพาะกลุ่มที่รับทำภาษีให้ช่าง Tradies)
2. **Xero Tax (Xero Practice Manager):** เติบโตสูงมากในกลุ่มสำนักงานบัญชีรุ่นใหม่ Cloud-first (~30-35%)
3. **MYOB Practice Compliance:** กลุ่มบริษัทขนาดกลางและระดับภูมิภาค (~15-20%)
4. **Wolters Kluwer CCH iFirm:** กลุ่มสำนักงานบัญชีขนาดกลาง-ใหญ่

### 1.2 โครงสร้างแบบฟอร์มสรรพากรจริง (ATO PLS Schema: Item D1)
เมื่อนักบัญชีเปิดหน้าภาษีบุคคลธรรมดา (Individual Tax Return - IITR):
- **Item D1 (Label A):** Work-related car expenses
- **ตารางหลัก (Deductions Schedule):** รหัส **`DDCTNS`** (Tax Schedule Code: **`ds`**) ซึ่ง ATO บังคับส่งคู่กับแบบแสดงรายการ
- **ตารางคำนวณยานพาหนะ (Motor Vehicle Worksheet):** รหัส **`mve`** ใน HandiTax/MYOB หรือ **Motor Vehicle Expenses Worksheet** ใน Xero Tax
- **Method Code:**
  - รหัส **`C`** = Cents per kilometre (สูงสุดไม่เกิน 5,000 กม. ต่อคัน อัตรา FY24/25 = 85c/km, FY25/26 = 88c/km)
  - รหัส **`B`** = Logbook method (คำนวณตามสัดส่วนธุรกิจจริงจากการจด 12 สัปดาห์ต่อเนื่อง)

---

## 2. สิ่งที่นักบัญชี "เกลียด" ในแอปอื่น vs สิ่งที่ "ต้องการจริง" ใน KiloClaim

| มิติ | แอปทั่วไปในตลาด (Driversnote, MileIQ, myDeductions) | สิ่งที่นักบัญชีต้องการจริง (และ KiloClaim สร้าง) |
| :--- | :--- | :--- |
| **PDF Format** | ทำ PDF สรุปกราฟิกสีสัน แผนที่เส้นทาง และสรุปยอดเงินรวมก้อนเดียว | **Box D1 Fast-Fill Workpaper:** ไม่มีแผนที่ให้รกตา แต่จัดหมวดหมู่ค่าใช้จ่ายตรงตามรหัสบัญชีภาษี 401–406 พร้อมสรุปวิธีคำนวณและข้อจำกัด กรอกลง HandiTax/Xero ได้ใน 30 วินาที |
| **CSV Structure** | ทิ้งข้อมูล GPS ดิบ (Lat/Lng, วันที่, ระยะทาง) ไม่มีเลขไมล์หน้าปัดจริง | **ATO-Compliant Odometer Ledger:** มีเลขไมล์เริ่มต้น–สิ้นสุด (Start/End Odometer), วัตถุประสงค์งานที่เฉพาะเจาะจง, และรหัสทริปคงที่ (`TRIP-001`) |
| **Receipt Tracking** | รูปใบเสร็จหลุดลอย อยู่นอกตาราง หรือให้ลิงก์ Cloud ที่คลิกแล้วต้องขอรหัสผ่าน | **Cryptographic Receipt Index:** มีตาราง CSV ดัชนีผูกเลขค่าใช้จ่ายเข้ากับไฟล์รูปภาพจริงใน ZIP พร้อมแนบ SHA-256 Checksum ตรวจสอบการแก้ไข |
| **Data Provenance** | ไม่บอกว่าตัวเลขมาจากไหน ทำให้ผู้สอบบัญชีไม่กล้าเซ็นรับรอง | **Record Sources Ledger:** แยกชัดเจนว่าบรรทัดไหนมาจาก Telematics อัตโนมัติ บรรทัดไหนผู้ใช้พิมพ์มือ |
| **Incomplete Data** | ซ่อนจุดผิด หรือแอบเติมข้อมูลให้ดูเหมือนครบ | **Explicit Review Issues:** เปิดเผยรายการที่ยังไม่ระบุวัตถุประสงค์หรือยังไม่ยืนยันตรงไปตรงมา นักบัญชีไม่ต้องเสียเวลาไล่หา |
| **Account Access** | บังคับให้นักบัญชีต้องสมัคร Account ในเว็บของแอปเพื่อเข้าไปดาวน์โหลด | **Zero-Friction Offline ZIP:** ไฟล์ ZIP มาตรฐานที่แตกไฟล์ออกมาเปิดบนคอมพิวเตอร์ได้ทันที 100% Offline ไม่ต้องสมัครสมาชิก |

---

## 3. สเปกไส้ในของชุดส่งออก KiloClaim (The Enterprise Export Specification)

ชุดส่งออกสร้างเป็น ZIP ก้อนเดียว: `KiloClaim_EOFY_Pack_FY[YYYY]_[REGO].zip` ประกอบด้วยไฟล์เนื้อเน้นๆ 6 รายการ:

```
KiloClaim_EOFY_Pack_FY2025_2026_TRADIE_01.zip
├── 01_Executive_Tax_Workpaper.pdf         <-- เอกสารสรุป Box D1 Fast-Fill สำหรับกรอก HandiTax / Xero
├── 02_HandiTax_D1_Schedule.csv            <-- ตารางตัวเลข 6 หมวดหลัก แมปเข้า Worksheet mve
├── 03_Continuous_Odometer_Ledger.csv      <-- ตารางเลขไมล์ 12 สัปดาห์ต่อเนื่อง (ITAA 1997 s28-125)
├── 04_Cryptographic_Receipt_Index.csv     <-- ดัชนีผูกรายการค่าใช้จ่ายกับรูปใบเสร็จ + SHA-256
├── 05_Record_Provenance.csv               <-- ที่มาของหลักฐาน (Telematics vs Manual Entry)
├── 06_Review_Exceptions_Log.csv           <-- รายการข้อมูลที่ยังไม่ระบุ/รอการตรวจสอบ
└── receipts/                              <-- โฟลเดอร์รวมรูปถ่ายใบเสร็จจริง (WebP/JPEG)
    ├── receipt-000001.webp
    └── receipt-000002.webp
```

---

## 4. โครงสร้างข้อมูลระดับฟิลด์ (Field-Level Specifications)

### 4.1 ไฟล์ `01_Executive_Tax_Workpaper.pdf` (เอกสารหน้าเดียวจบ)
ออกแบบตามมาตรฐาน **CPA / CA ANZ Audit Workpaper Layout**:
- **Header:** ชื่อผู้เสียภาษี, เลขประจำตัวผู้เสียภาษี (ABN/TFN Masked), ทะเบียนรถ, ยี่ห้อ/รุ่น, ปีภาษี
- **Section A: Method Arbitrage Verdict:**
  - เปรียบเทียบตัวเลข: วิธี CPK (สูงสุด 5,000 km) ได้เงินเคลมเท่าไหร่ vs วิธี Logbook ได้เงินเคลมเท่าไหร่
  - ระบุเหตุผลเชิงกฎหมายที่เลือกใช้วิธีนั้น (เช่น *"Logbook yields \$4,850 higher deduction than CPK 5,000 km cap"*)
- **Section B: Fast-Fill Box สำหรับกรอก Form D1:**
  - **D1 Method Code:** `[ B ]` (Logbook) หรือ `[ C ]` (Cents per km)
  - **Business Percentage:** `85.40%`
  - **Code 401 (Fuel & Oil):** Gross $\to$ Apportioned Claim
  - **Code 402 (Repairs & Tyres):** Gross $\to$ Apportioned Claim
  - **Code 403 (Rego & Insurance):** Gross $\to$ Apportioned Claim
  - **Code 404 (Car Loan / Lease Interest):** Gross $\to$ Apportioned Claim
  - **Code 405 (Div 40 Depreciation):** Gross (คำนึงถึง Car Cost Limit \$69,674) $\to$ Apportioned Claim
  - **Code 406 (Direct Tolls & Work Parking):** 100% Direct Claim
- **Section C: 3-State Substantiation Checklist:**
  - จำนวนใบเสร็จที่มีไฟล์แนบ / จำนวนที่เปิดอ่านได้ / จำนวนที่ช่างรับรองยอด ABN/GST แล้ว
- **Section D: Statutory Compliance & Bulky Tools Attestation:**
  - ระบุคำรับรองข้อยกเว้นขนอุปกรณ์หนัก (*Vogt 75 ATC 4073 & TR 95/34*) พร้อมลายเซ็นกำกับ

---

### 4.2 ไฟล์ `02_HandiTax_D1_Schedule.csv` (ตารางแมปเข้า HandiTax / Xero)
```csv
Tax_Year,Client_Name,ABN,Vehicle_Rego,Vehicle_Model,Item_Label,ATO_Schedule_Code,Schedule_Name,Gross_AUD,Business_Percent,Claim_AUD,Statutory_Authority
2025-2026,Dave Miller,51 824 753 556,TRADIE-01,2023 Toyota Hilux,D1A,METHOD,Logbook Method,0.00,85.40,0.00,ITAA 1997 Subdiv 28-F
2025-2026,Dave Miller,51 824 753 556,TRADIE-01,2023 Toyota Hilux,D1B,401,Fuel and Oil,4250.00,85.40,3629.50,TR 97/11 Par 18
2025-2026,Dave Miller,51 824 753 556,TRADIE-01,2023 Toyota Hilux,D1B,402,Service Repairs & Tyres,1850.00,85.40,1579.90,TR 97/11 Par 18
2025-2026,Dave Miller,51 824 753 556,TRADIE-01,2023 Toyota Hilux,D1B,403,Registration & Insurance,2400.00,85.40,2049.60,TR 97/11 Par 18
2025-2026,Dave Miller,51 824 753 556,TRADIE-01,2023 Toyota Hilux,D1B,404,Interest on Vehicle Loan,950.00,85.40,811.30,ITAA 1997 s 8-1
2025-2026,Dave Miller,51 824 753 556,TRADIE-01,2023 Toyota Hilux,D1B,405,Decline in Value (Div 40),17418.50,85.40,14875.40,ITAA 1997 s 40-230
2025-2026,Dave Miller,51 824 753 556,TRADIE-01,2023 Toyota Hilux,D1B,406,Work Tolls & Parking,580.00,100.00,580.00,ITAA 1997 s 8-1
```

---

### 4.3 ไฟล์ `03_Continuous_Odometer_Ledger.csv` (สมุดบันทึกการเดินทางตามกฎหมาย)
ฟิลด์บังคับตามกฎหมาย *ITAA 1997 Section 28-125*:
- `Entry_Number`: ลำดับที่ต่อเนื่อง
- `Date`: รูปแบบ DD/MM/YYYY (ห้ามใช้วันที่แบบสหรัฐอเมริกา MM/DD/YYYY เด็ดขาด เพื่อป้องกันความสับสน)
- `Start_Odometer`: เลขไมล์เริ่มต้นของเที่ยว
- `End_Odometer`: เลขไมล์สิ้นสุดของเที่ยว
- `Distance_KM`: ระยะทางจริง
- `Classification`: `BUSINESS` หรือ `[Private Journey]` (ซ่อนที่อยู่และวัตถุประสงค์เพื่อความเป็นส่วนตัวตาม Privacy Act 1988)
- `Origin`: ต้นทางจริง (หากไม่มี แสดง `[Unspecified Origin]`)
- `Destination`: ปลายทางจริง (หากไม่มี แสดง `[Unspecified Destination]`)
- `Business_Purpose`: วัตถุประสงค์งานที่เฉพาะเจาะจง (เช่น *"Emergency pipe repair at 14 Smith St - Job #1094"*)
- `Bulky_Tools_Carried`: `YES` / `NO` (ระบุการคุ้มครองตามคำพิพากษาคดี *Vogt 75 ATC 4073*)
- `Statutory_12Wk_Period`: `IN_PERIOD` หรือ `POST_PERIOD`
- `Running_Cumulative_Biz_KM` & `Running_Biz_Percent`

---

### 4.4 ไฟล์ `04_Cryptographic_Receipt_Index.csv` (ดัชนีใบเสร็จที่อ้างอิงกลับได้จริง)
```csv
Expense_ID,Date,Merchant,Merchant_ABN,Category,Gross_AUD,GST_AUD,Tax_Invoice_Valid,Receipt_Filename,File_SHA256_Checksum,User_Verified_Status,Linked_Trip_Ref
EXP-001,12/11/2025,BP Alexandria,59 008 459 407,Fuel,142.50,12.95,YES,receipts/receipt-000001.webp,a8f5c9e2b0123...4d90,CONFIRMED,TRIP-042
EXP-002,18/11/2025,Bridgestone Select,81 007 530 098,MaintenanceTyres,880.00,80.00,YES,receipts/receipt-000002.webp,c30248ad65789...11fe,CONFIRMED,TRIP-058
```

---

## 5. ผลกระทบเชิงธุรกิจ: การสร้าง "Accountant Flywheel"

เมื่อนักบัญชีได้รับไฟล์ของ KiloClaim เทียบกับแอปอื่น:
1. **เวลาที่ใช้ทำภาษีลดลง 90%:** จากเดิมที่ต้องแกะบิลค่าน้ำมัน 40-50 ใบและคำนวณไมล์ 2 ชั่วโมง เหลือเพียงเปิด `01_Executive_Tax_Workpaper.pdf` แล้วหยอดตัวเลขลงช่อง D1 ใน 30 วินาที
2. **ความเสี่ยงทางกฎหมายเป็นศูนย์:** มีดัชนี SHA-256 และการแจกแจงที่มา หากสรรพากร ATO ส่งจดหมายสุ่มตรวจ (Audit Query) นักบัญชีแค่หยิบ ZIP ก้อนนี้แนบตอบกลับ ATO ได้ทันที
3. **กลายเป็นช่องทางการจัดจำหน่ายหลัก (Distribution Moat):** สำนักงานบัญชีจะออกปากบอกลูกค้าที่เป็นช่างทุกคนว่า:
   *"คุณ Dave ปีหน้าคุณเลิกเก็บใบเสร็จใส่กล่องรองเท้า แล้วไปโหลดแอป KiloClaim ซะ ไม่งั้นผมต้องคิดค่าเสียเวลาจัดเอกสารเพิ่ม \$300"*
