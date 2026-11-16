# Adversarial Falsification Catalog & Auditor Personas (EDE v3.0)

## Purpose
This catalog defines the attack vectors and specialized auditor personas for EDE.
Under EDE v3.0, audits are executed using distinct adversarial roles to eliminate cross-model blind spots.

---

## 1. Adversarial Auditor Personas (Persona Injection)

| Persona / Role | Focus Area | Mindset |
| :--- | :--- | :--- |
| **`tax-lawyer`** | ATO Legislation, ITAA 1997 Div 28, TR 2021/1 | *"Will the ATO audit office reject this deduction or find a statutory conflict?"* |
| **`cso`** | Security, Data Exfiltration, PII, Auth, RLS | *"Can malicious input hijack the tenant, leak receipt coordinates, or alter history?"* |
| **`edge-breaker`** | Numeric boundaries, Zero/Negatives, Spatio-Temporal, Clocks | *"What happens at 23:59:59 on June 30 during daylight savings transition?"* |
| **`concurrency`** | Race conditions, SQLite write-locks, offline sync conflict | *"What happens when 2 background GPS pings write simultaneously during poor cell reception?"* |

---

## 2. Statutory ATO & ITAA 1997 Division 28 Catalog
1. **Multi-Vehicle CPK Boundary:**
   - *Attack:* A sole trader uses 2 vehicles in the same tax year (4,000 km and 3,000 km).
   - *Invariant:* The 5,000 km cap applies **per vehicle**, NOT across the taxpayer. Total claim = 7,000 km $\times$ rate.
2. **Opening/Closing Odometer Reconciler:**
   - *Attack:* Odometer skips a span (e.g. 100,000 km to 100,450 km with no tracked trip).
   - *Invariant:* The reconciler must NEVER invent synthetic business trips or alter baseline historical odometers.
3. **TR 2021/1 Home-to-Work Travel:**
   - *Attack:* Claiming travel from home base to standard workplace without carrying bulky trade equipment.
   - *Invariant:* Must be categorized as Private/Non-deductible unless the vehicle is an exempt commercial utility ($>1,000$ kg payload) or meets genuine bulky equipment transit rules.
4. **Logbook 12-Week Rolling Rule:**
   - *Attack:* A 12-week logbook established in 2021 being applied past the 5-year expiration or after a $>10\%$ business use pattern shift.
   - *Invariant:* Must flag logbook expiration and require re-establishment when pattern materially changes.

---

## 3. Spatio-Temporal & Evidence Matching Catalog
5. **Bunnings / Trade Supplier Proximity Drift:**
   - *Attack:* Receipt timestamp matches a trade stop, but GPS was 2 km away due to cellular tower triangulation delay.
   - *Invariant:* Spatio-temporal match must require both spatial radius ($\le 300$ m) and temporal window ($\le 2$ hours), with confidence decay.
6. **Bidirectional Immutability:**
   - *Attack:* Deleting an expense clears `trip.linkedExpenseIds` but leaves orphan `expense.linkedTripId`.
   - *Invariant:* Mutual referential integrity must be atomic and reversible.

---

## 4. Data Integrity & Adversarial Payloads
7. **XML/CSV Special Characters in Accountant Handoff:**
   - *Attack:* Trader business name, job site or invoice includes `&`, `<`, `>`, `"`, `'`, commas, newlines, or emoji.
   - *Invariant:* OpenXML Excel generator and CSV export must sanitize or escape properly without XML parse crash or CSV formula injection (`=cmd|' /C...`).
8. **Negative, Null or NaN Floating-point Arithmetic:**
   - *Attack:* Negative trip distance, zero fuel cost, null GST, or division by zero in fuel economy ($L/100km$).
   - *Invariant:* Never divide by zero; fallback cleanly to statutory defaults.
