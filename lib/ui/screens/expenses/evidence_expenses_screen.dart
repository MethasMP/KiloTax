import '../../widgets/adaptive_row.dart';
import '../../../core/theme/app_icons.dart';
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
  bool _onlyWithReceipts = false;
  bool _sortByAmount = false;

  void _showFilterSheet(BuildContext context) {
    var receiptFilter = _onlyWithReceipts;
    var amountSort = _sortByAmount;
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdaptiveRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter & Sort Expenses',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink),
                      ),
                      IconButton(
                        tooltip: 'Close filters',
                        icon: const Icon(AppIcons.close,
                            size: AppIconSize.control, color: AppColors.muted),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Receipt attached only',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                        'Hide manual expenses without photo evidence',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    value: receiptFilter,
                    activeThumbColor: AppColors.emerald,
                    onChanged: (val) {
                      setSheetState(() => receiptFilter = val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sort by amount (Highest first)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Default is newest date first',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    value: amountSort,
                    activeThumbColor: AppColors.emerald,
                    onChanged: (val) {
                      setSheetState(() => amountSort = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepNavy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _onlyWithReceipts = receiptFilter;
                        _sortByAmount = amountSort;
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Apply',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            )),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final expenses = appState.evidenceReview.expenses;

    var filtered = expenses.where((e) {
      if (_selectedFilter == 1 && !e.category.isCarExpense) return false;
      if (_selectedFilter == 2 && e.category.isCarExpense) return false;
      if (_onlyWithReceipts &&
          (e.receiptPath == null || e.receiptPath!.isEmpty)) {
        return false;
      }
      return true;
    }).toList();

    if (_sortByAmount) {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    }

    final activeExpenses = filtered.where((e) => !e.isVaultOnly).toList();
    final totalAmount =
        activeExpenses.fold(0.0, (sum, e) => sum + e.allocatedWorkAmount);
    final vaultOnlyCount = expenses.where((e) => e.isVaultOnly).length;

    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final bottomClearance = canPop
        ? (MediaQuery.paddingOf(context).bottom > 0
            ? MediaQuery.paddingOf(context).bottom + 8.0
            : 16.0)
        : 12.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Expenses · FY ${appState.activeTaxRule.financialYear}',
            style: AppTextStyles.sectionTitle),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.camera,
                color: AppColors.deepNavy, size: AppIconSize.control),
            tooltip: 'Scan Receipt',
            onPressed: () => ScanReceiptScreen.show(context, appState),
          ),
          IconButton(
            icon: const Icon(LucideIcons.sliders,
                color: AppColors.ink, size: AppIconSize.control),
            tooltip: 'Filter & Sort',
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
              child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (appState.receiptStorageWarning != null)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(appState.receiptStorageWarning!))),
              Text(appState.primaryVehicle?.displayName ?? 'Choose a vehicle',
                  style: AppTextStyles.secondaryMedium),
              const SizedBox(height: 12),
              Row(children: [
                _buildFilterTab(0, 'All'),
                _buildFilterTab(1, 'Vehicle'),
                _buildFilterTab(2, 'Business')
              ]),
              const SizedBox(height: 16),
              Text(Formatters.currency(totalAmount),
                  style: AppTextStyles.sectionTitle),
              Text(
                  vaultOnlyCount > 0
                      ? 'Recorded expenses • $vaultOnlyCount stored in records'
                      : 'Recorded expenses in this filter',
                  style: AppTextStyles.caption),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _buildEmptyState(context, appState)
              else
                for (final exp in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      key: ValueKey(exp.id),
                      onTap: () => ExpenseDetailScreen.show(context,
                          appState: appState, expense: exp),
                      borderRadius: BorderRadius.circular(14),
                      child: _buildExpenseTile(
                        merchant: exp.notes ?? exp.category.displayName,
                        category: exp.category.displayName,
                        date: Formatters.date(exp.date),
                        amount: Formatters.currency(exp.amount),
                        icon: exp.category.isCarExpense
                            ? LucideIcons.fuel
                            : LucideIcons.shoppingCart,
                        iconColor: AppColors.muted,
                        hasReceipt: exp.receiptPath?.trim().isNotEmpty ?? false,
                        isVaultOnly: exp.isVaultOnly,
                      ),
                    ),
                  ),
            ],
          )),
          // Premium Ergonomic Dual-Action Bar: [ Scan Receipt 📷 ] [ + Add Expense ]
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomClearance),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: AdaptiveRow(
              children: [
                // Primary Add Expense Button with Option Sheet (Scan or Manual)
                Expanded(
                  child: SizedBox(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () =>
                          _showAddExpenseOptions(context, appState),
                      icon: const Icon(AppIcons.add, size: AppIconSize.control),
                      label: const Text('Add Expense',
                          style: AppTextStyles.button),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
                AppIcons.expenses,
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
              'Add a receipt or enter an expense to start your records.',
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
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(AppIcons.camera,
                      color: AppColors.emerald, size: AppIconSize.control),
                ),
                title: const Text('Scan Paper Receipt',
                    style: AppTextStyles.cardPrimary),
                subtitle: const Text(
                    'Extract suggested details, then check them before saving',
                    style: AppTextStyles.caption),
                trailing: const Icon(AppIcons.next,
                    size: AppIconSize.inline, color: AppColors.muted),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScanReceiptScreen.show(context, appState);
                },
              ),
              const SizedBox(height: 10),

              // 2. Manual Entry Fallback
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.workBlueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(AppIcons.edit,
                      color: AppColors.deepNavy, size: AppIconSize.control),
                ),
                title: const Text('Manual Entry',
                    style: AppTextStyles.cardPrimary),
                subtitle: const Text(
                    'Enter amount, merchant & category directly',
                    style: AppTextStyles.caption),
                trailing: const Icon(AppIcons.next,
                    size: AppIconSize.inline, color: AppColors.muted),
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
                child:
                    const Text('Cancel', style: AppTextStyles.secondaryMedium),
              ),
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
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
    required String date,
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
        border: Border.all(color: AppColors.border),
      ),
      child: AdaptiveRow(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: AppIconSize.control),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdaptiveRow(
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
                AdaptiveRow(
                  children: [
                    Expanded(
                      child: Text(
                        '$category • $date',
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVaultOnly) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasReceipt
                            ? AppColors.emeraldLight
                            : AppColors.amberLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: AdaptiveRow(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasReceipt ? AppIcons.confirmed : AppIcons.warning,
                            size: 11,
                            color: hasReceipt
                                ? AppColors.emerald
                                : AppColors.amberDark,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            hasReceipt ? 'Receipt' : 'No photo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: hasReceipt
                                  ? AppColors.emerald
                                  : AppColors.amberDark,
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
          const Icon(AppIcons.next,
              size: AppIconSize.inline, color: AppColors.muted),
        ],
      ),
    );
  }
}
