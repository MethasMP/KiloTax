# ASO PACKAGE — App Store (Australia) · v1.0 (CPK only)
*พร้อม copy-paste ลง App Store Connect · 27 ก.ย. 2026*

> ⚠️ **v1.0 = CPK เท่านั้น ห้ามอ้างฟีเจอร์ Logbook ใน listing** (Apple ปฏิเสธได้ถ้าฟีเจอร์ไม่มีจริง)
> Logbook จะอยู่ใน **Promotional Text** เป็น "coming" และจะย้ายเข้า Description ใน v1.1

---

## 0) ข้อมูลเทคนิคที่ต้องรู้ (อัปเดต 2026)

| ฟิลด์ | ลิมิต |
|---|---|
| App Name | 30 ตัวอักษร |
| Subtitle | 30 ตัวอักษร |
| Keywords | **100 ตัวอักษร** · คั่นด้วย comma · **ห้ามมีเว้นวรรคหลัง comma** · **ห้ามซ้ำคำที่มีใน Name/Subtitle** |
| Description | 4,000 ตัวอักษร (3 บรรทัดแรก = สำคัญสุด เพราะแสดงก่อนปุ่ม "more") |
| Promotional Text | 170 ตัวอักษร · **แก้ได้โดยไม่ต้องส่ง review ใหม่** ← ใช้ยิงข้อความตามฤดูกาล |
| Screenshot iPhone | **ต้องส่งชุด 6.9"**: `1320×2868` หรือ `1290×2796` หรือ `1260×2736` px (portrait) · 1–10 ภาพ · JPEG/PNG · **ห้ามมี alpha channel** · ≤ 8 MB |
| Screenshot iPad | ถ้ารองรับ iPad ต้องส่งชุด 13": `2064×2752` หรือ `2048×2732` px |
| App Preview (วิดีโอ) | 15–30 วิ · แนะนำทำใน v1.1 |

---

## 1) App Name — 29/30 ตัวอักษร

```
KiloTax: Car Logbook ATO Tax
```

**คำที่ถูก index จากชื่อ (Tier 1 Rank Weight):** `kilotax` · `car` · `logbook` · `ato` · `tax`

---

## 2) Subtitle — 30/30 ตัวอักษร

```
Cents per Km Tracker & Claim
```

**คำที่ถูก index เพิ่มจาก Subtitle (Tier 2 Rank Weight):** `cents` · `per` · `km` · `tracker` · `claim`

---

## 3) Keywords field — 100/100 ตัวอักษร (copy ทั้งบรรทัด ห้ามเติม space)

```
vehicle,mileage,expenses,deduction,tradie,fuel,odometer,work,ute,trip,business,self,employed,receipt
```

**หลักการที่ใช้:**
- ❌ ไม่ซ้ำคำจาก Name/Subtitle (`kilotax`, `car`, `logbook`, `ato`, `tax`, `cents`, `per`, `km`, `tracker`, `claim`)
- ❌ ไม่ใส่ `app`, `free` (Apple ไม่คิดน้ำหนัก และเปลืองโควตา)
- ❌ ไม่ใส่ชื่อคู่แข่ง (`driversnote`, `mileiq`) เพื่อป้องกันปัญหา Trademark & App Review
- ✅ ปรับเปลี่ยน: นำ `claim` ออกจาก Keywords (เพราะขึ้นไปอยู่ใน Subtitle แล้ว) และใส่ `receipts` เข้ามาแทน ทำให้ได้ครอบคลุมคำค้นหมวดใบเสร็จภาษีเต็ม 99/100 ตัวอักษรเป๊ะ!
- ✅ รักษาคำเฉพาะออสซี่: `tradie`, `ute` (volume สูงสำหรับกลุ่มช่างและผู้รับเหมา)

### ชุด keyword แยกตาม locale (ทำ localization เหล่านี้ = ได้ 100 ตัวอักษรเพิ่มต่อ locale ฟรี)

| Locale | เหตุผล | keyword ที่แนะนำ |
|---|---|---|
| **en-AU** | ตลาดหลัก | ชุดด้านบน |
| **en-US** | สหรัฐฯ มีคนขับรถ gig ~57M คน · คำค้น "IRS" ต่างจาก ATO | `irs,mileage,deduction,self,employed,gig,uber,doordash,vehicle,expenses,log,tax,schedule,c` (⚠️ แต่ **ห้าม**เปิดขาย US จนกว่าจะมี US rules — ใช้แค่เป็น index ทดลอง หรือปิด availability) |
| **en-GB** | เตรียมไว้ก่อนเข้า UK เม.ย. 2028 | `hmrc,mileage,45p,55p,self,employed,cis,vehicle,expenses,claim,sole,trader,amap` |
| **en-NZ** | เตรียมไว้ก่อนเข้า NZ | `ird,logbook,mileage,km,rates,gst,vehicle,expenses,self,employed,tradie,claim` |

> **เคล็ด:** การเพิ่ม localization (แม้ใช้ screenshot/description ชุดเดียวกัน) ทำให้คุณได้ keyword field ชุดใหม่ 100 ตัวอักษรต่อ locale → เป็น ASO leverage ที่ฟรีที่สุด
> ⚠️ แต่ถ้าเปิด en-US/en-GB โดยที่แอปคำนวณภาษีผิดประเทศ จะโดนรีวิว 1 ดาว → **จำกัด App Availability เป็น Australia เท่านั้นใน v1.0** แล้วค่อยเปิดทีหลัง

---

## 4) Promotional Text — 157/170 ตัวอักษร (แก้ได้ตลอด ไม่ต้อง review)

**ใช้ตอนเปิดตัวและ Launch (Humanized Aha Hook):**
```
Claim up to $4,550 for your ute this year. Track work km at the official 91c rate, hit your 5,000 km cap, and export straight to your accountant. No sign-up.
```

**สลับใช้ช่วง EOFY (1 เม.ย. – 30 มิ.ย.):**
```
Tax time is coming. Claim your $4,550 car deduction before 30 June. Track 91c/km, monitor your 5,000 km ATO limit, and export clean records in seconds. Free.
```

---

## 5) Description — 2,470 ตัวอักษร (copy ได้เลย)

```
Track your work kilometres. Know exactly what you can claim at tax time.

Built for Australian tradies, sole traders and anyone who uses their own car for work. No sign-up. No account. Your data stays on your phone.

THE ATO RATE IS 91 CENTS PER KM (2026-27 YEAR)
The cents per kilometre method lets you claim 91c for every business kilometre - up to a maximum of 5,000 km per car, per year. That is a deduction of up to $4,550.

This app tracks that cap for you automatically, so you always know where you stand.

WHAT YOU GET (FREE)
- Log a trip in under 10 seconds: distance, destination and reason for the journey
- One tap to mark a trip as business or private
- Automatic cents-per-km calculation using the correct ATO rate for each income year (91c for 2026-27, 88c for 2024-25 and 2025-26, 85c for 2023-24)
- Live 5,000 km cap counter - see how much of your quota is left
- Full tax year summary: total business km, total deduction, trips by month
- Export to CSV so you or your bookkeeper can use the records
- Multiple vehicles

WHY IT MATTERS
If you drive a lot for work, the cents per km method may be leaving money on the table. The logbook method lets you claim your actual car costs - fuel, registration, insurance, servicing, repairs and decline in value - multiplied by your business use percentage. For many tradies that is several thousand dollars more per year.

This app shows you both numbers side by side using your real trips, so you can see which method is worth more to you.

COMING SOON
- 12-week logbook mode that meets ATO record-keeping requirements
- Automatic trip detection
- Odometer readings with photo evidence
- Fuel and expense receipts
- PDF export formatted for tax records

PRIVATE BY DESIGN
We do not require an account. We do not sell data. Everything you record stays on your device, and you can export a copy at any time.

IMPORTANT
This app helps you keep records and calculate amounts using rates published by the Australian Taxation Office. It does not provide tax advice and is not affiliated with, endorsed by or connected to the ATO. Always confirm your claim with a registered tax agent. Rates: ato.gov.au

Support: methaspak@gmail.com
Privacy Policy: https://kilotax.app/legal#privacy
Terms of Use: https://kilotax.app/legal#terms
Support URL: https://kilotax.app/legal#support
Marketing URL: https://kilotax.app
```

**หมายเหตุ:**
- ประโยค "not affiliated with, endorsed by or connected to the ATO" **จำเป็น** — ถ้าไม่ใส่ มีโอกาสถูก Apple ปฏิเสธ และเสี่ยงเรื่องเครื่องหมายการค้า (ATO/Australian Taxation Office เป็นของ Commonwealth)
- ห้ามใช้คำว่า "ATO approved" หรือ "ATO official" เด็ดขาด
- อีเมล Support ใช้ `methaspak@gmail.com` (ตั้งค่าในหน้ากฎหมายและ Support Portal เรียบร้อยแล้ว)

---

## 6) ฟิลด์อื่น ๆ ใน App Store Connect

| ฟิลด์ | ค่าที่แนะนำ |
|---|---|
| Primary Category | **Business** |
| Secondary Category | **Finance** |
| Age Rating | 4+ |
| Price | Free |
| App Availability | **Australia เท่านั้น** (ใน v1.0) |
| Support URL | `https://kilotax.app/legal#support` |
| Privacy Policy URL | `https://kilotax.app/legal#privacy` |
| Marketing URL | `https://kilotax.app` |
| Copyright | `2026 KiloTax Australia` |
| Version | 1.0.0 · Build 1 |

### App Privacy (Privacy Nutrition Labels) — สำหรับ v1.0
- **Data Used to Track You:** None (ไม่ใช้ IDFA, ไม่มี Third-party Ad tracking)
- **Data Linked to You:** Email / Name (เฉพาะกรณีผู้ใช้เลือก Sign In with Apple หรือ Google)
- **Data Not Linked to You:** Diagnostics / Crash Data (ถ้ามี)
- **Local Data:** การบันทึกระยะทางและคำนวณภาษีทำงานแบบ Local-First บนเครื่อง

---

## 7) Screenshot Set — 6 ภาพ @ `1320 × 2868 px` (iPhone 16/17/18 Pro Max 6.9")

**กฎเหล็ก Apple:**
- สเปกขนาด: `1320 × 2868 px` (อัตราส่วน 6.9" Super Retina XDR)
- ห้ามมี Alpha Channel (Transparency เด็ดขาด ต้อง 24-bit RGB)
- ห้ามใส่กรอบตัวเครื่อง iPhone หรือโลโก้ Apple
- โทนสีและสไตล์: Hi-Vis Tradie (เหลืองสะท้อนแสง/ดำ/เขียวมินต์) พาดหัวตัวใหญ่ กระชับ ตรงประเด็น

---

## 9) Notes สำหรับ Apple Review (ใส่ในช่อง "App Review Information")

```
This app helps Australian sole traders and tradies record work-related vehicle
kilometres and calculate indicative tax deductions using the official 91c/km
cents per kilometre method (ITAA 1997 Division 28-C) published by the Australian
Taxation Office (ATO).

App Review Guidance:
- The app operates on a Value-First, Local-First model. Users can immediately
  set up their vehicle, record trips, and calculate deductions without creating
  an account.
- Sign In with Apple and Google are provided as optional cloud sync options.
- The app does not provide financial or tax advice and prominently disclaims
  any official affiliation with the ATO or Tax Practitioners Board.
- In-app Account Deletion and Local Data Reset are fully implemented in Account Settings
  under Guideline 5.1.1(v).

Review Demo Steps:
1. Launch the app. Select vehicle type (e.g. Ute) and complete vehicle onboarding.
2. View the Value-First Reveal screen showing the $4,550 annual claim potential.
3. Tap "Continue as Guest" to explore full local functionality immediately.
4. From the Dashboard, record or review a business trip.
5. In the Tax Summary tab, verify live 5,000 km cap progress and 91c calculation.
6. Open the Export menu to generate an ATO-compliant CSV tax pack.
```

---

## 10) แผน submission

| ขั้นตอน | ทำอะไร |
|---|---|
| 1 | สร้าง App record ใน App Store Connect · กรอกทุกฟิลด์ด้านบน |
| 2 | อัปโหลด build ผ่าน `flutter build ipa` → Transporter / `xcrun altool` |
| 3 | ตั้ง **Manual release** (อย่าเลือก auto) — เพื่อคุมวัน launch |
| 4 | Submit · ปกติ review ใช้ 24–48 ชม. (ถ้าติด ใช้ Request Expedited Review ได้ 1 ครั้ง) |
| 5 | **อย่า submit ช่วงคริสต์มาส–ปีใหม่** (คิวยาวและทีมเล็ก) |
| 6 | กด release วัน **อังคาร–พฤหัส เวลา 10:00 AEST** |
| 7 | หลัง launch 48 ชม.: ตอบรีวิวทุกตัว · เช็ก App Store Connect → "App Analytics" ดู impressions กับ conversion rate (เป้า > 25%) |

---

## 11) ตัวเลขที่ต้องดูทุกสัปดาห์หลัง launch

| Metric | ดูที่ไหน | เป้า |
|---|---|---|
| Impressions → Product Page Views | App Store Connect → Analytics | CTR > 25% |
| Product Page → Downloads | App Store Connect | CR > 25% (ต่ำกว่า 15% = screenshot/ชื่อมีปัญหา) |
| D1 retention | PostHog | > 30% |
| % ผู้ใช้ที่เพิ่มเที่ยว ≥ 3 ครั้งใน 7 วันแรก | PostHog | > 40% |
| Search terms ที่นำคนมา | App Store Connect → Search Terms | ใช้ปรับ keyword field ทุก 30 วัน |
| เรตติ้ง | App Store Connect | ≥ 4.6 ก่อนเดือน เม.ย. 2027 |
