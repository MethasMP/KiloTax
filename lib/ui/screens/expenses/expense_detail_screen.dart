import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/ocr/receipt_audit_service.dart';
import '../../../services/ocr/receipt_intelligence_service.dart';
import '../../../services/ocr/receipt_pre_db_validator.dart';
import '../../../state/app_state.dart';

/// Screen 10: Expense Detail & Substantiation
/// Allows entering and saving real vehicle expenses with receipt evidence.
class ExpenseDetailScreen extends StatefulWidget {
  final AppState appState;
  final String merchant;
  final double amount;
  final String categoryName;
  final DateTime receiptDate;
  final String? receiptImagePath;
  final ReceiptOcrResult? receiptOcrResult;
  final VehicleExpense? existingExpense;

  const ExpenseDetailScreen({
    super.key,
    required this.appState,
    this.merchant = '',
    this.amount = 0.0,
    this.categoryName = 'Materials',
    required this.receiptDate,
    this.receiptImagePath,
    this.receiptOcrResult,
    this.existingExpense,
  });

  static Future<void> show(BuildContext context,
      {required AppState appState, required VehicleExpense expense}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(
          appState: appState,
          merchant: expense.notes ?? expense.category.displayName,
          amount: expense.amount,
          categoryName: expense.category.displayName,
          receiptDate: expense.date,
          receiptImagePath: expense.receiptPath,
          existingExpense: expense,
        ),
      ),
    );
  }

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final ReceiptIntelligenceService _receiptIntelligence =
      const ReceiptIntelligenceService();
  final ReceiptAuditService _receiptAuditService = const ReceiptAuditService();
  final ReceiptPreDbValidator _preDbValidator = const ReceiptPreDbValidator();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _gstController;
  late TextEditingController _notesController;
  late ExpenseCategory _selectedCategory;
  late DateTime _selectedDate;
  String? _imagePath;
  bool _isVaultOnly = false;
  String? _vaultReason;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.merchant);
    _amountController = TextEditingController(
      text: widget.amount > 0 ? widget.amount.toStringAsFixed(2) : '',
    );
    final initialGst = widget.existingExpense?.gstAmount ??
        widget.receiptOcrResult?.gstAmount ??
        (widget.amount > 0 ? (widget.amount / 11.0) : null);
    _gstController = TextEditingController(
      text: initialGst != null ? initialGst.toStringAsFixed(2) : '',
    );
    _notesController =
        TextEditingController(text: widget.existingExpense?.notes ?? '');
    _selectedCategory =
        widget.existingExpense?.category ?? _resolveInitialCategory();
    _selectedDate = widget.existingExpense?.date ?? widget.receiptDate;
    _imagePath = widget.existingExpense?.receiptPath ?? widget.receiptImagePath;
    _isVaultOnly = widget.existingExpense?.isVaultOnly ?? false;
    _vaultReason = widget.existingExpense?.vaultReason;

    _amountController.addListener(_onFieldChanged);
    _gstController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  ExpenseCategory _resolveInitialCategory() {
    final source =
        '${widget.categoryName}\n${widget.merchant}\n${widget.existingExpense?.notes ?? ''}';
    final match = _receiptIntelligence.classify(source);
    return match.category;
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFieldChanged);
    _gstController.removeListener(_onFieldChanged);
    _merchantController.dispose();
    _amountController.dispose();
    _gstController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.deepNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  ReceiptValidationResult _evaluateValidation() {
    final amt = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final gst = double.tryParse(_gstController.text.replaceAll(',', '').trim());
    final ocr = ReceiptOcrResult(
      merchant: _merchantController.text.trim(),
      amount: amt,
      gstAmount: gst,
      date: _selectedDate,
      category: _selectedCategory,
      confidence: widget.receiptOcrResult?.confidence ?? 0.9,
      evidence: widget.receiptOcrResult?.evidence ?? const [],
      rawText: widget.receiptOcrResult?.rawText ?? '',
    );
    return _preDbValidator.validateAndSanitize(
      ocrResult: ocr,
      logbookStartDate: widget.appState.primaryVehicle?.logbookStartDate,
    );
  }

  void _showTacticalGuidanceSheet({
    required BuildContext context,
    required String title,
    required String explanation,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              explanation,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                onPrimary();
              },
              child: Text(
                primaryLabel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onSecondary?.call();
                },
                child: Text(
                  secondaryLabel,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndCommitExpense() async {
    final parsedAmount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.crimson,
          content: Text('Please enter a valid expense amount.'),
        ),
      );
      return;
    }

    final vehicle = widget.appState.primaryVehicle;
    final vehicleName = vehicle != null
        ? (vehicle.make.isNotEmpty ? vehicle.make : vehicle.vehicleType.displayName.toLowerCase())
        : 'vehicle';
    final isCentsPerKm = vehicle?.taxMethod == TaxMethod.centsPerKm;
    final rateCents = widget.appState.taxRuleService.getRateCentsForDate(_selectedDate);

    // 1. Check Cents-per-km method conflict
    final methodConflict = _preDbValidator.checkMethodConflict(
      isCentsPerKm: isCentsPerKm,
      category: _selectedCategory,
      rateCents: rateCents,
      vehicleName: vehicleName,
    );

    if (methodConflict != null && !_isVaultOnly) {
      _showTacticalGuidanceSheet(
        context: context,
        title: methodConflict.title,
        explanation: methodConflict.explanation,
        primaryLabel: methodConflict.primaryActionLabel,
        onPrimary: () {
          setState(() {
            _isVaultOnly = true;
            _vaultReason = 'cents_per_km_running_cost';
          });
          _commitSaveExpense(parsedAmount, true, 'cents_per_km_running_cost');
        },
        secondaryLabel: methodConflict.secondaryActionLabel,
        onSecondary: () {},
      );
      return;
    }

    // 2. Check Date & Cross-FY Conflict
    final valResult = _evaluateValidation();
    if (valResult.isVaultOnlyRecommended && !_isVaultOnly) {
      final guidance = valResult.humanGuidance ??
          const HumanizedValidationError(
            title: 'Receipt from last tax year',
            explanation:
                'This purchase is dated before 1 July. We\'ll save the photo for your records so you have proof, without mixing it into this year\'s tax claim.',
            primaryActionLabel: 'Save Receipt',
            secondaryActionLabel: 'Change Date',
          );
      _showTacticalGuidanceSheet(
        context: context,
        title: guidance.title,
        explanation: guidance.explanation,
        primaryLabel: guidance.primaryActionLabel,
        onPrimary: () {
          setState(() {
            _isVaultOnly = true;
            _vaultReason = 'prior_tax_year';
          });
          _commitSaveExpense(parsedAmount, true, 'prior_tax_year');
        },
        secondaryLabel: guidance.secondaryActionLabel,
        onSecondary: _pickDate,
      );
      return;
    }

    await _commitSaveExpense(parsedAmount, _isVaultOnly, _vaultReason);
  }

  Future<void> _commitSaveExpense(double parsedAmount, bool isVault, String? reason) async {
    HapticFeedback.mediumImpact();
    final merchantName = _merchantController.text.trim().isNotEmpty
        ? _merchantController.text.trim()
        : 'Work Expense';

    final notesText = _notesController.text.trim();
    final finalNotes = notesText.isNotEmpty
        ? (notesText.contains(merchantName)
            ? notesText
            : '$notesText ($merchantName)')
        : merchantName;
    final messenger = ScaffoldMessenger.of(context);
    final auditTrail = await _receiptAuditService.create(
      merchant: merchantName,
      amount: parsedAmount,
      category: _selectedCategory,
      imagePath: _imagePath,
      ocrResult: widget.receiptOcrResult,
    );
    if (!mounted) return;

    final parsedGst = double.tryParse(_gstController.text.replaceAll(',', '').trim());

    if (widget.existingExpense != null) {
      final updated = VehicleExpense(
        id: widget.existingExpense!.id,
        vehicleId: widget.existingExpense!.vehicleId,
        amount: parsedAmount,
        gstAmount: parsedGst,
        category: _selectedCategory,
        date: _selectedDate,
        receiptPath: _imagePath,
        businessPercentage: widget.existingExpense!.businessPercentage,
        notes: finalNotes,
        linkedTripId: widget.existingExpense!.linkedTripId,
        clientDedupId: widget.existingExpense!.clientDedupId,
        deletedAt: widget.existingExpense!.deletedAt,
        receiptAudit: auditTrail,
        isVaultOnly: isVault,
        vaultReason: reason,
      );
      widget.appState.updateExpense(updated);
    } else {
      final expense = VehicleExpense(
        id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
        vehicleId: widget.appState.primaryVehicle?.id ?? 'default_vehicle',
        amount: parsedAmount,
        gstAmount: parsedGst,
        category: _selectedCategory,
        date: _selectedDate,
        receiptPath: _imagePath,
        notes: finalNotes,
        receiptAudit: auditTrail,
        isVaultOnly: isVault,
        vaultReason: reason,
      );
      widget.appState.recordExpense(expense);
    }

    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.emerald,
        content: Text(isVault
            ? 'Receipt saved safely in your records.'
            : (auditTrail.needsReview
                ? 'Expense saved for review. Receipt evidence needs confirmation.'
                : 'Expense saved with verified receipt evidence.')),
      ),
    );
  }

  Widget _buildStatusPill({
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, size: 14, color: textColor),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.primaryVehicle;
    final vehicleName = vehicle != null
        ? (vehicle.make.isNotEmpty ? vehicle.make : vehicle.vehicleType.displayName.toLowerCase())
        : 'vehicle';
    final isCentsPerKm = vehicle?.taxMethod == TaxMethod.centsPerKm;
    final rateCents = widget.appState.taxRuleService.getRateCentsForDate(_selectedDate);

    final methodConflict = _preDbValidator.checkMethodConflict(
      isCentsPerKm: isCentsPerKm,
      category: _selectedCategory,
      rateCents: rateCents,
      vehicleName: vehicleName,
    );
    final valResult = _evaluateValidation();
    final parsedAmount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final parsedGst = double.tryParse(_gstController.text.replaceAll(',', '').trim());
    final legalMaxGst = parsedAmount > 0 ? double.parse((parsedAmount / 11.0).toStringAsFixed(2)) : 0.0;
    final isGstExceeded = parsedGst != null && parsedGst > (legalMaxGst + 0.05);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Expense detail',
          style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.ink),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // OCR suggestions are never accounting truth until reviewed.
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.receiptOcrResult == null
                    ? AppColors.background
                    : AppColors.emeraldLight,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.emerald,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.sparkles,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.receiptOcrResult == null
                              ? 'MANUAL ENTRY • REVIEW REQUIRED'
                              : 'OCR SUGGESTION • REVIEW & CONFIRM',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.emerald,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.receiptOcrResult == null
                              ? 'Attach a clear receipt and confirm every field before tax export.'
                              : 'Matched "${_selectedCategory.displayName}" at ${(widget.receiptOcrResult!.confidence * 100).round()}% confidence. Edit any field that is wrong.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Merchant & Amount Input Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.receipt,
                            color: AppColors.emerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _merchantController,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.ink),
                          decoration: const InputDecoration(
                            hintText: 'Merchant / Supplier',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Review before export',
                          style: TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w800,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Amount (AUD)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        color: AppColors.ink),
                    decoration: const InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          color: AppColors.ink),
                      hintText: '0.00',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  // Apple HIG Glanceable Status Pill
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: methodConflict != null
                          ? _buildStatusPill(
                              backgroundColor: AppColors.amberLight,
                              textColor: AppColors.amberDark,
                              icon: LucideIcons.alertCircle,
                              label: methodConflict.title,
                              onTap: () => _showTacticalGuidanceSheet(
                                context: context,
                                title: methodConflict.title,
                                explanation: methodConflict.explanation,
                                primaryLabel: methodConflict.primaryActionLabel,
                                onPrimary: () {
                                  setState(() {
                                    _isVaultOnly = true;
                                    _vaultReason = 'cents_per_km_running_cost';
                                  });
                                  _commitSaveExpense(parsedAmount, true, 'cents_per_km_running_cost');
                                },
                                secondaryLabel: methodConflict.secondaryActionLabel,
                                onSecondary: () {},
                              ),
                            )
                          : (valResult.isVaultOnlyRecommended || _isVaultOnly)
                              ? _buildStatusPill(
                                  backgroundColor: AppColors.amberLight,
                                  textColor: AppColors.amberDark,
                                  icon: LucideIcons.clock,
                                  label: "Receipt from last tax year",
                                  onTap: () {
                                    final guidance = valResult.humanGuidance ??
                                        const HumanizedValidationError(
                                          title: 'Receipt from last tax year',
                                          explanation:
                                              'This purchase is dated before 1 July. We\'ll save the photo for your records so you have proof, without mixing it into this year\'s tax claim.',
                                          primaryActionLabel: 'Save Receipt',
                                          secondaryActionLabel: 'Change Date',
                                        );
                                    _showTacticalGuidanceSheet(
                                      context: context,
                                      title: guidance.title,
                                      explanation: guidance.explanation,
                                      primaryLabel: guidance.primaryActionLabel,
                                      onPrimary: () {
                                        setState(() {
                                          _isVaultOnly = true;
                                          _vaultReason = 'prior_tax_year';
                                        });
                                      },
                                      secondaryLabel: guidance.secondaryActionLabel,
                                      onSecondary: _pickDate,
                                    );
                                  },
                                )
                              : isGstExceeded
                                  ? _buildStatusPill(
                                      backgroundColor: AppColors.crimsonLight,
                                      textColor: AppColors.crimson,
                                      icon: LucideIcons.alertTriangle,
                                      label: "Check GST amount",
                                      onTap: () => _showTacticalGuidanceSheet(
                                        context: context,
                                        title: 'Check GST amount',
                                        explanation:
                                            'For a \$${parsedAmount.toStringAsFixed(2)} purchase, GST cannot exceed \$${legalMaxGst.toStringAsFixed(2)}. The camera may have misread the tax line.',
                                        primaryLabel: 'Fix to \$${legalMaxGst.toStringAsFixed(2)}',
                                        onPrimary: () {
                                          setState(() {
                                            _gstController.text = legalMaxGst.toStringAsFixed(2);
                                          });
                                        },
                                        secondaryLabel: 'Keep \$${parsedGst.toStringAsFixed(2)}',
                                        onSecondary: () {},
                                      ),
                                    )
                                  : parsedAmount > 0
                                      ? _buildStatusPill(
                                          backgroundColor: AppColors.emeraldLight,
                                          textColor: AppColors.emerald,
                                          icon: LucideIcons.checkCircle2,
                                          label: 'Ready for tax',
                                        )
                                      : const SizedBox.shrink(),
                    ),
                  ),

                  // Interactive Date Trigger
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.calendar, size: 14, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            Formatters.date(_selectedDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.deepNavy,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '• Tap to change date',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Minimal GST Component Input Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGstExceeded ? AppColors.crimson : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.percent, size: 16, color: AppColors.muted),
                        const SizedBox(width: 8),
                        const Text(
                          'GST component',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _gstController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isGstExceeded ? AppColors.crimson : AppColors.ink,
                            ),
                            decoration: const InputDecoration(
                              prefixText: '\$ ',
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (parsedAmount > 0) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _gstController.text = legalMaxGst.toStringAsFixed(2);
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'Auto 10%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isGstExceeded)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'For a \$${parsedAmount.toStringAsFixed(2)} purchase, maximum GST is \$${legalMaxGst.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.crimson,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildDropdownRow(
                    icon: LucideIcons.tag,
                    label: 'Category',
                    value: _selectedCategory.displayName,
                    onTap: _showCategoryPicker,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildInfoRow(
                    icon: LucideIcons.creditCard,
                    label: 'Payment method',
                    value: 'Business Account',
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildInfoRow(
                    icon: LucideIcons.truck,
                    label: 'Vehicle',
                    value: vehicleName,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildInfoRow(
                    icon: LucideIcons.percent,
                    label: 'Claim type',
                    value: _selectedCategory.isDirectlyDeductibleByDefault
                        ? '100% Direct Business Claim'
                        : 'Logbook Scaled Claim',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _notesController,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  icon: Icon(LucideIcons.pencil,
                      size: 20, color: AppColors.muted),
                  hintText: 'Notes (e.g. Tools, Materials, Client job site)',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Receipt Photo Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _imagePath != null && File(_imagePath!).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(_imagePath!),
                                fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Icon(LucideIcons.receipt,
                                color: AppColors.muted, size: 28),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tax Receipt Evidence',
                          style: AppTextStyles.cardPrimary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _imagePath != null
                              ? 'Photo attached & verified'
                              : 'Digital substantiation record',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ATO Substantiation Evidence Checklist Card (Matching TripDetailScreen Spec #8)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ATO Evidence Checklist',
                      style: AppTextStyles.cardPrimary),
                  const SizedBox(height: 14),
                  _buildEvidenceCheck(
                      label: 'Supplier / Merchant',
                      isVerified: _merchantController.text.trim().isNotEmpty),
                  const SizedBox(height: 10),
                  _buildEvidenceCheck(
                      label: 'Expense Amount',
                      isVerified:
                          (double.tryParse(_amountController.text.trim()) ??
                                  0) >
                              0),
                  const SizedBox(height: 10),
                  _buildEvidenceCheck(label: 'Date & Time', isVerified: true),
                  const SizedBox(height: 10),
                  _buildEvidenceCheck(
                      label: 'Business Category', isVerified: true),
                  const SizedBox(height: 10),
                  _buildEvidenceCheck(
                      label: 'Receipt Photo Attached',
                      isVerified: _imagePath != null),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _saveAndCommitExpense,
              child: Text(
                widget.existingExpense != null
                    ? 'Update Expense Record'
                    : 'Save Expense to Vault',
                style: AppTextStyles.button,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCheck(
      {required String label, required bool isVerified}) {
    return Row(
      children: [
        Icon(
          isVerified ? LucideIcons.checkCircle : LucideIcons.alertCircle,
          size: 16,
          color: isVerified ? AppColors.emerald : AppColors.amberDark,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isVerified ? AppColors.ink : AppColors.muted,
          ),
        ),
        const Spacer(),
        Text(
          isVerified ? '✓ Valid' : 'Missing',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isVerified ? AppColors.emerald : AppColors.amberDark,
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'SELECT STATUTORY CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.muted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  'Core 3 Pillars (97% of Tradie Vehicle Claims)',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ),
              _buildCategoryTile(ctx, ExpenseCategory.fuel, LucideIcons.fuel,
                  AppColors.emerald),
              _buildCategoryTile(ctx, ExpenseCategory.maintenanceTyres,
                  LucideIcons.wrench, AppColors.workBlue),
              _buildCategoryTile(ctx, ExpenseCategory.rego,
                  LucideIcons.fileText, AppColors.workBlue),
              _buildCategoryTile(ctx, ExpenseCategory.insurance,
                  LucideIcons.shieldCheck, AppColors.workBlue),
              _buildCategoryTile(ctx, ExpenseCategory.tollsParking,
                  LucideIcons.parkingSquare, AppColors.amberDark),
              const Divider(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  'Other Secondary Business Costs',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted),
                ),
              ),
              _buildCategoryTile(ctx, ExpenseCategory.toolsMaterials,
                  LucideIcons.hammer, AppColors.muted),
              _buildCategoryTile(ctx, ExpenseCategory.interest,
                  LucideIcons.percent, AppColors.muted),
              _buildCategoryTile(ctx, ExpenseCategory.otherBusiness,
                  LucideIcons.moreHorizontal, AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(
      BuildContext ctx, ExpenseCategory cat, IconData icon, Color iconColor) {
    final isSel = cat == _selectedCategory;
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(
        cat.displayName,
        style: TextStyle(
          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
          color: isSel ? AppColors.workBlue : AppColors.ink,
        ),
      ),
      trailing: isSel
          ? const Icon(Icons.check_circle_rounded, color: AppColors.workBlue)
          : null,
      onTap: () {
        setState(() => _selectedCategory = cat);
        Navigator.of(ctx).pop();
      },
    );
  }

  Widget _buildDropdownRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.muted),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.ink)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: AppColors.workBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppColors.ink)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
