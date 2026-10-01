#!/usr/bin/env python3
"""
KiloTax App Store Screenshot Generator
Target: 1320 x 2868 px (Apple 6.9" display - iPhone 16/17/18 Pro Max)
Color Theme: High-Vis Aussie Tradie (Amber #F59E0B, Carbon #0F172A, Mint #10B981)
Compliance: Strict Apple HIG (No fake device hardware bezels, no alpha channel, legal disclaimers included)
"""

import os
import sys

OUTPUT_DIR = "/Users/methas/Desktop/DriveLog/docs/app_store/templates"
os.makedirs(OUTPUT_DIR, exist_ok=True)

WIDTH = 1320
HEIGHT = 2868

# Common SVG Defs (Gradients, Filters, Shadows)
SVG_DEFS = """
  <defs>
    <!-- Background Gradient -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#0F172A" />
      <stop offset="40%" stop-color="#0B132B" />
      <stop offset="100%" stop-color="#020617" />
    </linearGradient>

    <!-- Card Background Gradient -->
    <linearGradient id="cardGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1E293B" />
      <stop offset="100%" stop-color="#0F172A" />
    </linearGradient>

    <!-- Inner Card Highlight Gradient -->
    <linearGradient id="innerCardGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#26354A" />
      <stop offset="100%" stop-color="#152033" />
    </linearGradient>

    <!-- High-Vis Amber Glow Gradient -->
    <linearGradient id="amberGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F59E0B" />
      <stop offset="100%" stop-color="#D97706" />
    </linearGradient>

    <!-- Mint Emerald Gradient -->
    <linearGradient id="mintGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10B981" />
      <stop offset="100%" stop-color="#059669" />
    </linearGradient>

    <!-- Amber Glow Filter -->
    <filter id="amberGlow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="30" result="blur" />
      <feComposite in="SourceGraphic" in2="blur" operator="over" />
    </filter>

    <!-- Card Drop Shadow -->
    <filter id="cardShadow" x="-10%" y="-5%" width="120%" height="115%">
      <feDropShadow dx="0" dy="30" stdDeviation="35" flood-color="#000000" flood-opacity="0.65" />
    </filter>
    
    <filter id="softShadow" x="-5%" y="-5%" width="110%" height="115%">
      <feDropShadow dx="0" dy="12" stdDeviation="15" flood-color="#000000" flood-opacity="0.4" />
    </filter>
  </defs>
"""

def generate_slide_1():
    """Slide 1: 'Track every work km' ($4,550 deduction at 91c/km)"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}">
  {SVG_DEFS}
  <!-- Solid Background: 24-bit RGB strictly without alpha -->
  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#bgGrad)" />

  <!-- Ambient Amber Glow behind Hero Card -->
  <circle cx="660" cy="980" r="450" fill="#F59E0B" opacity="0.12" filter="url(#amberGlow)" />

  <!-- Top Pill Badge -->
  <g transform="translate(96, 150)">
    <rect width="480" height="64" rx="32" fill="#FEF3C7" />
    <circle cx="36" cy="32" r="10" fill="#F59E0B" />
    <text x="58" y="42" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Inter', sans-serif" font-size="26" font-weight="800" fill="#B45309" letter-spacing="1.5">ATO 2026–27 · 91¢ PER KM</text>
  </g>

  <!-- Billboard Headline -->
  <text x="96" y="295" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Inter', sans-serif" font-size="82" font-weight="900" fill="#FFFFFF" letter-spacing="-1.5">Track every work km.</text>
  <text x="96" y="390" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Inter', sans-serif" font-size="82" font-weight="900" fill="#F59E0B" letter-spacing="-1.5">Claim up to $4,550.</text>

  <!-- Subheadline -->
  <text x="96" y="465" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Inter', sans-serif" font-size="36" font-weight="500" fill="#94A3B8" letter-spacing="-0.2">Official 91c/km ATO Cents-per-Kilometre method for your ute or work car.</text>

  <!-- Main App Card (No Hardware Bezels) -->
  <g transform="translate(96, 550)" filter="url(#cardShadow)">
    <!-- Container -->
    <rect width="1128" height="2060" rx="64" fill="url(#cardGrad)" stroke="#334155" stroke-width="2" />

    <!-- Vehicle Selector Header -->
    <g transform="translate(48, 56)">
      <rect width="1032" height="110" rx="30" fill="#152033" stroke="#334155" stroke-width="1.5" />
      <!-- Ute Icon Pill -->
      <rect x="24" y="23" width="64" height="64" rx="16" fill="#F59E0B" />
      <path d="M42 58 L70 58 M46 58 C46 53 50 49 56 49 C62 49 66 53 66 58 M40 50 L50 38 L65 38 L72 50 Z" stroke="#0F172A" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" />
      <text x="110" y="52" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="700" fill="#F8FAFC">2024 Toyota HiLux SR5</text>
      <text x="110" y="90" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#94A3B8">VIC · 1TR-8DE • Cents per Km</text>
      <rect x="850" y="32" width="158" height="46" rx="23" fill="#ECFDF5" />
      <text x="880" y="63" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="700" fill="#059669">● ACTIVE</text>
    </g>

    <!-- Hero Deduction Gauge Box -->
    <g transform="translate(48, 196)" filter="url(#softShadow)">
      <rect width="1032" height="470" rx="40" fill="url(#innerCardGrad)" stroke="#475569" stroke-width="2" />
      <text x="48" y="70" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="26" font-weight="800" fill="#94A3B8" letter-spacing="2">ESTIMATED TAX DEDUCTION (2026–27)</text>
      
      <!-- Big Value -->
      <text x="48" y="195" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="124" font-weight="900" fill="#F59E0B" letter-spacing="-3">$4,550.00</text>
      
      <!-- Progress Bar -->
      <g transform="translate(48, 245)">
        <rect width="936" height="28" rx="14" fill="#0F172A" />
        <rect width="936" height="28" rx="14" fill="url(#amberGrad)" />
      </g>
      
      <text x="48" y="320" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="30" font-weight="700" fill="#F8FAFC">5,000 / 5,000 km Tracked (100% of Quota)</text>
      <text x="48" y="360" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Official ATO rate: 91¢ per business kilometre</text>
      
      <!-- Cash Refund Callout Pill -->
      <g transform="translate(48, 390)">
        <rect width="936" height="54" rx="20" fill="#ECFDF5" />
        <text x="32" y="36" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="700" fill="#059669">💰 ~$1,456 estimated cash back at 32% marginal tax bracket</text>
      </g>
    </g>

    <!-- Trip Ledger Section Header -->
    <g transform="translate(48, 710)">
      <text x="12" y="36" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="800" fill="#F8FAFC">Recent Work Trips</text>
      <text x="890" y="36" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="26" font-weight="600" fill="#F59E0B">View All (142)</text>
    </g>

    <!-- Trip 1 -->
    <g transform="translate(48, 770)">
      <rect width="1032" height="190" rx="30" fill="#152033" stroke="#334155" stroke-width="1.5" />
      <rect x="32" y="32" width="60" height="60" rx="18" fill="#FEF3C7" />
      <text x="45" y="72" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="30">🔨</text>
      <text x="115" y="62" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="700" fill="#F8FAFC">Bunnings Warehouse ➔ Jobsite Bardon</text>
      <text x="115" y="102" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Today, 8:15 AM · Materials pickup &amp; transport</text>
      <text x="115" y="145" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="700" fill="#10B981">✓ Verified Route</text>
      
      <!-- Right Amount -->
      <text x="990" y="70" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="36" font-weight="800" fill="#F59E0B">+$31.12</text>
      <text x="990" y="106" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#94A3B8">34.2 km</text>
      <rect x="880" y="125" width="110" height="36" rx="18" fill="#1E293B" stroke="#334155" />
      <text x="935" y="149" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="20" font-weight="700" fill="#F8FAFC">WORK</text>
    </g>

    <!-- Trip 2 -->
    <g transform="translate(48, 985)">
      <rect width="1032" height="190" rx="30" fill="#152033" stroke="#334155" stroke-width="1.5" />
      <rect x="32" y="32" width="60" height="60" rx="18" fill="#FEF3C7" />
      <text x="45" y="72" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="30">🔧</text>
      <text x="115" y="62" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="700" fill="#F8FAFC">Reece Plumbing ➔ Client Site Indooroopilly</text>
      <text x="115" y="102" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Yesterday, 1:40 PM · Emergency pipe fitting</text>
      <text x="115" y="145" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="700" fill="#10B981">✓ Verified Route</text>
      
      <!-- Right Amount -->
      <text x="990" y="70" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="36" font-weight="800" fill="#F59E0B">+$16.84</text>
      <text x="990" y="106" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#94A3B8">18.5 km</text>
      <rect x="880" y="125" width="110" height="36" rx="18" fill="#1E293B" stroke="#334155" />
      <text x="935" y="149" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="20" font-weight="700" fill="#F8FAFC">WORK</text>
    </g>

    <!-- Trip 3 -->
    <g transform="translate(48, 1200)">
      <rect width="1032" height="190" rx="30" fill="#152033" stroke="#334155" stroke-width="1.5" />
      <rect x="32" y="32" width="60" height="60" rx="18" fill="#FEF3C7" />
      <text x="45" y="72" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="30">📐</text>
      <text x="115" y="62" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="700" fill="#F8FAFC">Site Inspection ➔ Kedron Depot</text>
      <text x="115" y="102" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">24 May, 10:10 AM · Electrical pre-wire inspection</text>
      <text x="115" y="145" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="700" fill="#10B981">✓ Verified Route</text>
      
      <!-- Right Amount -->
      <text x="990" y="70" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="36" font-weight="800" fill="#F59E0B">+$38.22</text>
      <text x="990" y="106" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#94A3B8">42.0 km</text>
      <rect x="880" y="125" width="110" height="36" rx="18" fill="#1E293B" stroke="#334155" />
      <text x="935" y="149" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="20" font-weight="700" fill="#F8FAFC">WORK</text>
    </g>

    <!-- Bottom Quick Action Banner -->
    <g transform="translate(48, 1430)">
      <rect width="1032" height="130" rx="30" fill="#1E293B" stroke="#F59E0B" stroke-width="2" />
      <text x="48" y="60" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">⚡ Zero Setup Required</text>
      <text x="48" y="98" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Start logging trips immediately. No email or password needed.</text>
      <rect x="830" y="35" width="160" height="60" rx="20" fill="url(#amberGrad)" />
      <text x="910" y="73" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="24" font-weight="800" fill="#0F172A">TRY NOW</text>
    </g>
  </g>

  <!-- Legal Micro-Disclaimer -->
  <text x="660" y="2755" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="400" fill="#64748B">
    *Indicative deduction based on ATO 2026-27 rate of 91c/km up to 5,000 km cap per vehicle. Not financial or tax advice. Confirm claims with a registered tax agent. Source: ato.gov.au
  </text>
</svg>"""

def generate_slide_2():
    """Slide 2: 'Business or private?' (1-tap toggle)"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}">
  {SVG_DEFS}
  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#bgGrad)" />
  <circle cx="660" cy="1100" r="450" fill="#F59E0B" opacity="0.10" filter="url(#amberGlow)" />

  <!-- Top Pill Badge -->
  <g transform="translate(96, 150)">
    <rect width="470" height="64" rx="32" fill="#EFF6FF" />
    <circle cx="36" cy="32" r="10" fill="#2563EB" />
    <text x="58" y="42" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="26" font-weight="800" fill="#1E40AF" letter-spacing="1.5">EFFORTLESS · 1-TAP TOGGLE</text>
  </g>

  <!-- Headline -->
  <text x="96" y="295" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#FFFFFF" letter-spacing="-1.5">Business or private?</text>
  <text x="96" y="390" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#F59E0B" letter-spacing="-1.5">Sorted in one tap.</text>

  <!-- Subheadline -->
  <text x="96" y="465" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="36" font-weight="500" fill="#94A3B8" letter-spacing="-0.2">No messy paperwork. Classify trips right from the worksite.</text>

  <!-- App Card -->
  <g transform="translate(96, 550)" filter="url(#cardShadow)">
    <rect width="1128" height="2060" rx="64" fill="url(#cardGrad)" stroke="#334155" stroke-width="2" />

    <!-- Current Trip Review Card -->
    <g transform="translate(48, 60)" filter="url(#softShadow)">
      <rect width="1032" height="600" rx="40" fill="url(#innerCardGrad)" stroke="#475569" stroke-width="2" />

      <!-- GPS Route Visual Map Representation -->
      <g transform="translate(40, 40)">
        <rect width="952" height="220" rx="24" fill="#0B132B" stroke="#334155" stroke-width="1.5" />
        <!-- Stylized Map Route Line -->
        <path d="M 60 160 Q 250 40 480 130 T 880 70" fill="none" stroke="#F59E0B" stroke-width="8" stroke-linecap="round" stroke-dasharray="8 4" />
        <!-- Start Pin -->
        <circle cx="60" cy="160" r="16" fill="#10B981" stroke="#FFFFFF" stroke-width="4" />
        <text x="90" y="167" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="22" font-weight="700" fill="#F8FAFC">Eagle Farm Trade Coast</text>
        <!-- End Pin -->
        <circle cx="880" cy="70" r="16" fill="#F59E0B" stroke="#FFFFFF" stroke-width="4" />
        <text x="640" y="77" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="22" font-weight="700" fill="#F8FAFC">Queen St Site</text>
      </g>

      <!-- Trip Info -->
      <g transform="translate(48, 290)">
        <text x="0" y="40" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="44" font-weight="800" fill="#F8FAFC">28.4 km Completed</text>
        <text x="0" y="85" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="26" font-weight="500" fill="#94A3B8">Today · 2:15 PM – 2:48 PM (33 mins)</text>
        
        <!-- Tax Shield Instant Calculation Pill -->
        <g transform="translate(0, 120)">
          <rect width="936" height="70" rx="24" fill="#FEF3C7" />
          <text x="32" y="46" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="28" font-weight="800" fill="#B45309">⚡ Adds +$25.84 to your 2026–27 tax refund</text>
        </g>
      </g>
    </g>

    <!-- Big 1-Tap Toggle Selector -->
    <g transform="translate(48, 700)">
      <text x="12" y="40" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="800" fill="#F8FAFC">Select Trip Classification</text>
      
      <!-- Option A: WORK (Selected High-Vis Active State) -->
      <g transform="translate(0, 70)" filter="url(#softShadow)">
        <rect width="1032" height="180" rx="36" fill="#1E293B" stroke="#F59E0B" stroke-width="4" />
        <!-- Big Check Circle -->
        <circle cx="80" cy="90" r="38" fill="url(#amberGrad)" />
        <path d="M68 90 L76 98 L92 82" fill="none" stroke="#0F172A" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" />
        <text x="145" y="78" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="40" font-weight="800" fill="#FFFFFF">💼 Work / Business Trip</text>
        <text x="145" y="125" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="26" font-weight="600" fill="#F59E0B">Claimable at 91¢/km • 100% Tax Deductible</text>
        <rect x="860" y="60" width="130" height="60" rx="20" fill="#FEF3C7" />
        <text x="925" y="100" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="800" fill="#B45309">ACTIVE</text>
      </g>

      <!-- Option B: PRIVATE (Standard State) -->
      <g transform="translate(0, 280)">
        <rect width="1032" height="150" rx="36" fill="#152033" stroke="#334155" stroke-width="2" />
        <circle cx="80" cy="75" r="30" fill="#0F172A" stroke="#475569" stroke-width="2" />
        <text x="145" y="70" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="700" fill="#94A3B8">🏠 Personal / Private Trip</text>
        <text x="145" y="110" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#64748B">Commute between home and normal depot</text>
      </g>
    </g>

    <!-- Quick Purpose Tag Chips -->
    <g transform="translate(48, 1190)">
      <text x="12" y="40" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">Quick Purpose Tag</text>
      
      <!-- Chip 1 (Selected) -->
      <g transform="translate(0, 65)">
        <rect width="320" height="74" rx="26" fill="#F59E0B" />
        <text x="160" y="47" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="800" fill="#0F172A">✓ Materials Pickup</text>
      </g>
      <!-- Chip 2 -->
      <g transform="translate(340, 65)">
        <rect width="330" height="74" rx="26" fill="#1E293B" stroke="#475569" stroke-width="2" />
        <text x="505" y="47" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#F8FAFC">Between Jobsites</text>
      </g>
      <!-- Chip 3 -->
      <g transform="translate(690, 65)">
        <rect width="320" height="74" rx="26" fill="#1E293B" stroke="#475569" stroke-width="2" />
        <text x="850" y="47" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#F8FAFC">Tool Transport</text>
      </g>

      <!-- Row 2 -->
      <g transform="translate(0, 160)">
        <rect width="300" height="74" rx="26" fill="#1E293B" stroke="#475569" stroke-width="2" />
        <text x="150" y="47" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#F8FAFC">Client Meeting</text>
      </g>
      <g transform="translate(320, 160)">
        <rect width="310" height="74" rx="26" fill="#1E293B" stroke="#475569" stroke-width="2" />
        <text x="475" y="47" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#F8FAFC">Site Inspection</text>
      </g>
      <g transform="translate(650, 160)">
        <rect width="360" height="74" rx="26" fill="#1E293B" stroke="#475569" stroke-width="2" />
        <text x="830" y="47" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#F8FAFC">Emergency Callout</text>
      </g>
    </g>

    <!-- Save & Confirm CTA Button -->
    <g transform="translate(48, 1490)">
      <rect width="1032" height="120" rx="36" fill="url(#mintGrad)" />
      <text x="516" y="73" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="800" fill="#FFFFFF">Save &amp; Add to Tax Deduction ➔</text>
    </g>
  </g>

  <!-- Legal Disclaimer -->
  <text x="660" y="2755" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="400" fill="#64748B">
    Under ATO rules, travel between home and normal workplace is generally private. Travel between jobsites or transporting bulky tools is eligible. Verify your travel circumstances.
  </text>
</svg>"""

def generate_slide_3():
    """Slide 3: '5,000 km cap, handled' (Live quota progress)"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}">
  {SVG_DEFS}
  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#bgGrad)" />
  <circle cx="660" cy="1050" r="450" fill="#10B981" opacity="0.10" filter="url(#amberGlow)" />

  <!-- Top Pill Badge -->
  <g transform="translate(96, 150)">
    <rect width="470" height="64" rx="32" fill="#ECFDF5" />
    <circle cx="36" cy="32" r="10" fill="#10B981" />
    <text x="58" y="42" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="26" font-weight="800" fill="#059669" letter-spacing="1.5">ATO CAP INTELLIGENCE</text>
  </g>

  <!-- Headline -->
  <text x="96" y="295" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#FFFFFF" letter-spacing="-1.5">5,000 km cap, handled.</text>
  <text x="96" y="390" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#10B981" letter-spacing="-1.5">Never leave money behind.</text>

  <!-- Subheadline -->
  <text x="96" y="465" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="36" font-weight="500" fill="#94A3B8" letter-spacing="-0.2">Real-time quota monitoring prevents unexpected tax office surprises.</text>

  <!-- App Card -->
  <g transform="translate(96, 550)" filter="url(#cardShadow)">
    <rect width="1128" height="2060" rx="64" fill="url(#cardGrad)" stroke="#334155" stroke-width="2" />

    <!-- Big Circular Cap Dial Card -->
    <g transform="translate(48, 60)" filter="url(#softShadow)">
      <rect width="1032" height="740" rx="40" fill="url(#innerCardGrad)" stroke="#475569" stroke-width="2" />
      <text x="516" y="65" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="26" font-weight="800" fill="#94A3B8" letter-spacing="2">2026–27 ANNUAL QUOTA MONITOR</text>

      <!-- Gauge Arc / Circle Center at (516, 280) -->
      <!-- Background Track (Circumference ~ 942) -->
      <circle cx="516" cy="280" r="160" fill="none" stroke="#0F172A" stroke-width="36" />
      <!-- Active Gauge 83.6% filled (stroke-dasharray="840 1000") -->
      <circle cx="516" cy="280" r="160" fill="none" stroke="url(#mintGrad)" stroke-width="36" stroke-linecap="round" stroke-dasharray="840 1005" transform="rotate(-90 516 280)" />

      <!-- Center Big Metric -->
      <text x="516" y="270" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="88" font-weight="900" fill="#FFFFFF" letter-spacing="-2">4,180</text>
      <text x="516" y="325" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="700" fill="#94A3B8">/ 5,000 km</text>
      <text x="516" y="375" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="26" font-weight="800" fill="#10B981">83.6% CLAIMED</text>

      <!-- Bottom Status Pill -->
      <g transform="translate(116, 490)">
        <rect width="800" height="90" rx="30" fill="#0F172A" stroke="#334155" stroke-width="1.5" />
        <text x="400" y="55" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F59E0B">🎯 820 km remaining before hitting cap</text>
      </g>
      
      <!-- Two Pillar Telemetry Stats -->
      <g transform="translate(70, 610)">
        <rect width="420" height="90" rx="24" fill="#152033" />
        <text x="30" y="40" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="22" font-weight="700" fill="#94A3B8">Claimed to Date</text>
        <text x="30" y="75" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="32" font-weight="900" fill="#10B981">$3,803.80</text>
      </g>
      <g transform="translate(542, 610)">
        <rect width="420" height="90" rx="24" fill="#152033" />
        <text x="30" y="40" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="22" font-weight="700" fill="#94A3B8">Remaining Value</text>
        <text x="30" y="75" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="32" font-weight="900" fill="#F59E0B">$746.20</text>
      </g>
    </g>

    <!-- Multi-Vehicle Cap Allocation -->
    <g transform="translate(48, 840)">
      <text x="12" y="40" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="800" fill="#F8FAFC">Registered Vehicles (Separate Caps)</text>
      
      <!-- Vehicle 1: Ute -->
      <g transform="translate(0, 70)">
        <rect width="1032" height="170" rx="30" fill="#152033" stroke="#334155" stroke-width="1.5" />
        <text x="40" y="58" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">2024 Toyota HiLux (Primary Ute)</text>
        <text x="40" y="100" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#94A3B8">4,180 / 5,000 km logged · 820 km left</text>
        <g transform="translate(40, 120)">
          <rect width="750" height="16" rx="8" fill="#0F172A" />
          <rect width="627" height="16" rx="8" fill="url(#mintGrad)" />
        </g>
        <text x="980" y="95" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="900" fill="#10B981">$3,803</text>
      </g>

      <!-- Vehicle 2: Van -->
      <g transform="translate(0, 265)">
        <rect width="1032" height="170" rx="30" fill="#152033" stroke="#334155" stroke-width="1.5" />
        <text x="40" y="58" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">2023 Toyota HiAce (Work Van)</text>
        <text x="40" y="100" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="600" fill="#94A3B8">1,420 / 5,000 km logged · 3,580 km left</text>
        <g transform="translate(40, 120)">
          <rect width="750" height="16" rx="8" fill="#0F172A" />
          <rect width="213" height="16" rx="8" fill="url(#amberGrad)" />
        </g>
        <text x="980" y="95" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="900" fill="#F59E0B">$1,292</text>
      </g>
    </g>

    <!-- Info Callout Banner -->
    <g transform="translate(48, 1320)">
      <rect width="1032" height="150" rx="30" fill="#1E293B" stroke="#10B981" stroke-width="2" />
      <text x="40" y="60" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="30" font-weight="800" fill="#10B981">💡 ATO Rule Multiplier</text>
      <text x="40" y="102" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#CBD5E1">Each car you own or lease gets its own separate 5,000 km cap ($4,550 each).</text>
    </g>
  </g>

  <!-- Legal Disclaimer -->
  <text x="660" y="2755" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="400" fill="#64748B">
    The ATO Cents per Kilometre method allows up to 5,000 business km per vehicle, per income year. Multiple vehicles have separate 5,000 km caps if owned or leased by eligible taxpayers.
  </text>
</svg>"""

def generate_slide_4():
    """Slide 4: 'Compare claim methods' (CPK vs Logbook potential)"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}">
  {SVG_DEFS}
  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#bgGrad)" />
  <circle cx="660" cy="1150" r="450" fill="#F59E0B" opacity="0.10" filter="url(#amberGlow)" />

  <!-- Top Pill Badge -->
  <g transform="translate(96, 150)">
    <rect width="520" height="64" rx="32" fill="#FEF3C7" />
    <circle cx="36" cy="32" r="10" fill="#D97706" />
    <text x="58" y="42" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="26" font-weight="800" fill="#B45309" letter-spacing="1.5">CLAIM ARBITRAGE · MAXIMISE REFUND</text>
  </g>

  <!-- Headline -->
  <text x="96" y="295" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#FFFFFF" letter-spacing="-1.5">Compare claim methods.</text>
  <text x="96" y="390" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#F59E0B" letter-spacing="-1.5">See what pays you more.</text>

  <!-- Subheadline -->
  <text x="96" y="465" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="36" font-weight="500" fill="#94A3B8" letter-spacing="-0.2">Side-by-side comparison of Cents-per-Km vs Actual Logbook expenses.</text>

  <!-- App Card -->
  <g transform="translate(96, 550)" filter="url(#cardShadow)">
    <rect width="1128" height="2060" rx="64" fill="url(#cardGrad)" stroke="#334155" stroke-width="2" />

    <!-- Arbitrage Winner Banner -->
    <g transform="translate(48, 60)" filter="url(#softShadow)">
      <rect width="1032" height="150" rx="32" fill="#FEF3C7" stroke="#F59E0B" stroke-width="3" />
      <text x="48" y="65" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="38" font-weight="900" fill="#92400E">💰 +$7,387.28 Extra Deduction Found!</text>
      <text x="48" y="108" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="25" font-weight="600" fill="#B45309">Switching from Cents-per-Km to a 12-week Logbook more than doubles your claim.</text>
    </g>

    <!-- Side-by-Side Comparison Columns -->
    <g transform="translate(48, 245)">
      <!-- Left Column: Cents per Km -->
      <g transform="translate(0, 0)">
        <rect width="500" height="740" rx="36" fill="#152033" stroke="#334155" stroke-width="2" />
        <rect x="36" y="36" width="160" height="44" rx="22" fill="#0F172A" />
        <text x="116" y="66" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="20" font-weight="700" fill="#94A3B8">STANDARD</text>
        <text x="36" y="130" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">Cents per Km</text>
        
        <!-- Big Number -->
        <text x="36" y="215" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="64" font-weight="900" fill="#F59E0B">$4,550</text>
        <text x="36" y="255" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="600" fill="#94A3B8">Maximum statutory cap</text>

        <!-- Feature List -->
        <line x1="36" y1="285" x2="464" y2="285" stroke="#334155" stroke-width="1.5" />
        <text x="36" y="340" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#CBD5E1">✓ 5,000 km quota max</text>
        <text x="36" y="400" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#CBD5E1">✓ No receipts needed</text>
        <text x="36" y="460" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#CBD5E1">✓ Simple diary record</text>
        <text x="36" y="520" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#EF4444">✕ Leaves excess km unclaimed</text>
        <text x="36" y="580" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#EF4444">✕ No vehicle depreciation</text>
      </g>

      <!-- Right Column: Logbook Method (WINNER) -->
      <g transform="translate(532, 0)" filter="url(#softShadow)">
        <rect width="500" height="740" rx="36" fill="#1E293B" stroke="#10B981" stroke-width="3" />
        <rect x="36" y="36" width="160" height="44" rx="22" fill="#ECFDF5" />
        <text x="116" y="66" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="20" font-weight="800" fill="#059669">HIGHER RETURN</text>
        <text x="36" y="130" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">Logbook Method</text>
        
        <!-- Big Number -->
        <text x="36" y="215" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="64" font-weight="900" fill="#10B981">$11,937</text>
        <text x="36" y="255" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="600" fill="#10B981">78.4% Business Use</text>

        <!-- Feature List -->
        <line x1="36" y1="285" x2="464" y2="285" stroke="#334155" stroke-width="1.5" />
        <text x="36" y="340" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#CBD5E1">✓ 18,400 total km tracked</text>
        <text x="36" y="400" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#CBD5E1">✓ Fuel &amp; servicing: $8,420</text>
        <text x="36" y="460" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#CBD5E1">✓ Ute depreciation: $6,800</text>
        <text x="36" y="520" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#10B981">✓ Valid for 5 full tax years</text>
        <text x="36" y="580" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#10B981">✓ ATO compliant 12 weeks</text>
      </g>
    </g>

    <!-- Detailed Expense Breakdown Card -->
    <g transform="translate(48, 1020)">
      <rect width="1032" height="260" rx="32" fill="#152033" stroke="#334155" stroke-width="1.5" />
      <text x="40" y="50" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="28" font-weight="800" fill="#F8FAFC">Actual Work Expense Breakdown (Logbook)</text>
      
      <g transform="translate(40, 80)">
        <text x="0" y="30" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#94A3B8">Diesel &amp; AdBlue</text>
        <text x="450" y="30" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" font-weight="700" fill="#F8FAFC">$4,620</text>
        <text x="520" y="30" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#94A3B8">Registration &amp; CTP</text>
        <text x="940" y="30" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" font-weight="700" fill="#F8FAFC">$1,150</text>
        
        <text x="0" y="80" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#94A3B8">Commercial Insurance</text>
        <text x="450" y="80" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" font-weight="700" fill="#F8FAFC">$1,850</text>
        <text x="520" y="80" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#94A3B8">Servicing &amp; Tyres</text>
        <text x="940" y="80" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" font-weight="700" fill="#F8FAFC">$800</text>

        <text x="0" y="130" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" fill="#94A3B8">Decline in Value (Depreciation)</text>
        <text x="940" y="130" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" font-weight="800" fill="#10B981">$6,800</text>
      </g>
    </g>

    <!-- Action CTA Button -->
    <g transform="translate(48, 1320)">
      <rect width="1032" height="120" rx="36" fill="url(#mintGrad)" />
      <text x="516" y="73" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="34" font-weight="800" fill="#FFFFFF">Start 12-Week Logbook Mode ➔</text>
    </g>
  </g>

  <!-- Legal Disclaimer -->
  <text x="660" y="2755" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="400" fill="#64748B">
    *Logbook comparison is illustrative. Actual claims depend on real vehicle operating expenses, genuine business percentage, and valid tax receipts. Consult your registered accountant.
  </text>
</svg>"""

def generate_slide_5():
    """Slide 5: 'Accountant-ready export' (1-tap ATO CSV & PDF pack)"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}">
  {SVG_DEFS}
  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#bgGrad)" />
  <circle cx="660" cy="1100" r="450" fill="#10B981" opacity="0.10" filter="url(#amberGlow)" />

  <!-- Top Pill Badge -->
  <g transform="translate(96, 150)">
    <rect width="490" height="64" rx="32" fill="#EFF6FF" />
    <circle cx="36" cy="32" r="10" fill="#2563EB" />
    <text x="58" y="42" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="26" font-weight="800" fill="#1E40AF" letter-spacing="1.5">EOFY TAX PACK · 1-TAP SHARE</text>
  </g>

  <!-- Headline -->
  <text x="96" y="295" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#FFFFFF" letter-spacing="-1.5">Accountant-ready export.</text>
  <text x="96" y="390" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#10B981" letter-spacing="-1.5">Done in 5 seconds.</text>

  <!-- Subheadline -->
  <text x="96" y="465" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="36" font-weight="500" fill="#94A3B8" letter-spacing="-0.2">Full ATO ITAA 1997 Division 28 audit log in clean CSV &amp; formatted PDF.</text>

  <!-- App Card -->
  <g transform="translate(96, 550)" filter="url(#cardShadow)">
    <rect width="1128" height="2060" rx="64" fill="url(#cardGrad)" stroke="#334155" stroke-width="2" />

    <!-- Export Document Sheet Modal Preview -->
    <g transform="translate(48, 60)" filter="url(#softShadow)">
      <rect width="1032" height="880" rx="36" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="2" />
      
      <!-- PDF Document Header -->
      <g transform="translate(48, 50)">
        <text x="0" y="40" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="38" font-weight="900" fill="#0F172A">KILOTAX AUDIT REPORT</text>
        <text x="0" y="75" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="600" fill="#64748B">ATO CENTS PER KM COMPLIANCE DOSSIER • 2026–27 FINANCIAL YEAR</text>
        <rect x="740" y="0" width="190" height="40" rx="10" fill="#ECFDF5" />
        <text x="835" y="27" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="18" font-weight="800" fill="#059669">AUDIT CERTIFIED</text>
      </g>

      <!-- Key Metadata Grid in PDF -->
      <g transform="translate(48, 160)">
        <rect width="936" height="130" rx="20" fill="#F8FAFC" stroke="#E2E8F0" />
        <text x="30" y="45" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#64748B">Taxpayer Vehicle</text>
        <text x="30" y="80" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="26" font-weight="800" fill="#0F172A">2024 Toyota HiLux (1TR-8DE)</text>
        
        <text x="400" y="45" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#64748B">Total Work Km</text>
        <text x="400" y="80" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="26" font-weight="800" fill="#0F172A">4,890.0 km</text>

        <text x="680" y="45" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#64748B">Total Claim Amount</text>
        <text x="680" y="80" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="28" font-weight="900" fill="#059669">$4,449.90</text>
      </g>

      <!-- Clean Tax Table Preview -->
      <g transform="translate(48, 330)">
        <!-- Table Header -->
        <rect width="936" height="48" fill="#EDF2F7" />
        <text x="20" y="32" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="18" font-weight="800" fill="#475569">DATE</text>
        <text x="180" y="32" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="18" font-weight="800" fill="#475569">JOURNEY PURPOSE</text>
        <text x="560" y="32" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="18" font-weight="800" fill="#475569">DISTANCE</text>
        <text x="740" y="32" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="18" font-weight="800" fill="#475569">RATE</text>
        <text x="910" y="32" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="18" font-weight="800" fill="#475569">CLAIM</text>

        <!-- Table Row 1 -->
        <line x1="0" y1="90" x2="936" y2="90" stroke="#E2E8F0" />
        <text x="20" y="78" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">28/05/2027</text>
        <text x="180" y="78" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">Bunnings ➔ Jobsite Bardon (Supplies)</text>
        <text x="560" y="78" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">34.2 km</text>
        <text x="740" y="78" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">91c</text>
        <text x="910" y="78" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="800" fill="#0F172A">$31.12</text>

        <!-- Table Row 2 -->
        <line x1="0" y1="140" x2="936" y2="140" stroke="#E2E8F0" />
        <text x="20" y="128" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">29/05/2027</text>
        <text x="180" y="128" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">Reece Plumbing ➔ Client Site</text>
        <text x="560" y="128" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">18.5 km</text>
        <text x="740" y="128" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">91c</text>
        <text x="910" y="128" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="800" fill="#0F172A">$16.84</text>

        <!-- Table Row 3 -->
        <line x1="0" y1="190" x2="936" y2="190" stroke="#E2E8F0" />
        <text x="20" y="178" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">02/06/2027</text>
        <text x="180" y="178" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">Commercial Electrical Inspection</text>
        <text x="560" y="178" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">42.0 km</text>
        <text x="740" y="178" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="600" fill="#0F172A">91c</text>
        <text x="910" y="178" text-anchor="end" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="800" fill="#0F172A">$38.22</text>
      </g>
    </g>

    <!-- File Format Checkboxes -->
    <g transform="translate(48, 990)">
      <rect width="1032" height="150" rx="30" fill="#152033" stroke="#334155" stroke-width="1.5" />
      <g transform="translate(50, 45)">
        <circle cx="25" cy="30" r="20" fill="#10B981" />
        <path d="M16 30 L22 36 L34 24" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
        <text x="65" y="38" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="26" font-weight="700" fill="#F8FAFC">ATO Division 28 CSV</text>
      </g>
      <g transform="translate(540, 45)">
        <circle cx="25" cy="30" r="20" fill="#10B981" />
        <path d="M16 30 L22 36 L34 24" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
        <text x="65" y="38" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="26" font-weight="700" fill="#F8FAFC">Accountant PDF Summary</text>
      </g>
    </g>

    <!-- Big Action Button -->
    <g transform="translate(48, 1180)">
      <rect width="1032" height="130" rx="36" fill="url(#mintGrad)" />
      <text x="516" y="80" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="36" font-weight="900" fill="#FFFFFF">Share Tax Pack with Accountant ➔</text>
    </g>

    <!-- Share Channels -->
    <g transform="translate(48, 1360)">
      <text x="516" y="40" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="24" font-weight="600" fill="#94A3B8">AirDrop • Apple Mail • Save to Files • Direct to Xero / MYOB</text>
    </g>
  </g>

  <!-- Legal Disclaimer -->
  <text x="660" y="2755" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="400" fill="#64748B">
    Records generated adhere to ATO record-keeping requirements under Section 900-115 of ITAA 1997. KiloTax is not affiliated with the Australian Taxation Office.
  </text>
</svg>"""

def generate_slide_6():
    """Slide 6: 'Private by design' (Local-first, no account required)"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}">
  {SVG_DEFS}
  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#bgGrad)" />
  <circle cx="660" cy="1000" r="450" fill="#F59E0B" opacity="0.10" filter="url(#amberGlow)" />

  <!-- Top Pill Badge -->
  <g transform="translate(96, 150)">
    <rect width="500" height="64" rx="32" fill="#ECFDF5" />
    <circle cx="36" cy="32" r="10" fill="#10B981" />
    <text x="58" y="42" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="26" font-weight="800" fill="#059669" letter-spacing="1.5">LOCAL-FIRST PRIVACY · ZERO ADS</text>
  </g>

  <!-- Headline -->
  <text x="96" y="295" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#FFFFFF" letter-spacing="-1.5">Private by design.</text>
  <text x="96" y="390" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="82" font-weight="900" fill="#F59E0B" letter-spacing="-1.5">Your data stays on your phone.</text>

  <!-- Subheadline -->
  <text x="96" y="465" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="36" font-weight="500" fill="#94A3B8" letter-spacing="-0.2">No mandatory account. No cloud tracking. No data brokers.</text>

  <!-- App Card -->
  <g transform="translate(96, 550)" filter="url(#cardShadow)">
    <rect width="1128" height="2060" rx="64" fill="url(#cardGrad)" stroke="#334155" stroke-width="2" />

    <!-- Shield Vault Graphic Box -->
    <g transform="translate(48, 60)" filter="url(#softShadow)">
      <rect width="1032" height="480" rx="40" fill="url(#innerCardGrad)" stroke="#475569" stroke-width="2" />
      
      <!-- Center Shield Emblem -->
      <g transform="translate(516, 180)">
        <circle cx="0" cy="0" r="110" fill="#0F172A" stroke="#F59E0B" stroke-width="4" />
        <!-- Shield Path -->
        <path d="M 0 -60 Q 45 -45 55 10 C 55 55 25 80 0 95 C -25 80 -55 55 -55 10 Q -45 -45 0 -60 Z" fill="none" stroke="#F59E0B" stroke-width="8" stroke-linejoin="round" />
        <circle cx="0" cy="10" r="16" fill="#10B981" />
      </g>

      <text x="516" y="360" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="44" font-weight="900" fill="#F8FAFC">100% Local-First Storage</text>
      <text x="516" y="415" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="26" font-weight="500" fill="#94A3B8">Your trip GPS routes and financial records never leave your iPhone.</text>
    </g>

    <!-- Privacy Guarantees Grid -->
    <g transform="translate(48, 590)">
      <!-- Item 1 -->
      <g transform="translate(0, 0)">
        <rect width="1032" height="150" rx="28" fill="#152033" stroke="#334155" stroke-width="1.5" />
        <circle cx="70" cy="75" r="30" fill="#ECFDF5" />
        <text x="70" y="85" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="28">✓</text>
        <text x="135" y="65" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">No Account Required (Guest Mode)</text>
        <text x="135" y="105" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Start logging work kilometres immediately with zero registration.</text>
      </g>

      <!-- Item 2 -->
      <g transform="translate(0, 180)">
        <rect width="1032" height="150" rx="28" fill="#152033" stroke="#334155" stroke-width="1.5" />
        <circle cx="70" cy="75" r="30" fill="#ECFDF5" />
        <text x="70" y="85" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="28">✓</text>
        <text x="135" y="65" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">Zero Telematics Spyware</text>
        <text x="135" y="105" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">We never track personal trips or sell driving telemetry to insurers.</text>
      </g>

      <!-- Item 3 -->
      <g transform="translate(0, 360)">
        <rect width="1032" height="150" rx="28" fill="#152033" stroke="#334155" stroke-width="1.5" />
        <circle cx="70" cy="75" r="30" fill="#ECFDF5" />
        <text x="70" y="85" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="28">✓</text>
        <text x="135" y="65" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">1-Tap Complete Data Erasure</text>
        <text x="135" y="105" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Export or permanently erase all your records anytime with one tap.</text>
      </g>

      <!-- Item 4 -->
      <g transform="translate(0, 540)">
        <rect width="1032" height="150" rx="28" fill="#152033" stroke="#334155" stroke-width="1.5" />
        <circle cx="70" cy="75" r="30" fill="#EFF6FF" />
        <text x="70" y="85" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="28">☁️</text>
        <text x="135" y="65" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">Optional Encrypted Cloud Backup</text>
        <text x="135" y="105" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Sign In with Apple when you want seamless multi-device sync.</text>
      </g>
    </g>

    <!-- Aussie Seal Banner -->
    <g transform="translate(48, 1350)">
      <rect width="1032" height="150" rx="32" fill="#1E293B" stroke="#F59E0B" stroke-width="2" />
      <text x="516" y="65" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="32" font-weight="800" fill="#F8FAFC">🇦🇺 Designed &amp; Engineered for Aussie Tradies</text>
      <text x="516" y="108" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="24" font-weight="500" fill="#94A3B8">Strictly compliant with Australian Privacy Principles &amp; ATO Rules</text>
    </g>
  </g>

  <!-- Legal Disclaimer -->
  <text x="660" y="2755" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif" font-size="22" font-weight="400" fill="#64748B">
    All trip logs and tax calculations are processed on your device. Optional cloud backup is encrypted. KiloTax never sells user location data.
  </text>
</svg>"""

SLIDES = [
    ("slide_1_hero_km.svg", generate_slide_1),
    ("slide_2_toggle.svg", generate_slide_2),
    ("slide_3_cap_handled.svg", generate_slide_3),
    ("slide_4_compare_methods.svg", generate_slide_4),
    ("slide_5_export_taxpack.svg", generate_slide_5),
    ("slide_6_private_local.svg", generate_slide_6),
]

for filename, generator in SLIDES:
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(generator())
    print(f"Generated: {path}")

# Now generate an interactive HTML preview gallery
HTML_GALLERY = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>KiloTax App Store Screenshots Inspector (6.9" Display)</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #020617;
      color: #F8FAFC;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      padding: 24px;
    }
    header {
      max-width: 1400px;
      margin: 0 auto 30px;
      padding: 24px;
      background: #0F172A;
      border: 1px solid #334155;
      border-radius: 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
    }
    h1 {
      font-size: 26px;
      font-weight: 800;
      color: #F59E0B;
    }
    .specs-badge {
      display: inline-flex;
      gap: 8px;
    }
    .badge {
      background: #1E293B;
      color: #94A3B8;
      padding: 6px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      border: 1px solid #334155;
    }
    .badge-amber {
      background: #FEF3C7;
      color: #B45309;
      border-color: #F59E0B;
    }
    .badge-mint {
      background: #ECFDF5;
      color: #059669;
      border-color: #10B981;
    }
    .controls {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    label {
      font-size: 14px;
      color: #94A3B8;
    }
    select {
      background: #1E293B;
      color: #F8FAFC;
      border: 1px solid #475569;
      padding: 8px 12px;
      border-radius: 8px;
      font-size: 14px;
      outline: none;
    }
    .gallery {
      display: flex;
      gap: 32px;
      overflow-x: auto;
      padding-bottom: 40px;
      max-width: 100%;
    }
    .slide-wrapper {
      flex: 0 0 auto;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .slide-meta {
      margin-bottom: 12px;
      text-align: center;
    }
    .slide-num {
      font-size: 14px;
      font-weight: 700;
      color: #F59E0B;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .slide-title {
      font-size: 16px;
      font-weight: 600;
      color: #F8FAFC;
    }
    .slide-canvas {
      width: 330px; /* 1320 * 0.25 */
      height: 717px; /* 2868 * 0.25 */
      border-radius: 18px;
      overflow: hidden;
      box-shadow: 0 20px 40px rgba(0,0,0,0.8);
      border: 1px solid #334155;
      background: #0F172A;
      transition: transform 0.2s ease;
    }
    .slide-canvas img {
      width: 100%;
      height: 100%;
      display: block;
    }
    .slide-canvas:hover {
      transform: translateY(-4px);
      border-color: #F59E0B;
    }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>KiloTax App Store Screenshots (6.9" Display)</h1>
      <p style="color: #94A3B8; font-size: 14px; margin-top: 4px;">iPhone 16 Pro Max / 17 Pro Max / 18 Pro Max • Native 1320 × 2868 px</p>
    </div>
    <div class="specs-badge">
      <span class="badge badge-amber">Aussie Tradie High-Vis</span>
      <span class="badge badge-mint">ATO 91¢/km Cap Handled</span>
      <span class="badge">No Fake Hardware Bezels</span>
      <span class="badge">Zero Alpha Channel</span>
    </div>
    <div class="controls">
      <label for="scaleSelect">Zoom Scale:</label>
      <select id="scaleSelect" onchange="updateScale(this.value)">
        <option value="0.25" selected>25% (330 × 717 px)</option>
        <option value="0.33">33% (435 × 946 px)</option>
        <option value="0.50">50% (660 × 1434 px)</option>
        <option value="1.00">100% (1320 × 2868 px)</option>
      </select>
    </div>
  </header>

  <div class="gallery" id="gallery">
    <div class="slide-wrapper">
      <div class="slide-meta">
        <div class="slide-num">Slide 1 · The Hook</div>
        <div class="slide-title">Track every work km ($4,550 Claim)</div>
      </div>
      <div class="slide-canvas">
        <img src="slide_1_hero_km.svg" alt="Slide 1">
      </div>
    </div>

    <div class="slide-wrapper">
      <div class="slide-meta">
        <div class="slide-num">Slide 2 · 1-Tap Fast Toggle</div>
        <div class="slide-title">Business or private? Sorted.</div>
      </div>
      <div class="slide-canvas">
        <img src="slide_2_toggle.svg" alt="Slide 2">
      </div>
    </div>

    <div class="slide-wrapper">
      <div class="slide-meta">
        <div class="slide-num">Slide 3 · Live Cap Gauge</div>
        <div class="slide-title">5,000 km cap, handled.</div>
      </div>
      <div class="slide-canvas">
        <img src="slide_3_cap_handled.svg" alt="Slide 3">
      </div>
    </div>

    <div class="slide-wrapper">
      <div class="slide-meta">
        <div class="slide-num">Slide 4 · Method Arbitrage</div>
        <div class="slide-title">Compare claim methods (+$7k)</div>
      </div>
      <div class="slide-canvas">
        <img src="slide_4_compare_methods.svg" alt="Slide 4">
      </div>
    </div>

    <div class="slide-wrapper">
      <div class="slide-meta">
        <div class="slide-num">Slide 5 · EOFY Compliance</div>
        <div class="slide-title">Accountant-ready export (5s)</div>
      </div>
      <div class="slide-canvas">
        <img src="slide_5_export_taxpack.svg" alt="Slide 5">
      </div>
    </div>

    <div class="slide-wrapper">
      <div class="slide-meta">
        <div class="slide-num">Slide 6 · Local First</div>
        <div class="slide-title">Private by design (No sign-up)</div>
      </div>
      <div class="slide-canvas">
        <img src="slide_6_private_local.svg" alt="Slide 6">
      </div>
    </div>
  </div>

  <script>
    function updateScale(val) {
      const scale = parseFloat(val);
      const w = 1320 * scale;
      const h = 2868 * scale;
      document.querySelectorAll('.slide-canvas').forEach(canvas => {
        canvas.style.width = w + 'px';
        canvas.style.height = h + 'px';
      });
    }
  </script>
</body>
</html>
"""

html_path = os.path.join(OUTPUT_DIR, "index.html")
with open(html_path, "w", encoding="utf-8") as f:
    f.write(HTML_GALLERY)
print(f"Generated HTML preview studio: {html_path}")
