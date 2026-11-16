#!/usr/bin/env python3
"""
EDE Risk-Tier Triage Gate (Python Template)
Automated CLI tool to evaluate file paths and classify changes into Tier 1 (Full EDE) vs Tier 2 (Fast-Track).
"""
import sys
import re
import subprocess

def get_changed_files(args):
    if args:
        return args

    try:
        git_diff = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD~1'], stderr=subprocess.DEVNULL, text=True)
        if git_diff.strip():
            return [line.strip() for line in git_diff.splitlines() if line.strip()]
    except Exception:
        pass

    try:
        git_status = subprocess.check_output(['git', 'status', '--porcelain'], stderr=subprocess.DEVNULL, text=True)
        return [line.strip()[3:].strip() for line in git_status.splitlines() if len(line.strip()) > 3]
    except Exception:
        return []

def classify_risk(files):
    critical_patterns = [
        re.compile(r'^(src|app|services|core|domain)/.*(tax|audit|calc|ledger|payment|billing|auth)', re.IGNORECASE),
        re.compile(r'^(src|app)/(models|schemas|entities)/', re.IGNORECASE),
        re.compile(r'^(src|app|db)/(database|migrations)/', re.IGNORECASE),
        re.compile(r'^(tool|scripts)/ede/', re.IGNORECASE),
    ]

    critical = []
    standard = []

    for f in files:
        normalized = f.replace('\\', '/')
        if any(p.search(normalized) for p in critical_patterns):
            critical.append(f)
        else:
            standard.append(f)

    return {
        'is_tier_1': len(critical) > 0,
        'critical_files': critical,
        'standard_files': standard,
    }

def main():
    files = get_changed_files(sys.argv[1:])
    verdict = classify_risk(files)

    print('========================================')
    print('EDE Risk-Tier Triage Gate (Python)')
    print('========================================')
    print(f"Verdict: {'TIER 1 (High Stakes - Full EDE Required)' if verdict['is_tier_1'] else 'TIER 2 (Fast-Track Permitted)'}")
    print('----------------------------------------')
    if verdict['critical_files']:
        print('Critical Path Files Triggered:')
        for f in verdict['critical_files']:
            print(f'  [!] {f}')
    if verdict['standard_files']:
        print('Standard/Presentation Files:')
        for f in verdict['standard_files']:
            print(f'  [-] {f}')
    print('----------------------------------------')
    if verdict['is_tier_1']:
        print('Action: Full Isolated Auditor claim sheet + debate falsification required.')
    else:
        print('Action: Fast-Track permitted (lint + static checks).')
    print('========================================')

    sys.exit(1 if verdict['is_tier_1'] else 0)

if __name__ == '__main__':
    main()
