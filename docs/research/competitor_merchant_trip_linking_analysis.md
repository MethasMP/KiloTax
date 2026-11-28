# Competitive Research: How Market Leaders Handle Merchants & Trip-to-Receipt Linking

Based on the strategic competitive document for KiloClaim (analyzing Driversnote, GOFAR, ATO myDeductions, MileIQ, CarSavvy, Hnry, Dext, and Rounded) and market evidence across Australia.

---

## 1. The Core Insight: Nobody "Bears It All Alone"

In the Australian market, apps that generate real revenue and scale do **NOT** build a proprietary nationwide geofence database of all merchants, nor do they try to create an end-to-end autonomous OCR engine alone. Instead, they leverage existing ecosystems, user habits, and bank integrations:

### Competitor Breakdown:

| App / Platform | How they solve "Merchant & ABN" (Item 1) | How they solve "Trip-to-Expense Linking" (Item 2) | Monetization / Business Model |
| :--- | :--- | :--- | :--- |
| **ATO myDeductions (Free Gov Tool)** | **Manual + Local Phone Memory:** User selects merchant from previous entries or types it once; camera captures receipt image for tax time. | **Completely Unlinked:** Keeps Trips and Expenses in separate buckets. It leaves the mental linking to the taxpayer at tax return time. | Free (Sets the baseline of "what people won't pay for"). |
| **Driversnote (AU Pro ~A$17/mo)** | **No Receipt OCR focus:** Focuses strictly on vehicle mileage, auto-start iBeacon, and IRS/ATO logbook compliance. | **Trip Purpose & Notes:** Users tag trips (e.g., "Bunnings run", "Site inspection"). Does not do receipt OCR matching. | High margin subscription via friction-free trip tracking. |
| **Dext (formerly Receipt Bank) & Hubdoc** | **Third-party OCR API (ABBYY/AWS) + Crowd/HITL Verification + Bank Feeds:** They match receipt amount and date against Bank Transactions (Open Banking / Xero feed). | **Accounting Ledger Linking:** They don't track GPS trips. They link the receipt to the Bank Account Statement. | B2B SaaS sold directly to Accountants & Bookkeepers. |
| **Hnry (1% of income, capped at $1,500/yr)** | **Human-in-the-Loop (Accountant Review) + Card Payments:** Tradies get an automated tax account; receipts uploaded are reviewed by actual accountants or matched with bank transactions. | **Claim Reconciliation:** Trips are logged as expense deductions alongside receipts. | Complete Tax Service (Accountant + Software in one). |
| **CarSavvy (Budget AU Tracker ~A$5/mo)** | **Native OS Places API (Google / Apple Places):** Auto-suggests nearby places when a trip ends using Google Places autocomplete. | **Trip-Centric Attachments:** Allows attaching a photo of a receipt directly onto a specific trip record. | Low-cost utility subscription. |
| **Rounded & Quickbooks Self-Employed** | **Bank Feed Rules:** If transaction says "Bunnings Alexandria", the rule automatically sets Merchant = Bunnings and Category = Materials. | **Date & Amount Matching:** Match receipt date with the bank feed transaction date. | Monthly SaaS for freelancers/sole traders. |

---

## 2. Why Trying to "Bear It All Alone" is a Trap for KiloClaim

1. **Merchant Geofencing is a Commoditized Wheel:**
   - Apple Maps and Google Places already have every Bunnings, Mitre 10, BP, and local cafe mapped, updated, and geocoded with millimeter accuracy.
   - If we try to curate and maintain our own geofence database, we become an unpaid mapping company.
2. **Accountants don't care about GPS timestamps; they care about Substantiation:**
   - As emphasized in the founder doc: *"สนามแรกที่เลือก: tradie ที่มีนักบัญชีอยู่แล้ว"* (The first battleground: Tradies who already have an accountant).
   - An accountant only needs:
     1. Tax Invoice with valid ABN
     2. Deductible business percentage / trip correlation (Logbook rule)
     3. Exclusion of private convenience items (Coke, snacks)
3. **The "Bank Feed / Open Banking" Anchor:**
   - The reason Dext and Hnry can be confident about merchants without complex geofencing is that **the credit card transaction already has the clean merchant name**.
