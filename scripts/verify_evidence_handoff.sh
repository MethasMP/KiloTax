#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .audit/evidence-handoff
flutter test --no-pub --timeout 60s \
  --dart-define="TAX_PACK_SAMPLE_PATH=$PWD/.audit/evidence-handoff/sample-pack.zip" \
  test/services/evidence_review_service_test.dart \
  test/weekly_evidence_review_test.dart \
  test/autonomous_trip_detector_test.dart \
  test/ui/evidence_review_flow_test.dart \
  test/ui/tax_pack_share_flow_test.dart \
  test/tax_pack_builder_test.dart \
  test/tax_email_dispatch_service_test.dart \
  test/services/export/accountant_workpaper_generator_test.dart \
  test/services/engine/accountant_workpaper_generator_test.dart \
  test/receipt_audit_service_test.dart \
  test/services/feedback_draft_test.dart \
  test/ui/feedback_screen_test.dart \
  test/account_settings_sheet_test.dart \
  test/accounting_export_validator_test.dart \
  test/cpk_batch_review_test.dart \
  test/cpk_compliance_ux_test.dart \
  test/cpk_lean_workflow_test.dart \
  test/csv_security_comprehensive_test.dart \
  test/data_persistence_integrity_audit_test.dart \
  test/evidence_engine_test.dart \
  test/export_enhancements_compliance_test.dart \
  test/logbook_privacy_export_test.dart \
  test/security_hardening_test.dart \
  test/services/engine/p0_systems_integrity_test.dart \
  test/services/handitax_d1_export_test.dart \
  test/tax_evidence_engine_wireframe_test.dart \
  test/ui/odometer_gap_journey_test.dart \
  test/pdf_export_service_test.dart \
  test/tax_calculation_scope_test.dart \
  test/tax_calculator_vault_exclusion_test.dart \
  --reporter expanded
DRIVELOG_CAPTURE=1 flutter test --no-pub --timeout 60s \
  test/ui/evidence_handoff_render_test.dart --reporter expanded
