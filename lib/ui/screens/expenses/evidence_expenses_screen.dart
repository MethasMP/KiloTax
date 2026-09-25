import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/app_state.dart';
import 'scan_receipt_screen.dart';
import 'expense_detail_screen.dart';

/// Implements Screen 11: Expenses List from UI.png
/// - Header: "Expenses" + Search / Filter icon
/// - Segmented Control: [ All ] [ Vehicle ] [ Business ]
/// - Total spent: "$1,892.45" • $26mb joo
/// - Expense cards:
///   - Bunnings $184.60 (Materials • 12 Sep 2026)
///   - Caltex $96.35 (Fuel • 10 Sep 2026)
///   - Officeworks $32.90 (Stationery • 10 Sep 2026)
///   - Repco $248.00 (Parts • 8 Sep 2026)
/// - Bottom bar CTA: "+ Add Expense"
class EvidenceExpensesScreen extends StatefulWidget {
  const EvidenceExpensesScreen({super.key});

  @override
  State<EvidenceExpensesScreen> createState() => _EvidenceExpensesScreenState();
}

class _EvidenceExpensesScreenState extends State<EvidenceExpensesScreen> {
  int _selectedFilter = 0; // 0 = All, 1 = Vehicle, 2 = Business

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final expenses = appState.expenses;

    final filtered = expenses.where((e) {
      if (_selectedFilter == 1) return e.category.isCarExpense;
      if (_selectedFilter == 2) return !e.category.isCarExpense;
      return true;
    }).toList();

    final activeExpenses = expenses.where((e) => !e.isVaultOnly).toList();
    final totalAmount = activeExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final vaultOnlyCount = expenses.where((e) => e.isVaultOnly).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Expenses',
          style: AppTextStyles.sectionTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.camera, color: AppColors.deepNavy, size: 22),
            tooltip: 'Scan Receipt',
            onPressed: () => ScanReceiptScreen.show(context, appState),
          ),
          IconButton(
            icon: const Icon(LucideIcons.sliders, color: AppColors.ink, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Segmented Filter Control: All | Vehicle | Business
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildFilterTab(0, 'All'),
                      _buildFilterTab(1, 'Vehicle'),
                      _buildFilterTab(2, 'Business'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Total Spent Amount Hero (Dynamic from live AppState)
                Text(
                  Formatters.currency(totalAmount),
                  style: AppTextStyles.heroNumber,
                ),
                const SizedBox(height: 2),
                Text(
                  vaultOnlyCount > 0
                      ? 'Total deductible claimable • $vaultOnlyCount stored in records'
                      : 'Total deductible expenses recorded',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable Expense Feed
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(context, appState)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final exp = filtered[index];
                      final hasReceipt = exp.receiptPath != null && exp.receiptPath!.isNotEmpty;
                      return InkWell(
                        key: ValueKey(exp.id),
                        onTap: () => ExpenseDetailScreen.show(
                          context,
                          appState: appState,
                          expense: exp,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: _buildExpenseTile(
                          merchant: exp.notes ?? exp.category.displayName,
                          category: exp.category.displayName,
                          amount: Formatters.currency(exp.amount),
                          icon: exp.category.isCarExpense ? LucideIcons.fuel : LucideIcons.shoppingCart,
                          iconColor: exp.category.isCarExpense ? AppColors.crimson : AppColors.emerald,
                          hasReceipt: hasReceipt,
                          isVaultOnly: exp.isVaultOnly,
                        ),
                      );
                    },
                  ),
          ),

          // Premium Ergonomic Dual-Action Bar: [ Scan Receipt 📷 ] [ + Add Expense ]
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                // Quick Camera Scan Action (Fast 1-tap receipt scanner)
                InkWell(
                  onTap: () => ScanReceiptScreen.show(context, appState),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.camera, color: AppColors.emerald, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Scan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Primary Add Expense Button with Option Sheet (Scan or Manual)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => _showAddExpenseOptions(context, appState),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add Expense', style: AppTextStyles.button),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState appState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.receipt,
                size: 32,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No expenses recorded yet',
              style: AppTextStyles.cardPrimary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Scan receipts or record expenses to build audit-proof tax deductions.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseOptions(BuildContext context, AppState appState) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Record Expense',
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how you want to substantiate this tax expense',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // 1. Scan Receipt
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.camera, color: AppColors.emerald, size: 20),
                ),
                title: const Text('Scan Paper Receipt', style: AppTextStyles.cardPrimary),
                subtitle: const Text('Instant OCR auto-extracts amount & merchant', style: AppTextStyles.caption),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScanReceiptScreen.show(context, appState);
                },
              ),
              const SizedBox(height: 10),

              // 2. Manual Entry Fallback
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.workBlueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.pencil, color: AppColors.deepNavy, size: 20),
                ),
                title: const Text('Manual Entry', style: AppTextStyles.cardPrimary),
                subtitle: const Text('Enter amount, merchant & category directly', style: AppTextStyles.caption),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailScreen(
                        appState: appState,
                        merchant: '',
                        amount: 0.0,
                        categoryName: 'Materials',
                        receiptDate: DateTime.now(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: AppTextStyles.secondaryMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
              color: isSelected ? AppColors.deepNavy : AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile({
    required String merchant,
    required String category,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required bool hasReceipt,
    bool isVaultOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: !hasReceipt ? AppColors.amber.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        merchant,
                        style: AppTextStyles.cardPrimary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(amount, style: AppTextStyles.cardPrimary),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVaultOnly) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Record only',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Evidence Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasReceipt ? AppColors.emeraldLight : AppColors.amberLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasReceipt ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
                            size: 11,
                            color: hasReceipt ? AppColors.emerald : AppColors.amberDark,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            hasReceipt ? 'Receipt' : 'No photo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: hasReceipt ? AppColors.emerald : AppColors.amberDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.muted),
        ],
      ),
    );
  }
}
