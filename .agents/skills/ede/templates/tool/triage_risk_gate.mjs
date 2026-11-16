#!/usr/bin/env node
/**
 * EDE Risk-Tier Triage Gate (Node.js / TypeScript Template)
 * Automated CLI tool to evaluate file paths and classify changes into Tier 1 (Full EDE) vs Tier 2 (Fast-Track).
 */
import { execSync } from 'child_process';
import process from 'process';

function getChangedFiles(args) {
  if (args.length > 0) return args;

  try {
    const gitDiff = execSync('git diff --name-only HEAD~1', { encoding: 'utf-8' });
    if (gitDiff.trim()) {
      return gitDiff.split('\n').map(s => s.trim()).filter(Boolean);
    }
  } catch (_) {}

  try {
    const gitStatus = execSync('git status --porcelain', { encoding: 'utf-8' });
    return gitStatus
      .split('\n')
      .map(s => s.trim())
      .filter(s => s.length > 3)
      .map(s => s.substring(3).trim());
  } catch (_) {
    return [];
  }
}

export function classifyRisk(files) {
  const criticalPatterns = [
    /^(src|lib)\/(services|engine|core|domain)\/.*(tax|audit|calc|ledger|payment|billing|auth).*/i,
    /^(src|lib)\/(models|entities|schemas)\/.*/i,
    /^(src|lib|db)\/(database|migrations|repositories)\/.*/i,
    /^(tool|scripts)\/ede\/.*/i,
  ];

  const critical = [];
  const standard = [];

  for (const file of files) {
    const normalized = file.replace(/\\/g, '/');
    const isCrit = criticalPatterns.some(pattern => pattern.test(normalized));
    if (isCrit) {
      critical.push(file);
    } else {
      standard.push(file);
    }
  }

  return {
    isTier1: critical.length > 0,
    criticalFiles: critical,
    standardFiles: standard,
  };
}

function main() {
  const files = getChangedFiles(process.argv.slice(2));
  const verdict = classifyRisk(files);

  console.log('========================================');
  console.log('EDE Risk-Tier Triage Gate (Node.js)');
  console.log('========================================');
  console.log(`Verdict: ${verdict.isTier1 ? 'TIER 1 (High Stakes - Full EDE Required)' : 'TIER 2 (Fast-Track Permitted)'}`);
  console.log('----------------------------------------');
  if (verdict.criticalFiles.length > 0) {
    console.log('Critical Path Files Triggered:');
    verdict.criticalFiles.forEach(f => console.log(`  [!] ${f}`));
  }
  if (verdict.standardFiles.length > 0) {
    console.log('Standard/Presentation Files:');
    verdict.standardFiles.forEach(f => console.log(`  [-] ${f}`));
  }
  console.log('----------------------------------------');
  if (verdict.isTier1) {
    console.log('Action: Full Isolated Auditor claim sheet + debate falsification required.');
  } else {
    console.log('Action: Fast-Track permitted (lint + static checks).');
  }
  console.log('========================================');

  process.exit(verdict.isTier1 ? 1 : 0);
}

if (process.argv[1] && process.argv[1].endsWith('triage_risk_gate.mjs')) {
  main();
}
