import '../../widgets/adaptive_row.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/annual_odometer.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/engine/accountant_handoff_service.dart';
import '../../../services/engine/accounting_export_validator.dart';
import '../../../services/engine/tax_email_dispatch_service.dart';
import '../../../state/app_state.dart';
import '../logbook/logbook_progress_screen.dart';

/// Pre-flight Review Screen
/// Gives the taxpayer 100% confidence before handing off vehicle records to their accountant.
/// Shows:
/// 1. Vehicle & Tax Method summary
/// 2. Pre-flight health checklist (unspecified trips, receipts, odometer continuity)
/// 3. Clear preview of the EXACT 2 deliverable files:
///    - Case 1 (CPK): [Summary_Declaration.pdf] + [Trip_Ledger.csv]
///    - Case 2 (Logbook): [Master_Tax_Report.pdf] + [Tax_Data.xlsx]
/// 4. 1-tap dispatch to Accountant
class PreFlightReviewScreen extends StatefulWidget {
  final AppState appState;
  final Directory? outputDirectory;
  final AccountantHandoffPackage? initialPackage;
  final ValidationResult? validationResult;
  final Future<void> Function()? onExport;

  const PreFlightReviewScreen({
    super.key,
    required this.appState,
    this.outputDirectory,
    this.initialPackage,
    this.validationResult,
    this.onExport,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    Directory? outputDirectory,
    AccountantHandoffPackage? initialPackage,
    ValidationResult? validationResult,
    Future<void> Function()? onExport,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreFlightReviewScreen(
          appState: appState,
          outputDirectory: outputDirectory,
          initialPackage: initialPackage,
          validationResult: validationResult,
          onExport: onExport,
        ),
      ),
    );
  }

  @override
  State<PreFlightReviewScreen> createState() => _PreFlightReviewScreenState();
}

class _PreFlightReviewScreenState extends State<PreFlightReviewScreen> {
  bool _isLoading = false;
  AccountantHandoffPackage? _package;
  late ValidationResult _validationResult;
  final Set<String> _acknowledgedWarningCodes = {};

  bool get _allWarningsAcknowledged =>
      _validationResult.warnings.every((w) => _acknowledgedWarningCodes.contains(w.code));

  bool get _canProceedToExport =>
      _validationResult.canExport && _allWarningsAcknowledged;

  @override
  void initState() {
    super.initState();
    _validationResult = widget.validationResult ??
        const AccountingExportValidator().validate(widget.appState);
    if (widget.initialPackage != null) {
      _package = widget.initialPackage;
      _isLoading = false;
    } else {
      _preparePackage();
    }
  }

  Future<void> _preparePackage() async {
    final vehicle = widget.appState.primaryVehicle;
    if (vehicle == null) return;

    setState(() => _isLoading = true);
    try {
      final tempDir = widget.outputDirectory ?? await getTemporaryDirectory();
      final userProfile = widget.appState.userProfile;
      final taxpayerName = userProfile.taxpayerName?.trim().isNotEmpty == true
          ? userProfile.taxpayerName
          : widget.appState.currentUser?.displayName;
      final abn = userProfile.abn;

      final package = await const AccountantHandoffService().buildPackage(
        vehicle: vehicle,
        taxRule: widget.appState.activeTaxRule,
        trips: widget.appState.trips,
        expenses: widget.appState.expenses,
        outputDirectory: tempDir,
        taxpayerName: taxpayerName,
        abn: abn,
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _package = package;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing tax records: $e')),
        );
      }
    }
  }

  void _revalidate() {
    setState(() {
      _validationResult =
          const AccountingExportValidator().validate(widget.appState);
    });
    if (widget.initialPackage == null) {
      _preparePackage();
    }
  }

  Future<void> _showClosingOdometerDialog() async {
    final vehicle = widget.appState.primaryVehicle;
    if (vehicle == null) return;
    final trips = widget.appState.trips
        .where((t) => !t.isDeleted && t.vehicleId == vehicle.id && t.endOdometer > 0)
        .toList()
      ..sort((a, b) => b.endOdometer.compareTo(a.endOdometer));
    final suggested = trips.isNotEmpty
        ? trips.first.endOdometer
        : vehicle.initialOdometer;

    final savedValue = await showDialog<double>(
      context: context,
      builder: (_) => _ClosingOdometerDialog(initialValue: suggested),
    );

    if (savedValue != null && mounted) {
      final fy = widget.appState.activeTaxRule.financialYear;
      final existing = widget.appState.annualOdometers
          .where((a) => a.vehicleId == vehicle.id && a.financialYear == fy)
          .firstOrNull;
      final record = existing != null
          ? existing.copyWith(
              closingOdometer: savedValue,
              closingDate: DateTime.now(),
            )
          : AnnualVehicleOdometer(
              id: 'odo_${vehicle.id}_$fy',
              vehicleId: vehicle.id,
              financialYear: fy,
              openingDate: DateTime.now(),
              openingOdometer: vehicle.initialOdometer,
              closingDate: DateTime.now(),
              closingOdometer: savedValue,
            );
      widget.appState.recordAnnualOdometer(record);
      _revalidate();
    }
  }

  Future<void> _fixValidationError(String code) async {
    HapticFeedback.lightImpact();
    if (code == 'NO_CLOSING_ODOMETER') {
      await _showClosingOdometerDialog();
    } else if (code == 'NO_TRIPS') {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _fixWarning(String code) async {
    HapticFeedback.lightImpact();
    if (code == 'SHORT_LOGBOOK') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<AppState>.value(
            value: widget.appState,
            child: const LogbookProgressScreen(),
          ),
        ),
      );
      if (mounted) _revalidate();
    }
  }

  Future<void> _handlePreviewPdf() async {
    final pkg = _package;
    if (pkg == null) return;

    HapticFeedback.lightImpact();
    final pdfBytes = await pkg.pdfFile.readAsBytes();
    if (!mounted) return;

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: pkg.pdfFile.uri.pathSegments.last,
    );
  }

  Future<void> _handleConfirmAndSend() async {
    final pkg = _package;
    if (pkg == null) return;

    if (widget.onExport != null) {
      HapticFeedback.mediumImpact();
      setState(() => _isLoading = true);
      try {
        await widget.onExport!();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      Rect? shareOrigin;
      final renderBox = context.findRenderObject();
      if (renderBox is RenderBox && renderBox.hasSize) {
        shareOrigin = renderBox.localToGlobal(Offset.zero) & renderBox.size;
      }

      final dispatchResult = await TaxEmailDispatchService.dispatchTaxPackEmail(
        attachmentPaths: pkg.attachmentPaths,
        subject: pkg.emailSubject,
        body: pkg.emailBody,
        sharePositionOrigin: shareOrigin,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final message = switch (dispatchResult) {
        EmailDispatchResult.sentViaMailApp =>
          'Handed off 2 tax files to your email app.',
        EmailDispatchResult.fallbackToShareSheet =>
          'Shared 2 tax files via share sheet.',
        EmailDispatchResult.failed =>
          'Failed to dispatch files. Please try again.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.deepNavy,
          content: Text(message),
        ),
      );

      if (dispatchResult != EmailDispatchResult.failed) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispatch failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.primaryVehicle;
    final rule = widget.appState.activeTaxRule;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pre-flight Review')),
        body: const Center(child: Text('No active vehicle found.')),
      );
    }

    final isCpk = vehicle.taxMethod == TaxMethod.centsPerKm;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pre-flight Tax Review',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading && _package == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vehicle & Tax Method Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: AdaptiveRow(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.deepNavy,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.car,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle.make} ${vehicle.model}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${vehicle.regoPlate} • FY${rule.financialYear}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isCpk
                                ? AppColors.workBlueLight
                                : AppColors.emeraldLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCpk
                                  ? AppColors.border
                                  : AppColors.emerald.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            isCpk ? 'Cents/KM' : 'Logbook',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCpk
                                  ? AppColors.deepNavy
                                  : AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Claim Estimate Hero Card
                  if (_package != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.deepNavy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdaptiveRow(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ESTIMATED BOX D1 DEDUCTION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Colors.white70,
                                ),
                              ),
                              if (_package!.reviewIssues.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.emerald.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const AdaptiveRow(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.shieldCheck,
                                        size: 13,
                                        color: AppColors.emerald,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '100% ATO Compliant',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.emerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$${_package!.claimAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isCpk
                                ? 'Calculated at ${(rule.centsPerKmRate * 100).toInt()}c/km for ${Formatters.distance(_package!.claimAmount / rule.centsPerKmRate)} (capped at 5,000 km)'
                                : 'Calculated at ${_package!.businessPercentage.toStringAsFixed(1)}% logbook business use across ${_package!.totalExpenses} expense items',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Blocking Validation Errors
                  if (_validationResult.errors.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.alertOctagon, color: AppColors.crimson, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Export Blocked: Fix Errors Before Hand-off',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.crimson,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ..._validationResult.errors.map(
                            (err) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('• ',
                                      style: TextStyle(
                                          color: AppColors.crimson,
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      err.message,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (err.code == 'NO_CLOSING_ODOMETER' ||
                                      err.code == 'NO_TRIPS')
                                    TextButton(
                                      key: Key('fix_error_${err.code}'),
                                      onPressed: () =>
                                          _fixValidationError(err.code),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.crimson,
                                        minimumSize: const Size(48, 48),
                                      ),
                                      child: const Text(
                                        'Fix Now',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Compliance Warnings (require user acknowledgement)
                  if (_validationResult.warnings.isNotEmpty) ...[
                    ..._validationResult.warnings.map(
                      (warn) => Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.amber),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.triangleAlert,
                                    color: AppColors.amber, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Compliance Warning',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        warn.message,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: AppColors.amber),
                            Row(
                              children: [
                                Checkbox(
                                  key: Key('warning_ack_${warn.code}'),
                                  value: _acknowledgedWarningCodes.contains(warn.code),
                                  activeColor: AppColors.deepNavy,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _acknowledgedWarningCodes.add(warn.code);
                                      } else {
                                        _acknowledgedWarningCodes.remove(warn.code);
                                      }
                                    });
                                  },
                                ),
                                const Text(
                                  'I understand',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const Spacer(),
                                if (warn.code == 'SHORT_LOGBOOK')
                                  TextButton(
                                    key: Key('fix_warning_${warn.code}'),
                                    onPressed: () => _fixWarning(warn.code),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.amberDark,
                                      minimumSize: const Size(48, 48),
                                    ),
                                    child: const Text(
                                      'View Progress',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Pre-flight Health & Gap Checklist
                  const Text(
                    'Pre-flight Health Checklist',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildChecklistTile(
                          icon: _package?.unspecifiedTripsCount == 0
                              ? LucideIcons.circleCheck
                              : LucideIcons.circleAlert,
                          iconColor: _package?.unspecifiedTripsCount == 0
                              ? AppColors.emerald
                              : AppColors.amber,
                          title: 'Trip Purpose Specificity',
                          subtitle: _package?.unspecifiedTripsCount == 0
                              ? 'All business trips have stated business purpose'
                              : '${_package?.unspecifiedTripsCount} trips have unstated purpose (will be exported as [Unspecified])',
                        ),
                        const Divider(height: 1, indent: 48),
                        if (!isCpk) ...[
                          _buildChecklistTile(
                            icon: _package?.unverifiedReceiptsCount == 0
                                ? LucideIcons.circleCheck
                                : LucideIcons.circleAlert,
                            iconColor: _package?.unverifiedReceiptsCount == 0
                                ? AppColors.emerald
                                : AppColors.brandPrimary,
                            title: 'Digital Tax Invoices Attached',
                            subtitle:
                                '${_package?.verifiedReceiptsCount} of ${_package?.totalExpenses} expenses backed by verified receipts',
                          ),
                          const Divider(height: 1, indent: 48),
                        ],
                        _buildChecklistTile(
                          icon: widget.appState.pendingOdometerGaps.isEmpty
                              ? LucideIcons.circleCheck
                              : LucideIcons.circleAlert,
                          iconColor: widget.appState.pendingOdometerGaps.isEmpty
                              ? AppColors.emerald
                              : AppColors.amber,
                          title: 'Odometer Continuity',
                          subtitle: widget.appState.pendingOdometerGaps.isEmpty
                              ? 'No unexplained odometer gaps detected'
                              : '${widget.appState.pendingOdometerGaps.length} odometer gaps pending review',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Deliverables Preview (The EXACT 2 Files)
                  const Text(
                    'Accountant Deliverables (Exact 2 Files)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  if (_package != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          // File 1: PDF Report
                          _buildFileDeliverableRow(
                            icon: LucideIcons.fileText,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                            fileName: _package!.pdfFile.uri.pathSegments.last,
                            fileDescription: isCpk
                                ? 'ATO Box D1 Summary & Declaration (PDF)'
                                : 'Master Tax Report: 12-Wk Period & D1 401-406 (PDF)',
                            fileSize:
                                '${(_package!.pdfFile.lengthSync() / 1024).toStringAsFixed(0)} KB',
                          ),
                          const Divider(height: 16),
                          // File 2: Data Ledger (XLSX Workbook)
                          _buildFileDeliverableRow(
                            icon: isCpk
                                ? LucideIcons.fileSpreadsheet
                                : LucideIcons.sheet,
                            iconBg: isCpk
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFF0FDF4),
                            iconColor: isCpk
                                ? AppColors.emerald
                                : const Color(0xFF16A34A),
                            fileName: _package!.dataFile.uri.pathSegments.last,
                            fileDescription: isCpk
                                ? '2-Tab Workbook: Summary, Trip Ledger (XLSX)'
                                : '3-Tab Workbook: Summary, Trips, Expenses (XLSX)',
                            fileSize:
                                '${(_package!.dataFile.lengthSync() / 1024).toStringAsFixed(0)} KB',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  AdaptiveRow(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(LucideIcons.eye, size: 16),
                          label: const Text('Preview PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.deepNavy,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handlePreviewPdf,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          key: const Key('export_button'),
                          icon: const Icon(LucideIcons.send, size: 16),
                          label: Text(
                              (_package?.reviewIssues.isNotEmpty ?? true)
                                  ? 'Share draft for review'
                                  : 'Share records'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: (_isLoading || !_canProceedToExport)
                              ? null
                              : _handleConfirmAndSend,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChecklistTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: AdaptiveRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileDeliverableRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String fileName,
    required String fileDescription,
    required String fileSize,
  }) {
    return AdaptiveRow(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                fileDescription,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          fileSize,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _ClosingOdometerDialog extends StatefulWidget {
  final double initialValue;

  const _ClosingOdometerDialog({required this.initialValue});

  @override
  State<_ClosingOdometerDialog> createState() => _ClosingOdometerDialogState();
}

class _ClosingOdometerDialogState extends State<_ClosingOdometerDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue > 0 ? widget.initialValue.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Closing Odometer Reading'),
      content: TextField(
        key: const Key('closing_odometer_input'),
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Odometer (km)',
          hintText: 'e.g. 84250',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('closing_odometer_save'),
          onPressed: () {
            final parsed = double.tryParse(_controller.text.trim());
            if (parsed != null && parsed > 0) {
              Navigator.of(context).pop(parsed);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
