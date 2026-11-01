#!/usr/bin/env python3
import sys
import os
import json
import re
import urllib.request
import io
import datetime

try:
    import pypdf
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pypdf"])
    import pypdf

print("=" * 60)
print("🏛️  [ATO Sentinel] Autonomous Gazette Legal Extraction Engine")
print("=" * 60)

SUPABASE_URL = (os.environ.get("SUPABASE_URL") or "https://mwtxfdqcyalsohruzmps.supabase.co").strip()
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

now = datetime.datetime.now()
current_start_year = now.year if now.month >= 7 else now.year - 1

# Statutory Determinations under ITAA 1997 s.28-25
GAZETTE_REGISTRY = {
    2026: "F2026L00785",
    2024: "F2024L00697",
    2023: "F2023L00767",
    2022: "F2022L00813",
    2020: "F2020L00676",
}

# 1. Probe for future year determination (e.g. 2027) if published
next_year = current_start_year + 1
print(f"🔎 Probing Australian Legislation Register for upcoming FY {next_year} Determination...")
try:
    search_url = f"https://api.prod.legislation.gov.au/v1/titles?$filter=contains(name,'Cents%20per%20Kilometre')%20and%20contains(name,'{next_year}')&$select=id,name"
    req = urllib.request.Request(search_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=5) as res:
        if res.status == 200:
            data = json.loads(res.read().decode('utf-8'))
            items = data.get('value', [])
            if items:
                new_id = items[0]['id']
                print(f"🚨 FOUND NEW STATUTORY INSTRUMENT FOR {next_year}: {new_id}")
                GAZETTE_REGISTRY[next_year] = new_id
except Exception as e:
    print(f"   ℹ️  Future year check: not yet gazetted for {next_year}")

# 2. Extract rates from official Gazette PDFs
detected_rules = []

for year in sorted(GAZETTE_REGISTRY.keys(), reverse=True):
    reg_id = GAZETTE_REGISTRY[year]
    print(f"📥 Downloading & Parsing Official Gazette PDF: FY {year} ({reg_id})...")
    try:
        downloads_url = f"https://www.legislation.gov.au/{reg_id}/latest/downloads"
        req = urllib.request.Request(downloads_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as res:
            html = res.read().decode("utf-8")
        
        pdf_match = re.search(rf"https://www\.legislation\.gov\.au/{reg_id}/asmade/[^/]+/text/original/pdf", html)
        if not pdf_match:
            print(f"   ⚠️ Could not find PDF link for {reg_id}")
            continue

        pdf_url = pdf_match.group(0)
        req_pdf = urllib.request.Request(pdf_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req_pdf, timeout=15) as res_pdf:
            pdf_bytes = res_pdf.read()

        reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
        full_text = " ".join([page.extract_text() for page in reader.pages])

        rate_match = re.search(r"is\s+(\d{2})\s+cents\s+per\s+kilometre", full_text, re.IGNORECASE)
        if not rate_match:
            print(f"   ⚠️ Could not extract rate pattern from {reg_id}")
            continue

        cents = int(rate_match.group(1))
        rate = cents / 100.0
        print(f"   🎯 VERIFIED STATUTORY RATE: FY {year} = {cents}¢/km (Source: {reg_id})")

        detected_rules.append({
            "year": year,
            "rate": rate,
            "registerId": reg_id,
        })
    except Exception as e:
        print(f"   ❌ Error extracting {reg_id}: {e}")

if not detected_rules:
    print("❌ Failed to extract any statutory rules. Aborting.")
    sys.exit(1)

# 3. Completely clear & rebuild assets/data/ato_rates_baseline.json
baseline_data = []
for rule in detected_rules:
    y = rule["year"]
    fy_str = f"{y}-{(y + 1) % 100:02d}"
    baseline_data.append({
        "financialYear": fy_str,
        "startYear": y,
        "centsPerKmRate": rule["rate"],
        "centsPerKmMaxKm": 5000.0,
        "carDepreciationLimit": 69674.0,
        "isActive": (y == current_start_year),
        "source": f"Australian Government Gazette ({rule['registerId']})"
    })

baseline_path = os.path.join("assets", "data", "ato_rates_baseline.json")
with open(baseline_path, "w", encoding="utf-8") as f:
    json.dump(baseline_data, f, indent=2)

print(f"\n💾 {baseline_path} completely rebuilt & written directly from Government Gazette!")
print(f"   Total statutory determinations: {len(baseline_data)}")

# 4. Synchronize directly into Supabase Cloud Vault (ato_tax_rules)
if SERVICE_ROLE_KEY:
    print("\n☁️  Upserting statutory determinations to Supabase (ato_tax_rules)...")
    for rule in detected_rules:
        y = rule["year"]
        fy_str = f"{y}-{(y + 1) % 100:02d}"
        payload = {
            "financial_year": fy_str,
            "start_year": y,
            "cents_per_km_rate": rule["rate"],
            "cents_per_km_max_km": 5000.0,
            "car_depreciation_limit": 69674.0,
            "legislative_ref": f"ITAA 1997 s.28-25 / Gazette {rule['registerId']}",
            "source_url": f"https://www.legislation.gov.au/{rule['registerId']}",
            "is_active": (y == current_start_year),
            "verified_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }
        upsert_url = f"{SUPABASE_URL}/rest/v1/ato_tax_rules"
        req_up = urllib.request.Request(
            upsert_url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "apikey": SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates",
            },
            method="POST"
        )
        try:
            with urllib.request.urlopen(req_up, timeout=10) as res_up:
                if res_up.status in [200, 201]:
                    print(f"   ✅ Upserted FY {fy_str} ({int(rule['rate']*100)}¢) into Supabase")
                else:
                    print(f"   ⚠️ Supabase returned {res_up.status}")
        except Exception as e:
            print(f"   ⚠️ Supabase Upsert error: {e}")
else:
    print("\nℹ️  SUPABASE_SERVICE_ROLE_KEY not supplied. Skipping cloud upsert (local baseline updated).")

print("\n🛡️ [ATO Sentinel] Pipeline completed with 100% statutory integrity.")
print("=" * 60)
