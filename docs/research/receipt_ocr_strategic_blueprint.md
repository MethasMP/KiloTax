# KiloClaim Receipt OCR Architecture & Strategic Blueprint

## Executive Summary
Generic OCR solutions (Google ML Kit, Apple Vision, Tesseract, standard PaddleOCR) are trained for general-purpose line-by-line reading. However, when applied to **Australian Tax Invoices / Receipts (ATO Compliance)**, they fail under predictable real-world conditions:
1. **Faded Thermal Paper:** Sun exposure on ute dashboards bleaches ink, resulting in character confusion (`0` <-> `O`, `8` <-> `B`, `1` <-> `I`/`l`).
2. **Multi-Column Drift:** Line-by-line bounding boxes separate merchant descriptions from amounts on the far right edge.
3. **ABN & GST Checksum Failures:** Generic engines do not know ATO Modulus-89 or the $11 \times \text{GST} = \text{Total}$ statutory invariant.

To solve this, KiloClaim adopts a **Two-Phase Architecture** mimicking the success of OpenThai OCR:

---

## Phase 1: Deterministic Domain-Repair Layer (Completed & Deployed in App)
Instead of relying solely on the raw OCR string, we enforce **ATO Invariant Rules** inside `AustralianTaxValidator` and `ReceiptIntelligenceService`:
- **Optical ABN Auto-Repair:** An algorithmic repair pipeline that identifies high-frequency character confusions (`O`, `D`, `Q` -> `0`; `I`, `L`, `|` -> `1`; `B` -> `8`; `S` -> `5`; `Z` -> `2`) and evaluates them against the ATO Modulus-89 algorithm.
- **GST Mathematical Invariant Deduction:** Auto-corrects Total amounts from GST ($11 \times \text{GST} = \text{Total}$) when total lines are smudged or torn.
- **Levenshtein Fuzzy Settlement Anchor:** Anchors totals to bottom-up payment tokens (`TOTAL`, `EFTPOS`, `VISA`, `PAID`) within edit distance $\le 1$.

*Result:* Instant elimination of manual edits for single-character optical errors on ABN and Total without increasing inference latency or memory.

---

## Phase 2: KiloClaim-Receipt-VLM (Dedicated Model Architecture)

### 1. Base Model Selection
Instead of training from scratch, fine-tune an open-weight sub-1B Vision-Language / Document Parser:
- **Primary Candidate:** **Surya 2 / Surya-OCR** (Lightweight Transformer, native reading order and layout) or **GOT-OCR 2.0 / PaddleOCR-VL 1.5** (End-to-End VLM).
- **Target Footprint:** Model size $\le 450\text{ MB}$ in GGUF / ONNX format, allowing local execution on modern iPhone (Neural Engine / CoreML) and Apple Silicon Macs.

### 2. Output Schema Contract
The model should not emit flat text. It emits structured JSON directly:
```json
{
  "merchant": "BUNNINGS WAREHOUSE",
  "abn": "53004085616",
  "tax_invoice": true,
  "date": "2026-11-20",
  "time": "14:32:00",
  "currency": "AUD",
  "subtotal": 100.00,
  "gst": 10.00,
  "total": 110.00,
  "payment_method": "EFTPOS",
  "items": [
    {
      "description": "DEWALT 18V XR DRILL",
      "quantity": 1.0,
      "unit_price": 110.00,
      "total_price": 110.00,
      "is_deductible_tool": true
    }
  ]
}
```

### 3. Training & Data Generation Pipeline
1. **Synthetic Australian Receipt Generator:**
   - 50,000 synthetic receipts matching top Australian tradie suppliers:
     - Hardware: Bunnings, Mitre 10, Bowens, Total Tools, Sydney Tools.
     - Plumbing: Reece, Tradelink.
     - Electrical: Middy's, Rexel, Lawrence & Hanson.
     - Fuel: Ampol, BP, Shell/Coles Express, 7-Eleven, EG Fuelco.
2. **Noise & Degradation Augmentation:**
   - Thermal fade simulation (contrast reduction, erosion, pixel dropout).
   - In-car lighting simulation (direct sunlight glare, steering wheel shadows).
   - Geometric warp (folds, crinkles, angled perspective).

### 4. Deployment Topology
- **Tier 1 (On-Device Mobile):** Mobile pre-processing (Sauvola local binarization) + ML Kit / ONNX compact model + Deterministic Repair Layer.
- **Tier 2 (Cloud / Edge Acceleration):** High-resolution server endpoint running fine-tuned Sub-1B VLM for receipts with confidence $< 0.80$.
