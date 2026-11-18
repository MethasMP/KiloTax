import '../../widgets/adaptive_row.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/evidence/evidence_auto_match_engine.dart';
import '../../../services/ocr/receipt_audit_service.dart';
import '../../../services/ocr/receipt_intelligence_service.dart';
import '../../../services/ocr/receipt_pre_db_validator.dart';
import '../../../services/receipts/receipt_workflow_policy.dart';
import '../../../services/scanner/document_scanner_service.dart';
import '../../../services/tax/ato_tax_period_engine.dart';
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
  final String? initialLinkedTripId;
  final String? autoMatchReason;
  final DocumentScannerService? documentScanner;
  final ReceiptAuditService? receiptAuditService;
  final Future<void> Function(VehicleExpense)? onSaveDraft;
  final bool purchaseDateUnknown;

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
    this.initialLinkedTripId,
    this.autoMatchReason,
    this.documentScanner,
    this.receiptAuditService,
    this.onSaveDraft,
    this.purchaseDateUnknown = false,
  });

  static Future<void> show(BuildContext context,
      {required AppState appState, required VehicleExpense expense}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(
          appState: appState,
          merchant:
              expense.supplier ?? expense.notes ?? expense.category.displayName,
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
  late final ReceiptAuditService _receiptAuditService =
      widget.receiptAuditService ?? const ReceiptAuditService();
  final ReceiptPreDbValidator _preDbValidator = const ReceiptPreDbValidator();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _gstController;
  late TextEditingController _notesController;
  late TextEditingController _abnController;
  late TextEditingController _invoiceController;
  String? _currency;
  bool _replacementReviewed = false;
  late ExpenseCategory _selectedCategory;
  late DateTime _selectedDate;
  List<ReceiptAllocation> _allocations = [];
  int _allocationRevision = 0;
  String? _vehicleId;
  bool _categoryConfirmed = false;
  bool _isSaving = false;
  bool _confirmedByUser = false;
  bool _dateNeedsReview = false;
  bool _detailsChanged = false;
  bool _pickingReceipt = false;
  String? _imagePath;
  bool _isVaultOnly = false;
  String? _vaultReason;
  String? _linkedTripId;
  String? _suggestedTripId;
  String? _autoMatchReason;

  @override
  void initState() {
    super.initState();
    _vehicleId =
        widget.existingExpense?.vehicleId ?? widget.appState.primaryVehicle?.id;
    _allocations = List.of(widget.existingExpense?.allocations ?? []);
    _merchantController = TextEditingController(text: widget.merchant);
    _amountController = TextEditingController(
      text: widget.amount > 0 ? widget.amount.toStringAsFixed(2) : '',
    );
    final initialGst =
        widget.existingExpense?.gstAmount ?? widget.receiptOcrResult?.gstAmount;
    _gstController = TextEditingController(
      text: initialGst != null ? initialGst.toStringAsFixed(2) : '',
    );
    _notesController =
        TextEditingController(text: widget.existingExpense?.notes ?? '');
    _abnController = TextEditingController(
        text: widget.existingExpense?.supplierAbn ??
            widget.receiptOcrResult?.abn ??
            '');
    _invoiceController = TextEditingController(
        text: widget.existingExpense?.invoiceNumber ??
            widget.receiptOcrResult?.invoiceNumber ??
            '');
    _currency = widget.existingExpense != null
        ? widget.existingExpense!.currency
        : widget.receiptOcrResult?.currency ??
            (widget.receiptOcrResult == null ? 'AUD' : null);
    _abnController.addListener(_onFieldChanged);
    _invoiceController.addListener(_onFieldChanged);
    _selectedCategory =
        widget.existingExpense?.category ?? _resolveInitialCategory();
    _selectedDate = widget.existingExpense?.date ?? widget.receiptDate;
    _dateNeedsReview = widget.purchaseDateUnknown ||
        (widget.receiptOcrResult?.dateNeedsReview ?? false);
    _imagePath = widget.existingExpense?.receiptPath ?? widget.receiptImagePath;
    _isVaultOnly = widget.existingExpense?.isVaultOnly ?? false;
    _vaultReason = widget.existingExpense?.vaultReason;
    _linkedTripId = widget.existingExpense?.linkedTripId;
    _suggestedTripId =
        widget.existingExpense == null ? widget.initialLinkedTripId : null;
    _autoMatchReason = widget.autoMatchReason;
    _categoryConfirmed = widget.existingExpense != null;

    _amountController.addListener(_onFieldChanged);
    _gstController.addListener(_onFieldChanged);
    _merchantController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);

    _checkAutoTripSuggestion();
  }

  void _checkAutoTripSuggestion() {
    if (_linkedTripId == null && _suggestedTripId == null) {
      final parsedAmount = double.tryParse(
            _amountController.text.replaceAll(',', '').trim(),
          ) ??
          widget.amount;
      final tempExpense = VehicleExpense(
        id: widget.existingExpense?.id ?? 'temp_suggest_exp',
        vehicleId: _vehicleId ?? '',
        amount: parsedAmount,
        category: _selectedCategory,
        date: _selectedDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : widget.merchant,
      );
      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: tempExpense,
        candidateTrips: widget.appState.trips,
      );
      if (match != null && match.confidenceScore >= 0.80) {
        _suggestedTripId = match.trip.id;
        _autoMatchReason = match.matchReason;
      }
    }
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {
        _confirmedByUser = false;
        _detailsChanged = true;
      });
    }
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
    _merchantController.removeListener(_onFieldChanged);
    _notesController.removeListener(_onFieldChanged);
    _merchantController.dispose();
    _amountController.dispose();
    _gstController.dispose();
    _notesController.dispose();
    _abnController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime(2020)) ||
              _selectedDate.isAfter(DateTime.now().add(const Duration(days: 1)))
          ? DateTime.now()
          : _selectedDate,
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
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateNeedsReview = false;
        _confirmedByUser = false;
        _detailsChanged = true;
      });
    }
  }

  Future<void> _attachReceipt() async {
    if (_pickingReceipt || _isSaving) return;
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Scan receipt'),
            onTap: () => Navigator.of(context).pop('scan'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose receipt photo'),
            onTap: () => Navigator.of(context).pop('gallery'),
          ),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _pickingReceipt = true);
    try {
      final scanner = widget.documentScanner ?? DocumentScannerService();
      final path = source == 'scan'
          ? await scanner.scanDocument()
          : await scanner.pickFromGallery();
      if (path == null || !mounted) return;
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw const FormatException('The receipt photo could not be read.');
      }
      if (!mounted) return;
      setState(() {
        _imagePath = path;
        _replacementReviewed = true;
        _confirmedByUser = false;
        _detailsChanged = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not attach the receipt. Please try another photo.')));
      }
    } finally {
      if (mounted) setState(() => _pickingReceipt = false);
    }
  }

  String? get _allocationError => VehicleExpense(
          id: 'review',
          vehicleId: _vehicleId ?? '',
          amount: double.tryParse(
                  _amountController.text.replaceAll(',', '').trim()) ??
              0,
          gstAmount:
              double.tryParse(_gstController.text.replaceAll(',', '').trim()),
          category: _selectedCategory,
          date: _selectedDate,
          allocations: _allocations)
      .allocationError;

  void _changeAllocation(int index,
      {String? description,
      double? amount,
      double? gst,
      bool clearGst = false,
      AllocationPurpose? purpose,
      ExpenseCategory? category}) {
    final old = _allocations[index];
    setState(() {
      _allocations[index] = ReceiptAllocation(
          description: description ?? old.description,
          amount: amount ?? old.amount,
          gstAmount: clearGst ? null : gst ?? old.gstAmount,
          purpose: purpose ?? old.purpose,
          category: category ?? old.category);
      _confirmedByUser = false;
      _detailsChanged = true;
    });
  }

  Widget _buildAllocationEditor() {
    final totalReceiptAmount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim()) ??
            0.0;
    final allocatedTotal = _allocations.fold(
        0.0, (sum, l) => sum + (l.amount.isFinite ? l.amount : 0.0));
    final work = _allocations
        .where((l) => l.purpose == AllocationPurpose.work)
        .fold(0.0, (sum, l) => sum + (l.amount.isFinite ? l.amount : 0.0));
    final private = _allocations
        .where((l) => l.purpose == AllocationPurpose.private)
        .fold(0.0, (sum, l) => sum + (l.amount.isFinite ? l.amount : 0.0));

    final totalCents = (totalReceiptAmount * 100).round();
    final allocatedCents = (allocatedTotal * 100).round();
    final differenceCents = totalCents - allocatedCents;
    final remainingDiff = differenceCents / 100.0;
    final isBalanced = _allocations.isNotEmpty && differenceCents == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _allocations.isEmpty
              ? AppColors.border
              : (isBalanced ? AppColors.emerald : Colors.amber.shade700),
          width: isBalanced ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('What belongs to work / vehicle?',
                    style: AppTextStyles.cardPrimary),
              ),
              if (_allocations.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBalanced
                        ? AppColors.emerald.withValues(alpha: 0.12)
                        : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBalanced
                        ? 'Balanced 100%'
                        : (remainingDiff > 0
                            ? 'Rem: \$${remainingDiff.toStringAsFixed(2)}'
                            : 'Exceeded: \$${(-remainingDiff).toStringAsFixed(2)}'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isBalanced
                          ? AppColors.emerald
                          : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep the full receipt. Separate personal purchases before calculating business use.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_allocations.isEmpty)
                TextButton.icon(
                  key: const ValueKey('split-receipt'),
                  icon: const Icon(Icons.call_split),
                  label: const Text('Separate personal / work items'),
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _allocations = [
                              ReceiptAllocation(
                                  description: 'Receipt items',
                                  amount: double.tryParse(_amountController.text
                                          .replaceAll(',', '')
                                          .trim()) ??
                                      0,
                                  purpose: AllocationPurpose.unresolved,
                                  category: _selectedCategory)
                            ];
                            _confirmedByUser = false;
                            _detailsChanged = true;
                          });
                        },
                ),
              ActionChip(
                key: const ValueKey('preset-100-work'),
                avatar: const Icon(Icons.business_center, size: 16),
                label: const Text('100% Work'),
                backgroundColor: _allocations.length == 1 &&
                        _allocations.first.purpose == AllocationPurpose.work
                    ? AppColors.emerald.withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _allocations = [
                            ReceiptAllocation(
                              description: _selectedCategory.displayName,
                              amount: totalReceiptAmount,
                              purpose: AllocationPurpose.work,
                              category: _selectedCategory,
                            ),
                          ];
                          _confirmedByUser = false;
                          _detailsChanged = true;
                        });
                      },
              ),
              ActionChip(
                key: const ValueKey('preset-split-snack'),
                avatar: const Icon(Icons.remove_circle_outline, size: 16),
                label: const Text('Deduct Personal Items'),
                backgroundColor: Colors.grey.shade100,
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          final defaultWork = (totalReceiptAmount > 10)
                              ? (totalReceiptAmount - 10)
                              : totalReceiptAmount;
                          final defaultPrivate =
                              totalReceiptAmount - defaultWork;
                          _allocations = [
                            ReceiptAllocation(
                              description: 'Work items',
                              amount:
                                  double.parse(defaultWork.toStringAsFixed(2)),
                              purpose: AllocationPurpose.work,
                              category: _selectedCategory,
                            ),
                            ReceiptAllocation(
                              description: 'Personal items (Drink/Food/Etc)',
                              amount: double.parse(
                                  defaultPrivate.toStringAsFixed(2)),
                              purpose: AllocationPurpose.private,
                            ),
                          ];
                          _confirmedByUser = false;
                          _detailsChanged = true;
                        });
                      },
              ),
              if (_allocations.isNotEmpty)
                ActionChip(
                  key: const ValueKey('preset-clear-splits'),
                  avatar: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset'),
                  backgroundColor: Colors.grey.shade100,
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _allocations = [];
                            _confirmedByUser = false;
                            _detailsChanged = true;
                          });
                        },
                ),
            ],
          ),

          if (_allocations.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (work > 0 && totalReceiptAmount > 0)
                      Expanded(
                        flex: ((work / totalReceiptAmount) * 100)
                            .round()
                            .clamp(1, 100),
                        child: Container(color: AppColors.emerald),
                      ),
                    if (private > 0 && totalReceiptAmount > 0)
                      Expanded(
                        flex: ((private / totalReceiptAmount) * 100)
                            .round()
                            .clamp(1, 100),
                        child: Container(color: Colors.blueGrey),
                      ),
                    if (remainingDiff > 0 && totalReceiptAmount > 0)
                      Expanded(
                        flex: ((remainingDiff / totalReceiptAmount) * 100)
                            .round()
                            .clamp(1, 100),
                        child: Container(color: Colors.amber.shade400),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Work: \$${work.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald),
                ),
                Text(
                  'Personal: \$${private.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey),
                ),
                Text(
                  'Total: \$${totalReceiptAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ],
            ),
          ],

          for (var i = 0; i < _allocations.length; i++) ...[
            const Divider(height: 28),
            TextFormField(
                key: ValueKey('allocation-description-$i-$_allocationRevision'),
                initialValue: _allocations[i].description,
                decoration: InputDecoration(labelText: 'Item ${i + 1} Name'),
                onChanged: (v) => _changeAllocation(i, description: v)),
            const SizedBox(height: 12),
            TextFormField(
                key: ValueKey('allocation-amount-$i-$_allocationRevision'),
                initialValue: _allocations[i].amount > 0
                    ? _allocations[i].amount.toStringAsFixed(2)
                    : '',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Item amount (AUD)', prefixText: '\$ '),
                onChanged: (v) => _changeAllocation(i,
                    amount: double.tryParse(v.replaceAll(',', '').trim()) ??
                        double.nan)),
            const SizedBox(height: 12),
            DropdownButtonFormField<AllocationPurpose>(
                key: ValueKey('allocation-purpose-$i'),
                initialValue: _allocations[i].purpose,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Use'),
                items: const [
                  DropdownMenuItem(
                      value: AllocationPurpose.work,
                      child: Text('Vehicle / work')),
                  DropdownMenuItem(
                      value: AllocationPurpose.private,
                      child: Text('Personal — excluded')),
                  DropdownMenuItem(
                      value: AllocationPurpose.unresolved,
                      child: Text('Not sure — excluded'))
                ],
                onChanged: (v) {
                  if (v != null) _changeAllocation(i, purpose: v);
                }),
            if (_allocations[i].purpose != AllocationPurpose.private &&
                _receiptIntelligence
                    .isLikelyPersonalItem(_allocations[i].description)) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  key: ValueKey('mark-private-chip-$i'),
                  avatar: const Icon(Icons.person_outline,
                      size: 16, color: Colors.blueGrey),
                  label: const Text('Mark as Private'),
                  backgroundColor: Colors.blueGrey.shade50,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _changeAllocation(i, purpose: AllocationPurpose.private);
                  },
                ),
              ),
            ],
            if (_allocations[i].purpose == AllocationPurpose.work) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<ExpenseCategory>(
                  key: ValueKey('allocation-category-$i'),
                  initialValue: _allocations[i].category ?? _selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Item category'),
                  items: ExpenseCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.displayName)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _changeAllocation(i, category: v);
                  }),
            ],
            const SizedBox(height: 12),
            TextFormField(
                key: ValueKey('allocation-gst-$i-$_allocationRevision'),
                initialValue:
                    _allocations[i].gstAmount?.toStringAsFixed(2) ?? '',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Item GST (if shown)',
                    hintText: 'Leave blank if unknown'),
                onChanged: (v) => _changeAllocation(i,
                    clearGst: v.trim().isEmpty,
                    gst: double.tryParse(v.replaceAll(',', '').trim()) ??
                        double.nan)),
            if (_allocations.length > 1)
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove item'),
                      onPressed: () {
                        setState(() {
                          _allocations.removeAt(i);
                          _allocationRevision++;
                          _confirmedByUser = false;
                          _detailsChanged = true;
                        });
                      })),
          ],

          if (_allocations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('add-receipt-item'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add item'),
                    onPressed: () {
                      setState(() {
                        _allocations.add(const ReceiptAllocation(
                            description: '',
                            amount: 0,
                            purpose: AllocationPurpose.unresolved));
                        _confirmedByUser = false;
                        _detailsChanged = true;
                      });
                    },
                  ),
                ),
                if (remainingDiff > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('auto-balance-remaining'),
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: Text(
                          '+\$${remainingDiff.toStringAsFixed(2)} Personal'),
                      onPressed: () {
                        setState(() {
                          _allocations.add(ReceiptAllocation(
                            description: 'Personal remaining balance',
                            amount: remainingDiff,
                            purpose: AllocationPurpose.private,
                          ));
                          _confirmedByUser = false;
                          _detailsChanged = true;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _allocationError ?? 'Items balance perfectly with receipt total.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _allocationError == null
                    ? AppColors.emerald
                    : AppColors.crimson,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ReceiptValidationResult _evaluateValidation() {
    final amt =
        double.tryParse(_amountController.text.replaceAll(',', '').trim()) ??
            0.0;
    final gst = double.tryParse(_gstController.text.replaceAll(',', '').trim());
    final ocr = ReceiptOcrResult(
      merchant: _merchantController.text.trim(),
      amount: amt,
      gstAmount: gst,
      abn: _abnController.text.trim(),
      currency: _currency,
      date: _selectedDate,
      category: _selectedCategory,
      confidence: widget.receiptOcrResult?.confidence ?? 0.9,
      evidence: widget.receiptOcrResult?.evidence ?? const [],
      rawText: widget.receiptOcrResult?.rawText ?? '',
    );
    return _preDbValidator.validateAndSanitize(
      ocrResult: ocr,
      logbookStartDate: widget.appState.vehicles
          .where((v) => v.id == _vehicleId)
          .firstOrNull
          ?.logbookStartDate,
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
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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

  void _validateRecord(VehicleExpense expense) {
    final problems = const ReceiptWorkflowPolicy().coreIssues(expense);
    if (problems.isNotEmpty) throw FormatException(problems.join('. '));
  }

  Future<void> _saveAndCommitExpense() async {
    if (_pickingReceipt || _isSaving) return;
    if (_dateNeedsReview) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Choose the purchase date. It could not be read from the receipt.')));
      await _pickDate();
      return;
    }
    final parsedAmount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (parsedAmount == null || !parsedAmount.isFinite || parsedAmount <= 0) {
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
    if (_confirmedByUser && _merchantController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the merchant before confirming this expense.')));
      return;
    }

    final vehicle =
        widget.appState.vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    final vehicleName = vehicle != null
        ? (vehicle.make.isNotEmpty
            ? vehicle.make
            : vehicle.vehicleType.displayName.toLowerCase())
        : 'vehicle';
    final isCentsPerKm = vehicle?.taxMethod == TaxMethod.centsPerKm;
    final rateCents =
        widget.appState.taxRuleService.getRateCentsForDate(_selectedDate);

    final methodConflict = _preDbValidator.checkMethodConflict(
      isCentsPerKm: isCentsPerKm,
      category: _allocations.any((l) =>
              l.purpose == AllocationPurpose.work &&
              (l.category ?? _selectedCategory).isDirectlyDeductibleByDefault)
          ? ExpenseCategory.otherBusiness
          : _selectedCategory,
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

  Future<void> _commitSaveExpense(
      double parsedAmount, bool isVault, String? reason) async {
    if (_isSaving) return;
    if (_dateNeedsReview) {
      await _pickDate();
      return;
    }
    final gstText = _gstController.text.replaceAll(',', '').trim();
    final gst = double.tryParse(gstText);
    final error = _allocationError ??
        (_vehicleId == null
            ? 'Choose a vehicle before saving.'
            : (gstText.isNotEmpty &&
                    (gst == null ||
                        !gst.isFinite ||
                        gst < 0 ||
                        gst > parsedAmount / 11 + 0.01)
                ? 'Check the GST on the receipt, or leave it blank if unknown.'
                : null));
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // A mixed receipt can contain direct work costs even if its original fuel-only
    // record was kept as CPK evidence. Other vault reasons remain unchanged.
    if (reason == 'cents_per_km_running_cost' &&
        _allocations.any((line) =>
            line.purpose == AllocationPurpose.work &&
            (line.category ?? _selectedCategory)
                .isDirectlyDeductibleByDefault)) {
      isVault = false;
      reason = null;
    }
    final savedAllocations = List<ReceiptAllocation>.of(_allocations);
    final savedCategory = _selectedCategory;
    final savedDate = _selectedDate;
    final savedImagePath = _imagePath;
    final savedLinkedTripId = _linkedTripId;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final merchantName = _merchantController.text.trim().isNotEmpty
          ? _merchantController.text.trim()
          : 'Work Expense';

      final notesText = _notesController.text.trim();
      final finalNotes = notesText.isNotEmpty
          ? (notesText.contains(merchantName)
              ? notesText
              : '$notesText ($merchantName)')
          : merchantName;
      final auditTrail = await _receiptAuditService.create(
        merchant: merchantName,
        amount: parsedAmount,
        category: savedCategory,
        date: savedDate,
        currency: _currency,
        abn: _abnController.text.trim(),
        invoiceNumber: _invoiceController.text.trim(),
        gstAmount: gst,
        imageReplacementReviewed: _replacementReviewed,
        fieldValues: {
          "date": savedDate.toIso8601String(),
          "vehicleId": _vehicleId,
          "currency": _currency,
          "gstAmount": gst,
          "abn": _abnController.text.trim(),
          "invoiceNumber": _invoiceController.text.trim(),
          "allocations": savedAllocations.map((a) => a.toJson()).toList(),
        },
        imagePath: savedImagePath,
        ocrResult: widget.receiptOcrResult,
        existingAudit: widget.existingExpense?.receiptAudit,
        confirmedByUser: _confirmedByUser,
        detailsChanged: _detailsChanged,
      );
      if (!mounted) return;

      final parsedGst = gst;

      if (widget.existingExpense != null) {
        final updated = VehicleExpense(
          id: widget.existingExpense!.id,
          vehicleId: _vehicleId!,
          amount: parsedAmount,
          gstAmount: parsedGst,
          supplier: merchantName,
          currency: _currency,
          supplierAbn: _abnController.text.trim(),
          invoiceNumber: _invoiceController.text.trim(),
          allocations: savedAllocations,
          category: savedCategory,
          date: savedDate,
          receiptPath: savedImagePath,
          businessPercentage: widget.existingExpense!.businessPercentage,
          notes: finalNotes,
          linkedTripId: savedLinkedTripId,
          jobId: widget.existingExpense?.jobId,
          clientDedupId: widget.existingExpense!.clientDedupId,
          deletedAt: widget.existingExpense!.deletedAt,
          receiptAudit: auditTrail,
          isVaultOnly: isVault,
          vaultReason: reason,
        );
        if (widget.onSaveDraft == null) _validateRecord(updated);
        await (widget.onSaveDraft?.call(updated) ??
            widget.appState.saveWorkflowReceipt(updated));
      } else {
        final expense = VehicleExpense(
          id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
          vehicleId: _vehicleId!,
          amount: parsedAmount,
          gstAmount: parsedGst,
          supplier: merchantName,
          currency: _currency,
          supplierAbn: _abnController.text.trim(),
          invoiceNumber: _invoiceController.text.trim(),
          allocations: savedAllocations,
          category: savedCategory,
          date: savedDate,
          receiptPath: savedImagePath,
          notes: finalNotes,
          linkedTripId: savedLinkedTripId,
          jobId: widget.existingExpense?.jobId,
          receiptAudit: auditTrail,
          isVaultOnly: isVault,
          vaultReason: reason,
        );
        if (widget.onSaveDraft == null) _validateRecord(expense);
        await (widget.onSaveDraft?.call(expense) ??
            widget.appState.saveWorkflowReceipt(expense));
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.emerald,
          content: Text(widget.onSaveDraft != null
              ? 'Draft updated. Select it in the inbox to confirm with other receipts.'
              : isVault
                  ? 'Receipt saved safely in your records.'
                  : (auditTrail.needsReview
                      ? 'Expense saved for review. Receipt evidence needs confirmation.'
                      : (auditTrail.reviewStatus ==
                              ReceiptReviewStatus.confirmed
                          ? 'Expense details confirmed and saved.'
                          : 'Expense saved with matching receipt evidence.'))),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.crimson,
          content: Text(
              'Could not save this expense. Nothing was lost — your entry is still here, so try again.'),
        ),
      );
    }
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
        child: AdaptiveRow(
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

  bool get _hasReceiptEvidence =>
      (_imagePath?.trim().isNotEmpty ?? false) ||
      widget.receiptOcrResult != null;

  Widget _buildReceiptReviewHeader() {
    final editing = widget.existingExpense != null;
    final extracted = widget.receiptOcrResult != null;
    return Container(
      key: const ValueKey('receipt-review-guidance'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(editing ? 'Edit receipt details' : 'Review your receipt',
              style: AppType.cardTitle),
          const SizedBox(height: 8),
          Text(
            editing
                ? 'Check merchant, date, amount and category before updating this record.'
                : extracted
                    ? 'Draft extracted from photo, not saved. Check merchant, date, amount and category.'
                    : 'Photo attached, not saved. Check merchant, date, amount and category.',
            style: AppType.secondary,
          ),
        ],
      ),
    );
  }

  Future<void> _showReceiptPhoto() async {
    final path = _imagePath;
    if (path == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Receipt photo'),
            leading: IconButton(
              tooltip: 'Close receipt photo',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Text('Receipt preview unavailable'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptPhotoCard() {
    final hasPhoto = _imagePath != null && File(_imagePath!).existsSync();
    return Container(
      key: const ValueKey('receipt-photo-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 72,
            decoration: BoxDecoration(
              color: AppColor.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColor.hairline),
            ),
            child: hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  semanticLabel: 'Receipt preview unavailable'),
                            )),
                  )
                : const Icon(LucideIcons.receipt,
                    color: AppColor.inkMuted, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tax Receipt Evidence', style: AppType.bodyStrong),
                Text(hasPhoto ? 'Photo attached' : 'Receipt photo needed',
                    style: AppType.secondary),
                Wrap(
                  spacing: 4,
                  children: [
                    if (hasPhoto)
                      TextButton(
                        key: const ValueKey('inspect-receipt-photo'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _showReceiptPhoto,
                        child: const Text('Inspect'),
                      ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed:
                          _pickingReceipt || _isSaving ? null : _attachReceipt,
                      child: Text(_pickingReceipt
                          ? 'Attaching receipt…'
                          : _imagePath == null
                              ? 'Attach receipt'
                              : hasPhoto
                                  ? 'Replace'
                                  : 'Replace receipt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTripDayMonth(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$formattedHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final vehicle =
        widget.appState.vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    final vehicleName = vehicle != null
        ? (vehicle.make.isNotEmpty
            ? vehicle.make
            : vehicle.vehicleType.displayName.toLowerCase())
        : 'vehicle';
    final isCentsPerKm = vehicle?.taxMethod == TaxMethod.centsPerKm;
    final rateCents =
        widget.appState.taxRuleService.getRateCentsForDate(_selectedDate);

    final methodConflict = _preDbValidator.checkMethodConflict(
      isCentsPerKm: isCentsPerKm,
      category: _allocations.any((l) =>
              l.purpose == AllocationPurpose.work &&
              (l.category ?? _selectedCategory).isDirectlyDeductibleByDefault)
          ? ExpenseCategory.otherBusiness
          : _selectedCategory,
      rateCents: rateCents,
      vehicleName: vehicleName,
    );
    final valResult = _evaluateValidation();
    final parsedAmount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim()) ??
            0.0;
    final parsedGst =
        double.tryParse(_gstController.text.replaceAll(',', '').trim());
    final legalMaxGst = parsedAmount > 0
        ? double.parse((parsedAmount / 11.0).toStringAsFixed(2))
        : 0.0;
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
      body: AbsorbPointer(
          absorbing: _isSaving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasReceiptEvidence) ...[
                  _buildReceiptReviewHeader(),
                  const SizedBox(height: 12),
                  _buildReceiptPhotoCard(),
                  const SizedBox(height: 16),
                ],

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
                      TextField(
                        key: const ValueKey('expense-merchant'),
                        controller: _merchantController,
                        style: AppType.cardTitle,
                        decoration: const InputDecoration(
                          labelText: 'Merchant / Supplier',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColor.attentionTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Review before export',
                            style: AppType.secondary
                                .copyWith(color: AppColor.attentionInk)),
                      ),
                      const SizedBox(height: 16),
                      const Text('Amount (AUD)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted)),
                      const SizedBox(height: 4),
                      TextField(
                        key: const ValueKey('expense-amount'),
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                                    primaryLabel:
                                        methodConflict.primaryActionLabel,
                                    onPrimary: () {
                                      setState(() {
                                        _isVaultOnly = true;
                                        _vaultReason =
                                            'cents_per_km_running_cost';
                                      });
                                      _commitSaveExpense(parsedAmount, true,
                                          'cents_per_km_running_cost');
                                    },
                                    secondaryLabel:
                                        methodConflict.secondaryActionLabel,
                                    onSecondary: () {},
                                  ),
                                )
                              : (valResult.isVaultOnlyRecommended ||
                                      _isVaultOnly)
                                  ? _buildStatusPill(
                                      backgroundColor: AppColors.amberLight,
                                      textColor: AppColors.amberDark,
                                      icon: LucideIcons.clock,
                                      label: "Receipt from last tax year",
                                      onTap: () {
                                        final guidance =
                                            valResult.humanGuidance ??
                                                const HumanizedValidationError(
                                                  title:
                                                      'Receipt from last tax year',
                                                  explanation:
                                                      'This purchase is dated before 1 July. We\'ll save the photo for your records so you have proof, without mixing it into this year\'s tax claim.',
                                                  primaryActionLabel:
                                                      'Save Receipt',
                                                  secondaryActionLabel:
                                                      'Change Date',
                                                );
                                        _showTacticalGuidanceSheet(
                                          context: context,
                                          title: guidance.title,
                                          explanation: guidance.explanation,
                                          primaryLabel:
                                              guidance.primaryActionLabel,
                                          onPrimary: () {
                                            setState(() {
                                              _isVaultOnly = true;
                                              _vaultReason = 'prior_tax_year';
                                            });
                                          },
                                          secondaryLabel:
                                              guidance.secondaryActionLabel,
                                          onSecondary: _pickDate,
                                        );
                                      },
                                    )
                                  : isGstExceeded
                                      ? _buildStatusPill(
                                          backgroundColor:
                                              AppColors.crimsonLight,
                                          textColor: AppColors.crimson,
                                          icon: LucideIcons.alertTriangle,
                                          label: "Check GST amount",
                                          onTap: () =>
                                              _showTacticalGuidanceSheet(
                                            context: context,
                                            title: 'Check GST amount',
                                            explanation:
                                                'For a \$${parsedAmount.toStringAsFixed(2)} purchase, GST cannot exceed \$${legalMaxGst.toStringAsFixed(2)}. The camera may have misread the tax line.',
                                            primaryLabel:
                                                'Fix to \$${legalMaxGst.toStringAsFixed(2)}',
                                            onPrimary: () {
                                              setState(() {
                                                _gstController.text =
                                                    legalMaxGst
                                                        .toStringAsFixed(2);
                                              });
                                            },
                                            secondaryLabel:
                                                'Keep \$${parsedGst.toStringAsFixed(2)}',
                                            onSecondary: () {},
                                          ),
                                        )
                                      : parsedAmount > 0
                                          ? _buildStatusPill(
                                              backgroundColor:
                                                  AppColors.emeraldLight,
                                              textColor: AppColors.emerald,
                                              icon: LucideIcons.checkCircle2,
                                              label: 'Amount entered',
                                            )
                                          : const SizedBox.shrink(),
                        ),
                      ),

                      // Interactive Date Trigger
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AdaptiveRow(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.calendar,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(
                                _dateNeedsReview
                                    ? 'Choose purchase date'
                                    : Formatters.date(_selectedDate),
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
                      if (_dateNeedsReview)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Purchase date was not read. Choose the date printed on the receipt.',
                            key: ValueKey('receipt-date-needs-review'),
                            style: AppType.secondary,
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Minimal GST Component Input Row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isGstExceeded
                                ? AppColors.crimson
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('GST component (AUD)',
                                style: AppType.secondary),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: TextField(
                                controller: _gstController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: AppType.cardNumeric.copyWith(
                                    color: isGstExceeded
                                        ? AppColor.critical
                                        : AppColor.ink),
                                decoration: const InputDecoration(
                                    prefixText: '\$ ',
                                    hintText: 'If shown',
                                    isDense: true),
                              )),
                              if (parsedAmount > 0) ...[
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _gstController.text =
                                        legalMaxGst.toStringAsFixed(2));
                                  },
                                  child: const Text('Estimate'),
                                ),
                              ],
                            ]),
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
                        value: 'Not specified',
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildInfoRow(
                        icon: LucideIcons.truck,
                        label: 'Vehicle',
                        value: vehicleName,
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildDropdownRow(
                        icon: LucideIcons.link,
                        label: 'Linked Trip',
                        value: _linkedTripId != null
                            ? (widget.appState.trips
                                    .where((t) => t.id == _linkedTripId)
                                    .map((t) =>
                                        '${t.date.day}/${t.date.month} (${t.distanceKm.toStringAsFixed(1)} km)')
                                    .firstOrNull ??
                                'Linked')
                            : 'None (Tap to link)',
                        onTap: _showTripSelectorSheet,
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildInfoRow(
                        icon: LucideIcons.percent,
                        label: 'Claim type',
                        value: _selectedCategory.isDirectlyDeductibleByDefault
                            ? 'Confirm business use'
                            : 'Logbook Scaled Claim',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Additional details', style: AppType.section),
                const SizedBox(height: 12),
                if (_suggestedTripId != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: CheckboxListTile(
                      key: const ValueKey('accept-suggested-trip'),
                      value: false,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Suggested trip link'),
                      subtitle: Text(
                        '${_autoMatchReason ?? 'A nearby trip may match this receipt.'}\nLinking a trip does not confirm business use.',
                      ),
                      onChanged: (accepted) {
                        if (accepted != true) return;
                        setState(() {
                          _linkedTripId = _suggestedTripId;
                          _suggestedTripId = null;
                          _confirmedByUser = false;
                          _detailsChanged = true;
                        });
                      },
                    ),
                  ),
                if (_linkedTripId != null) ...[
                  Builder(
                    builder: (context) {
                      final linkedTrip = widget.appState.trips
                          .where((t) => t.id == _linkedTripId)
                          .firstOrNull;

                      final tripTitle = linkedTrip != null
                          ? '${_formatTripDayMonth(linkedTrip.date)} at ${_formatTime(linkedTrip.date)} · ${linkedTrip.distanceKm.toStringAsFixed(1)} km'
                          : 'Trip $_linkedTripId';

                      final bannerSubtitle = _autoMatchReason != null &&
                              _autoMatchReason!.isNotEmpty
                          ? _autoMatchReason!
                          : (linkedTrip?.purpose.isNotEmpty == true
                              ? linkedTrip!.purpose
                              : 'Linked Evidence');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.workBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  AppColors.workBlue.withValues(alpha: 0.35)),
                        ),
                        child: AdaptiveRow(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.workBlue.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.link,
                                  color: AppColors.workBlue, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Linked trip',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.workBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tripTitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    bannerSubtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  AdaptiveRow(
                                    children: [
                                      InkWell(
                                        onTap: _showTripSelectorSheet,
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: const Text(
                                            'Change trip',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.deepNavy,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _linkedTripId = null;
                                            _autoMatchReason = null;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: AppColors.crimson
                                                    .withValues(alpha: 0.4)),
                                          ),
                                          child: const Text(
                                            'Remove link',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.crimson,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                DropdownButtonFormField<String>(
                  initialValue:
                      widget.appState.vehicles.any((v) => v.id == _vehicleId)
                          ? _vehicleId
                          : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle for this receipt'),
                  items: widget.appState.vehicles
                      .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.make} ${v.model} · ${v.regoPlate}')))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() {
                            _vehicleId = value;
                            _linkedTripId = null;
                            _suggestedTripId = null;
                            _confirmedByUser = false;
                            _detailsChanged = true;
                          }),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _currency,
                  decoration:
                      const InputDecoration(labelText: 'Receipt currency'),
                  hint:
                      const Text('Choose the currency printed on the receipt'),
                  items: {
                    if (_currency != null) _currency!,
                    'AUD',
                    'USD',
                    'NZD',
                    'EUR',
                    'GBP',
                    'THB'
                  }
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() {
                            _currency = value;
                            _confirmedByUser = false;
                            _detailsChanged = true;
                          }),
                ),
                if (_currency != null && _currency != 'AUD')
                  const Text(
                      'Kept as a draft. Foreign currency is not converted to AUD automatically.'),
                TextField(
                    controller: _abnController,
                    decoration: const InputDecoration(
                        labelText: 'Supplier ABN (if printed)')),
                TextField(
                    controller: _invoiceController,
                    decoration: const InputDecoration(
                        labelText: 'Receipt / invoice number (if printed)')),
                const SizedBox(height: 16),
                // Notes field
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      hintText:
                          'Notes (e.g. Tools, Materials, Client job site)',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (!_hasReceiptEvidence) ...[
                  _buildReceiptPhotoCard(),
                  const SizedBox(height: 16),
                ],

                _buildAllocationEditor(),

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
                          isVerified:
                              _merchantController.text.trim().isNotEmpty),
                      const SizedBox(height: 10),
                      _buildEvidenceCheck(
                          label: 'Expense Amount',
                          isVerified:
                              (double.tryParse(_amountController.text.trim()) ??
                                      0) >
                                  0),
                      const SizedBox(height: 10),
                      _buildEvidenceCheck(
                          label: 'Date & Time',
                          isVerified: !_dateNeedsReview &&
                              const AtoTaxPeriodEngine()
                                  .forDate(_selectedDate)
                                  .containsExpenseDate(_selectedDate)),
                      const SizedBox(height: 10),
                      _buildEvidenceCheck(
                          label: 'Business Category',
                          isVerified: _categoryConfirmed),
                      const SizedBox(height: 10),
                      _buildEvidenceCheck(
                          label: 'Receipt Photo Attached',
                          isVerified: _imagePath != null &&
                              File(_imagePath!).existsSync()),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                CheckboxListTile(
                  key: const ValueKey('confirm-expense-details'),
                  value: _confirmedByUser,
                  onChanged: _isSaving || _pickingReceipt
                      ? null
                      : (value) =>
                          setState(() => _confirmedByUser = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                      'I checked the amount, date, category and receipt'),
                  subtitle: Text(widget.existingExpense?.receiptAudit
                                  ?.reviewStatus ==
                              ReceiptReviewStatus.confirmed &&
                          !_detailsChanged
                      ? 'Previously confirmed. Changes require another check.'
                      : 'Saving without confirmation keeps this expense in review.'),
                ),
                const SizedBox(height: 12),

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
                  onPressed: _isSaving || _pickingReceipt
                      ? null
                      : _saveAndCommitExpense,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(
                          widget.onSaveDraft != null
                              ? 'Update Receipt Draft'
                              : widget.existingExpense != null
                                  ? 'Update Expense Record'
                                  : 'Save Expense to Vault',
                          style: AppTextStyles.button,
                        ),
                ),
              ],
            ),
          )),
    );
  }

  Widget _buildEvidenceCheck(
      {required String label, required bool isVerified}) {
    return AdaptiveRow(
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
        setState(() {
          _selectedCategory = cat;
          _categoryConfirmed = true;
          _confirmedByUser = false;
          _detailsChanged = true;
        });
        Navigator.of(ctx).pop();
      },
    );
  }

  Widget _buildDropdownRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) =>
      Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 20, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label, style: AppType.secondary),
                    const SizedBox(height: 4),
                    Text(value, style: AppType.bodyStrong),
                  ])),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ]),
          ),
        ),
      );

  Widget _buildInfoRow(
          {required IconData icon,
          required String label,
          required String value}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: AppType.secondary),
                const SizedBox(height: 4),
                Text(value, style: AppType.bodyStrong),
              ])),
        ]),
      );

  void _showTripSelectorSheet() {
    final vehicleId = _vehicleId;
    final candidateTrips = widget.appState.trips
        .where((t) => vehicleId == null || t.vehicleId == vehicleId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: AdaptiveRow(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LINK TO WORK TRIP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.muted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: AppColors.muted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              if (_linkedTripId != null) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.crimson.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.unlink,
                        color: AppColors.crimson, size: 18),
                  ),
                  title: const Text(
                    'Unlink current trip',
                    style: TextStyle(
                      color: AppColors.crimson,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Remove evidence correlation with this trip',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _linkedTripId = null;
                      _autoMatchReason = null;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
              ],
              Expanded(
                child: candidateTrips.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No candidate trips recorded for this vehicle yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: candidateTrips.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final trip = candidateTrips[index];
                          final isSelected = trip.id == _linkedTripId;
                          final dateStr =
                              '${trip.date.day}/${trip.date.month}/${trip.date.year}';
                          final timeStr =
                              '${trip.date.hour.toString().padLeft(2, '0')}:${trip.date.minute.toString().padLeft(2, '0')}';

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor:
                                AppColors.workBlue.withValues(alpha: 0.08),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.workBlue.withValues(alpha: 0.2)
                                    : AppColors.background,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.car,
                                color: isSelected
                                    ? AppColors.workBlue
                                    : AppColors.muted,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              '$dateStr ($timeStr) • ${trip.distanceKm.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: isSelected
                                    ? AppColors.workBlue
                                    : AppColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              trip.purpose.isNotEmpty
                                  ? trip.purpose
                                  : (trip.classification ==
                                          TripClassification.business
                                      ? 'Business Drive'
                                      : 'Personal Drive'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(LucideIcons.check,
                                    color: AppColors.workBlue, size: 20)
                                : const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.muted, size: 18),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _linkedTripId = trip.id;
                                _autoMatchReason =
                                    'Manual selection: Trip on $dateStr ($timeStr)';
                              });
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
