# Adversarial Falsification Catalog (ATO Tax & Tradie Edge Cases)

## Purpose
This catalog serves as an attack reference for the EDE Adversarial Auditor. When tasked with auditing code, auditors should test the implementation against these known critical domain failure modes.

---

## 1. Statutory ATO & ITAA 1997 Division 28
1. **Multi-Vehicle CPK Boundary:**
   - *Attack:* A sole trader uses 2 vehicles in the same tax year (4,000 km and 3,000 km).
   - *Invariant:* The 5,000 km cap applies **per vehicle**, NOT across the taxpayer. Total claim = 7,000 km $\times$ rate.
2. **Opening/Closing Odometer Reconciler:**
   - *Attack:* Odometer skips a span (e.g. 100,000 km to 100,450 km with no tracked trip).
   - *Invariant:* The reconciler must NEVER invent synthetic business trips or alter baseline historical odometers.
3. **TR 2021/1 Home-to-Work Travel:**
   - *Attack:* Claiming travel from home base to standard workplace without carrying bulky trade equipment.
   - *Invariant:* Must be categorized as Private/Non-deductible unless the vehicle is an exempt commercial utility ($>1,000$ kg payload).

---

## 2. Spatio-Temporal & Evidence Matching
4. **Bunnings / Trade Supplier Proximity Drift:**
   - *Attack:* Receipt timestamp matches a trade stop, but GPS was 2 km away due to cellular tower triangulation delay.
   - *Invariant:* Spatio-temporal match must require both spatial radius ($\le 300$ m) and temporal window ($\le 2$ hours), with confidence decay.
5. **Bidirectional Immutability:**
   - *Attack:* Deleting an expense clears `trip.linkedExpenseIds` but leaves orphan `expense.linkedTripId`.
   - *Invariant:* Mutual referential integrity must be atomic.

---

## 3. Data Integrity & Adversarial Payloads
6. **XML Special Characters in Accountant Handoff:**
   - *Attack:* Trader business name or invoice includes `&`, `<`, `>`, `"`, `'`, or emoji.
   - *Invariant:* OpenXML Excel generator and PDF export must sanitize or escape properly without XML parse crash.
7. **Negative or Zero Values:**
   - *Attack:* Negative trip distance, zero fuel cost, or null GST.
   - *Invariant:* Never divide by zero; fallback cleanly to statutory defaults.
