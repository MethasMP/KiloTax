#!/usr/bin/env python3
"""
KiloClaim 1,000 Random User Sandbox Simulation (Tradie & Sole Trader Real-World Invariant Engine)
Simulates:
1. 1,000 distinct Australian tradie user personas & work patterns across FY 2026/2027.
2. Complete end-to-end user journeys:
   - Onboarding & Vehicle Setup (Make/Model, Dual Method Selection: CPK vs Logbook)
   - Tracking & Trip Capture (Bluetooth auto-start, GPS noise, Dead zone tunnel gaps, Geofences)
   - End-of-Day Review (Friction in Ute cabin at 5 PM, Fatigue, 1-tap resolution)
   - Receipt OCR & Expense Linking (Bunnings, Reece, Middy's, Caltex/Ampol fuel receipts)
   - ATO Tax Arbitrage & Accountant Handoff (5,000 km threshold caps, Bulky Tools exception, Audit-proof Export)
3. Quantitative telemetry for UX/UI bottlenecks, Invariant violations, and friction points.
"""

import random
import math
import json
from collections import defaultdict

def run_simulation(seed=42, n_users=1000):
    random.seed(seed)
    
    # Personas based on Australian Tradie Demographics
    # Sparky (30%), Plumber (25%), Chipper/Carpenter (20%), Subcontractor/Handyman (15%), Heavy Hauler/Civil (10%)
    personas_def = [
        {"trade": "Sparky", "weight": 0.30, "bulky_tools": True, "avg_stops_day": (6, 12), "top_merchants": ["Middy's", "Rexel", "Bunnings"]},
        {"trade": "Plumber", "weight": 0.25, "bulky_tools": True, "avg_stops_day": (5, 10), "top_merchants": ["Reece Plumbing", "Tradelink", "Bunnings"]},
        {"trade": "Chipper/Carpenter", "weight": 0.20, "bulky_tools": True, "avg_stops_day": (2, 5), "top_merchants": ["Bowens", "Bunnings", "Mitre 10"]},
        {"trade": "Subcontractor/Casual", "weight": 0.15, "bulky_tools": False, "avg_stops_day": (1, 3), "top_merchants": ["Bunnings", "Total Tools"]},
        {"trade": "Civil/Heavy Hauler", "weight": 0.10, "bulky_tools": True, "avg_stops_day": (2, 4), "top_merchants": ["Blackwoods", "Ampol", "BP"]},
    ]
    
    vehicles_pool = [
        ("Toyota", "HiLux SR5 2022", "Diesel Ute", 2800),
        ("Ford", "Ranger Wildtrak 2023", "Diesel Ute", 3000),
        ("Isuzu", "D-Max X-Terrain 2021", "Diesel Ute", 3000),
        ("Mitsubishi", "Triton GLS 2020", "Diesel Ute", 2400),
        ("Toyota", "HiAce Van 2021", "Van", 2800),
        ("Holden", "Colorado 2019", "Diesel Ute", 2800),
        ("Mazda", "BT-50 2022", "Diesel Ute", 3000),
        ("Hyundai", "iLoad Van 2018", "Van", 2500),
    ]

    # Metrics tracked
    results = {
        "total_users": n_users,
        "onboarding_friction": defaultdict(int),
        "tracking_issues": defaultdict(int),
        "review_friction_5pm": defaultdict(int),
        "receipt_ocr_issues": defaultdict(int),
        "tax_arbitrage_behavior": defaultdict(int),
        "accountant_handoff_blockers": defaultdict(int),
        "ui_ux_ergonomics": defaultdict(int),
        "critical_bugs_encountered": defaultdict(int),
    }

    user_journey_logs = []

    for user_id in range(1, n_users + 1):
        # Pick Persona
        r = random.random()
        cum = 0
        selected_p = personas_def[-1]
        for p in personas_def:
            cum += p["weight"]
            if r <= cum:
                selected_p = p
                break
        
        veh_make, veh_model, veh_type, engine_cc = random.choice(vehicles_pool)
        initial_odo = random.randint(15000, 185000)
        
        # User characteristics
        tech_literacy = random.uniform(0.15, 0.90)  # Tradies skew towards pragmatic/low tolerance for complex UI
        fatigue_level_5pm = random.uniform(0.50, 0.98) # High fatigue after physical work
        has_bluetooth_car = random.random() < 0.82
        bluetooth_auto_connect = has_bluetooth_car and (random.random() < 0.75)
        
        # Journey Stage 1: Onboarding & Setup
        user_log = {"id": user_id, "trade": selected_p["trade"], "vehicle": f"{veh_make} {veh_model}"}
        
        # 1.1 Rego Lookup vs Manual Entry
        if random.random() < 0.12: # Rego lookup failed or missing state
            results["onboarding_friction"]["rego_lookup_fallback_needed"] += 1
            if tech_literacy < 0.30 and random.random() < 0.25:
                results["onboarding_friction"]["abandoned_on_manual_rego_entry"] += 1
        
        # 1.2 Initial Method Selection (CPK vs Logbook)
        # Expected annual km
        annual_est_km = random.randint(3000, 42000)
        if annual_est_km < 5000:
            initial_method = "centsPerKm"
        else:
            # Many tradies start CPK because they think it's easier, despite driving 25,000 km!
            initial_method = "centsPerKm" if random.random() < 0.55 else "logbook"
        
        # Stage 2: Driving & Telemetry (Simulate a 12-week work cycle)
        num_weeks = 12
        total_trips = 0
        business_trips = 0
        total_km = 0.0
        business_km = 0.0
        gps_drop_count = 0
        unclassified_trips = 0
        receipts_scanned = 0
        receipts_unlinked = 0
        
        daily_stops = random.randint(*selected_p["avg_stops_day"])
        weekly_trips = daily_stops * 5
        
        current_odo = float(initial_odo)
        
        for w in range(num_weeks):
            for t in range(weekly_trips):
                total_trips += 1
                trip_km = max(0.4, random.expovariate(1.0 / 14.5)) # Exponential dist, avg 14.5 km
                total_km += trip_km
                
                # Classification logic
                is_business = True
                if t % daily_stops == 0:
                    # Home to first job - Bulky Tools exemption applies?
                    if selected_p["bulky_tools"]:
                        is_business = True # Deductible under s 8-1 bulky tools
                    else:
                        is_business = False # Commute is private!
                elif t % daily_stops == (daily_stops - 1):
                    # Last job to home
                    if selected_p["bulky_tools"]:
                        is_business = True
                    else:
                        is_business = False
                
                if is_business:
                    business_trips += 1
                    business_km += trip_km
                
                current_odo += trip_km
                
                # GPS & Hardware Real-world anomalies
                # A: GPS dead zone (underground carpark, tunnel, rural Victoria/NSW)
                if random.random() < 0.035:
                    results["tracking_issues"]["gps_tunnel_multipath_gap"] += 1
                    gps_drop_count += 1
                
                # B: Bluetooth disconnect before trip end
                if bluetooth_auto_connect and random.random() < 0.02:
                    results["tracking_issues"]["premature_trip_cutoff_bt_disconnect"] += 1
                
                # C: Micro-trip (< 800m e.g. moving ute around the construction site)
                if trip_km < 0.8:
                    results["tracking_issues"]["ghost_micro_trip_on_site"] += 1

        # Stage 3: End-of-Day / Weekend Review Fatigue (5 PM in the ute)
        # Tradies don't categorize every trip in real-time. They face a backlog!
        unreviewed_ratio = random.uniform(0.10, 0.45) if tech_literacy < 0.5 else random.uniform(0.02, 0.15)
        unreviewed_trips_count = int(total_trips * unreviewed_ratio)
        
        if unreviewed_trips_count > 15:
            results["review_friction_5pm"]["backlog_overwhelm_gt_15_trips"] += 1
            if fatigue_level_5pm > 0.85:
                results["review_friction_5pm"]["swiped_all_blindly_without_audit_check"] += 1
        
        if selected_p["bulky_tools"] and not initial_method == "centsPerKm":
            # Did the app clearly show them why home-to-site was deductible?
            if random.random() < 0.28:
                results["ui_ux_ergonomics"]["bulky_tools_rationale_unclear_at_review"] += 1

        # Stage 4: Expense & Receipt Ingestion (Bunnings / Fuel)
        num_expenses = random.randint(6, 35)
        for e in range(num_expenses):
            receipts_scanned += 1
            merchant = random.choice(selected_p["top_merchants"])
            
            # Receipt OCR friction with Thermal Preprocessor & Context Fusion
            is_crumpled_or_faded = random.random() < 0.22 # Thermal receipt faded in sunny ute dashboard
            if is_crumpled_or_faded:
                # With Thermal Preprocessor (contrast + gamma) and Mod-89 repair, 85% of faded receipts are recovered cleanly
                recovered_by_preprocessor_and_repair = random.random() < 0.85
                if not recovered_by_preprocessor_and_repair:
                    results["receipt_ocr_issues"]["faded_thermal_paper_low_confidence"] += 1
                    # With Context Fusion from recent Trip stop, ABN & Merchant are pre-filled
                    trip_context_available = random.random() < 0.80
                    if not trip_context_available and random.random() < 0.35:
                        results["receipt_ocr_issues"]["abn_or_gst_missed_requires_manual_edit"] += 1
                else:
                    results["receipt_ocr_issues"]["thermal_paper_auto_healed"] += 1
            
            # Unlinked expense (no trip matched within 2 hours)
            if random.random() < 0.14:
                receipts_unlinked += 1
                results["receipt_ocr_issues"]["orphaned_expense_no_matching_trip"] += 1

        # Stage 5: Tax Arbitrage Invariant & Statutory Threshold
        # ATO Cents per km cap is 5,000 km. Rate 88c/km (FY 2024-2026) -> Max $4,400.
        # If Logbook business km > 5,000 km, Logbook almost always wins by thousands of dollars!
        annual_projected_business_km = business_km * (52.0 / num_weeks)
        if initial_method == "centsPerKm" and annual_projected_business_km > 5000:
            money_left_on_table = (annual_projected_business_km - 5000) * 0.88 + (num_expenses * 120 * 0.70)
            results["tax_arbitrage_behavior"]["cpk_capped_at_5000km_money_loss"] += 1
            
            # Did user notice the Smart Pivot alert?
            if random.random() < 0.78:
                results["tax_arbitrage_behavior"]["smart_pivot_to_logbook_triggered"] += 1
            else:
                results["tax_arbitrage_behavior"]["ignored_smart_pivot_lost_deductions"] += 1

        # Stage 6: Accountant Handoff & EOFY Export
        # When sending to their tax agent:
        has_odometer_start_photo = random.random() < 0.68
        has_odometer_end_photo = random.random() < 0.54
        
        if initial_method == "logbook" or results["tax_arbitrage_behavior"]["smart_pivot_to_logbook_triggered"]:
            if not (has_odometer_start_photo and has_odometer_end_photo):
                results["accountant_handoff_blockers"]["missing_odo_photo_audit_vulnerability"] += 1
            
            # Odometer Gap
            if random.random() < 0.08:
                results["accountant_handoff_blockers"]["unexplained_odometer_jump_gap"] += 1
            
            # Non-business trip quarantine check
            private_trips = total_trips - business_trips
            if private_trips > 0 and random.random() < 0.12:
                results["accountant_handoff_blockers"]["user_worried_private_trip_details_leak_to_accountant"] += 1

        # Stage 7: Ergonomics & UI Accessibility (In sunlight, dynamic text 150-200%)
        if random.random() < 0.18: # High sunlight in car
            results["ui_ux_ergonomics"]["contrast_subtle_grey_unreadable_in_glare"] += 1
        
        if tech_literacy < 0.25:
            # Found small tap targets
            results["ui_ux_ergonomics"]["missed_small_touch_target_fatigue"] += 1

    return results

if __name__ == "__main__":
    print("🚀 Starting KiloClaim 1,000 Tradie Monte Carlo Sandbox Simulation...")
    sim_results = run_simulation(seed=1337, n_users=1000)
    print(json.dumps(sim_results, indent=2))
