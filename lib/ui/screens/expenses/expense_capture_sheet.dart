import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../state/app_state.dart';

/// EXPENSES UI (Layer 2):
/// 5-second quick capture sheet for vehicle receipts and expenses
class ExpenseCaptureSheet extends StatefulWidget {
  final AppState appState;

  const ExpenseCaptureSheet({super.key, required this.appState});

  static Future<void> show(BuildContext context, AppState appState) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseCaptureSheet(appState: appState),
    );
  }

  @override
  State<ExpenseCaptureSheet> createState() => _ExpenseCaptureSheetState();
}

class _ExpenseCaptureSheetState extends State<ExpenseCaptureSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.fuel;
  String? _receiptPhotoPath;
  String? _selectedTripId;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _simulateCameraSnap() {
    HapticFeedback.mediumImpact();
    setState(() {
      _receiptPhotoPath = '/mock/receipts/rec_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Receipt photo captured & saved to offline vault.'),
        backgroundColor: AppColors.ink,
      ),
    );
  }

  void _saveExpense() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter a valid expense amount.'),
          backgroundColor: AppColors.crimson,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    final expense = VehicleExpense(
      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.appState.primaryVehicle?.id ?? 'default_vehicle',
      amount: amount,
      category: _selectedCategory,
      date: DateTime.now(),
      receiptPath: _receiptPhotoPath,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      linkedTripId: _selectedTripId,
    );

    widget.appState.recordExpense(expense);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.workBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(PhosphorIconsBold.receipt, color: AppColors.workBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Record Vehicle Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Input
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink),
            decoration: InputDecoration(
              prefixText: '\$AUD ',
              prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.muted),
              labelText: 'Expense Total',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 12),

          // ATO DOUBLE-CLAIM GUARD (Apple HIG: Concise, Actionable, Zero Jargon)
          if (widget.appState.primaryVehicle?.taxMethod == TaxMethod.centsPerKm &&
              (_selectedCategory == ExpenseCategory.fuel || _selectedCategory == ExpenseCategory.maintenanceTyres)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.info, color: AppColors.amber, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fuel is included in your ${(AppConstants.activeTaxRule.centsPerKmRate * 100).toInt()}¢/km rate. Saved for proof only.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.workBlue,
                    ),
                    onPressed: () {
                      widget.appState.updatePrimaryVehicleTaxMethod(TaxMethod.logbook);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched to Logbook (claims actual fuel %)')),
                      );
                    },
                    child: const Text('Logbook', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],

          // Category Dropdown
          DropdownButtonFormField<ExpenseCategory>(
            value: _selectedCategory,
            items: ExpenseCategory.values.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(cat.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (cat) {
              if (cat != null) setState(() => _selectedCategory = cat);
            },
            decoration: InputDecoration(
              labelText: 'ATO Statutory Category',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 12),

          // Receipt Camera Snap Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: _receiptPhotoPath != null ? AppColors.emerald : AppColors.border,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: _receiptPhotoPath != null ? AppColors.emeraldLight : Colors.white,
            ),
            onPressed: _simulateCameraSnap,
            icon: Icon(
              _receiptPhotoPath != null ? PhosphorIconsFill.checkCircle : PhosphorIconsBold.camera,
              color: _receiptPhotoPath != null ? AppColors.emerald : AppColors.ink,
              size: 20,
            ),
            label: Text(
              _receiptPhotoPath != null ? 'Receipt Attached (Audit Proof)' : 'Snap Receipt Photo (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _receiptPhotoPath != null ? AppColors.emerald : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Save CTA
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saveExpense,
            child: const Text('Save Expense to Evidence Vault', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
