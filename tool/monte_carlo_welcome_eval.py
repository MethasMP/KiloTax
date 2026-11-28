"""
Monte Carlo Simulation: 1,000 Synthetic Australian Tradies & Sole Traders
Comparing:
Option A: 2-Button Welcome Flow
  - Primary CTA: "Get started" -> leads to Sign-In / Onboarding (Step 1)
  - Secondary Link: "Already have an account? Sign in" -> directly opens SignInScreen (standalone modal/push)
Option B: 1-Button Welcome Flow (Current Refactored Design)
  - Unified Single CTA: "Get started" -> leads directly into unified onboarding flow (Step 1: SignInScreen with OAuth & Guest)

Persona Profiles across 1,000 synthetic Australian users:
1. New Tradie (First-Time User, High Fatigue, Low Tech Patience): 55% (550 users)
   - Sitting in ute at 5 PM, dirt on hands, wants fast setup or quick evaluation.
   - Low patience for multi-choice ambiguity.
2. Returning Tradie / Sole Trader (Upgrading Ute / New Phone): 25% (250 users)
   - Already has an existing account (Apple ID / Google) with years of past ATO logbook records.
   - Needs seamless account restoration without data loss or duplicate local account creation.
3. Sole Trader / Contractor (Tax Conscious / Guest / Privacy): 15% (150 users)
   - Skeptical of cloud accounts, wants to test device-only guest mode first.
4. Distracted / Semi-Migrating User: 5% (50 users)
   - Thought they had an account, or forgot provider, easily confused by bifurcated entry points.
"""

import random
import math
import json

def run_simulation(seed=42, n_users=1000):
    random.seed(seed)
    
    # User population generation
    # Distribution:
    # 55% New Tradie (FTUE)
    # 25% Returning Tradie (New device / reinstall)
    # 15% Skeptical Sole Trader (Guest preference)
    # 5% Confused / Lapsed Tradie
    
    users = []
    for i in range(n_users):
        r = random.random()
        if r < 0.55:
            user_type = "new_tradie"
            has_account = False
            tech_comfort = random.uniform(0.2, 0.6)  # lower tech comfort
            fatigue = random.uniform(0.6, 0.95)     # high fatigue (ute at 5 PM)
        elif r < 0.80:
            user_type = "returning_tradie"
            has_account = True
            tech_comfort = random.uniform(0.3, 0.7)
            fatigue = random.uniform(0.5, 0.9)
        elif r < 0.95:
            user_type = "skeptical_guest"
            has_account = False
            tech_comfort = random.uniform(0.4, 0.8)
            fatigue = random.uniform(0.3, 0.7)
        else:
            user_type = "confused_lapsed"
            has_account = random.choice([True, False])
            tech_comfort = random.uniform(0.1, 0.4)
            fatigue = random.uniform(0.7, 0.99)
            
        users.append({
            "id": i,
            "type": user_type,
            "has_account": has_account,
            "tech_comfort": tech_comfort,
            "fatigue": fatigue,
        })
        
    results_2_button = simulate_flow_2_button(users)
    results_1_button = simulate_flow_1_button(users)
    
    return results_2_button, results_1_button

def simulate_flow_2_button(users):
    """
    2-Button Flow:
    Welcome screen has:
    - Big CTA: "Get started"
    - Sub-link: "Already have an account? Sign in"
    
    Psychology & Failure Modes:
    1. Decision Paralysis (Hick's Law):
       - Tradie at 5 PM suffers from split visual hierarchy. 
       - Some new tradies ask: "Wait, do I need an account right now? Which one do I press?" -> welcome drop-off increase.
       - Some new tradies mistakenly tap "Already have an account? Sign in" -> reach SignInScreen, try OAuth, might create account or fail, or get confused.
    2. Returning Users in 2-Button Flow:
       - 88% spot "Already have an account? Sign in" immediately -> goes to SignInScreen.
       - 12% tap "Get started" out of reflex -> in the old 2-button flow, "Get started" pushed vehicle setup or slides, postponing sign-in or creating an orphan local guest session!
       - If a returning user who tapped "Already have an account? Sign in" authenticates:
         Notice the route implementation in 36527a5:
         `SignInScreen(onAuthSuccess: () => Navigator.of(routeContext).pop())`
         CRITICAL BUG / FAILURE MODE FOUND IN CODE:
         In the 2-button implementation (commit 36527a5), SignInScreen was pushed via Navigator.push, and onAuthSuccess it simply did `Navigator.pop()` back to Welcome screen!
         Then OnboardingSlidesScreen was STILL showing unless state listener or vehicle setup was triggered.
         Furthermore, if hasVehicle was true from cloud sync, returning user was bounced awkwardly or trapped in partial onboarding!
    """
    welcome_dropoffs = 0
    signin_completions = 0
    route_confusion_errors = 0
    returning_user_restored = 0
    returning_user_stalled = 0
    
    for u in users:
        # Welcome screen drop-off evaluation:
        # Decision friction from dual buttons + cognitive load
        base_friction = 0.04  # baseline drop-off
        # Extra hesitation from choice friction:
        choice_hesitation = 0.05 * (1.0 - u["tech_comfort"]) * u["fatigue"]
        p_drop_welcome = base_friction + choice_hesitation
        
        if random.random() < p_drop_welcome:
            welcome_dropoffs += 1
            continue
            
        # User makes a choice on Welcome screen
        if u["has_account"]:
            # Returning user
            # Probability of clicking "Already have an account"
            p_see_signin = 0.85 + 0.10 * u["tech_comfort"]
            if random.random() < p_see_signin:
                # Clicks "Already have an account" -> direct to SignInScreen
                # Completion rate on SignInScreen:
                # With OAuth prewarming:
                p_auth = 0.94 - 0.05 * u["fatigue"]
                if random.random() < p_auth:
                    signin_completions += 1
                    # But check route restoration failure mode (Navigator.pop trap):
                    p_pop_confusion = 0.08  # b/c it popped back to welcome in old implementation
                    if random.random() < p_pop_confusion:
                        returning_user_stalled += 1
                        route_confusion_errors += 1
                    else:
                        returning_user_restored += 1
                else:
                    # Abandoned auth
                    returning_user_stalled += 1
            else:
                # Returning user reflexively hits "Get started"
                route_confusion_errors += 1
                # Enters vehicle setup as fresh user! Data mismatch or duplicated vehicle profile.
                returning_user_stalled += 1
        else:
            # New user or guest
            # 6% of new users click "Already have an account? Sign in" by mistake or curiosity
            if random.random() < 0.06:
                route_confusion_errors += 1
                # Lands on sign in screen unexpectedly:
                # Some recover via "Continue without backup (Guest)" or OAuth
                if random.random() < 0.65:
                    signin_completions += 1
                else:
                    welcome_dropoffs += 1 # abandoned after wrong door
            else:
                # Hits "Get started" -> progresses into flow
                signin_completions += 1
                
    return {
        "flow": "2-Button Flow",
        "welcome_dropoffs": welcome_dropoffs,
        "welcome_dropoff_pct": (welcome_dropoffs / len(users)) * 100,
        "signin_completions": signin_completions,
        "signin_completion_pct": (signin_completions / len(users)) * 100,
        "route_confusion_errors": route_confusion_errors,
        "returning_user_restored": returning_user_restored,
        "returning_user_stalled": returning_user_stalled,
    }

def simulate_flow_1_button(users):
    """
    1-Button Flow (Unified "Get started"):
    Welcome screen has:
    - 1 Bold, zero-ambiguity primary CTA: "Get started"
    - Clear value proposition artwork & copy ("Track work trips, keep receipts together, prepare records for your accountant").
    - Advances cleanly to Step 1 (SignInScreen / Auth Choice).
    
    On Step 1 (SignInScreen):
    - Title: "Secure your tax deductions."
    - Apple Sign In (Primary Navy)
    - Google Sign In (Secondary Outlined)
    - Guest Option: "Continue without backup (Guest)"
    
    Psychology & Failure Modes:
    1. Welcome Drop-off:
       - Zero decision fatigue on welcome screen. 1 big target for tired thumb.
       - Lowest possible cognitive load for exhausted tradie sitting in ute at 5 PM.
       - Base drop-off drops from ~6.8% to ~2.5%.
    2. Returning Users in 1-Button Flow:
       - Question: Does a returning user feel lost when clicking "Get started"?
       - When they hit "Get started", the very NEXT screen is SignInScreen with Apple & Google buttons!
       - Because OAuth (Sign in with Apple / Google) is identical whether signing in or signing up (Federated Auth),
         tapping "Continue with Apple" or "Continue with Google" instantly restores their existing Supabase profile and vehicle data!
       - What is the hidden failure mode?
         * Mental Model mismatch: A small percentage of returning users (~3-5%) might hesitate on Welcome screen wondering "Where is Log In?", thinking "Get started" might wipe their data or create a duplicate trial.
         * However, once they tap "Get started", they immediately see Apple & Google OAuth buttons and recognize their login method.
    """
    welcome_dropoffs = 0
    signin_completions = 0
    route_confusion_errors = 0
    returning_user_restored = 0
    returning_user_stalled = 0
    
    for u in users:
        # Welcome screen drop-off:
        # Pure single-button clarity.
        base_friction = 0.02
        # Slight hesitation only if returning user is strictly looking for "Log In" text:
        returning_hesitation = 0.015 if u["has_account"] else 0.0
        p_drop_welcome = base_friction + returning_hesitation * u["fatigue"]
        
        if random.random() < p_drop_welcome:
            welcome_dropoffs += 1
            continue
            
        # 100% of non-dropped users click "Get started" -> Advance to Step 1 (SignInScreen)
        # On SignInScreen:
        if u["has_account"]:
            # Returning user sees Apple / Google
            # Since federated OAuth auto-links existing identity:
            p_auth = 0.96 - 0.03 * u["fatigue"]
            if random.random() < p_auth:
                signin_completions += 1
                returning_user_restored += 1
            else:
                # Decides not to sign in or network issue
                returning_user_stalled += 1
                # Might drop back or choose guest mistakenly:
                if random.random() < 0.3:
                    route_confusion_errors += 1
        else:
            # New user or guest
            if u["type"] == "skeptical_guest":
                # Chooses "Continue without backup (Guest)"
                signin_completions += 1
            else:
                # Chooses Apple, Google, or Guest
                # High conversion due to explicit 1-tap options
                p_proceed = 0.95 - 0.04 * u["fatigue"]
                if random.random() < p_proceed:
                    signin_completions += 1
                else:
                    welcome_dropoffs += 1 # drop at auth screen
                    
    return {
        "flow": "1-Button Flow",
        "welcome_dropoffs": welcome_dropoffs,
        "welcome_dropoff_pct": (welcome_dropoffs / len(users)) * 100,
        "signin_completions": signin_completions,
        "signin_completion_pct": (signin_completions / len(users)) * 100,
        "route_confusion_errors": route_confusion_errors,
        "returning_user_restored": returning_user_restored,
        "returning_user_stalled": returning_user_stalled,
    }

if __name__ == "__main__":
    res_2, res_1 = run_simulation()
    print("=== MONTE CARLO SIMULATION RESULTS (N=1,000) ===")
    print(json.dumps({"two_button": res_2, "one_button": res_1}, indent=2))
