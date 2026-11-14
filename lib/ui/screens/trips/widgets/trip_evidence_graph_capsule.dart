import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/models/vehicle_expense.dart';
import '../../../../state/app_state.dart';
import '../../../widgets/adaptive_row.dart';
import '../../expenses/expense_detail_screen.dart';

class TripEvidenceGraphCapsule extends StatelessWidget {
  final Trip trip;
  final AppState appState;

  const TripEvidenceGraphCapsule({
    super.key,
    required this.trip,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final linkedExpenses = trip.linkedExpenseIds
        .map((id) => appState.expenses.cast<VehicleExpense?>().firstWhere(
              (e) => e?.id == id,
              orElse: () => null,
            ))
        .whereType<VehicleExpense>()
        .toList();

    if (linkedExpenses.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColor.scrimSoft,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdaptiveRow(
            children: [
              Icon(LucideIcons.link, size: 16, color: AppColors.deepNavy),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Evidence Graph & Substantiation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Direct ATO audit chain linking trip telemetry to verified tax substantiation.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ...linkedExpenses.map((expense) {
            final isBunningsOrTools = expense.category ==
                    ExpenseCategory.toolsMaterials ||
                (expense.notes?.toLowerCase().contains('bunnings') ?? false);
            final isFuel = expense.category == ExpenseCategory.fuel;
            final iconData = isFuel
                ? LucideIcons.fuel
                : (isBunningsOrTools
                    ? LucideIcons.hammer
                    : LucideIcons.receipt);
            final merchantName = (expense.notes?.isNotEmpty == true)
                ? expense.notes!
                : expense.category.displayName;
            final hasSha256 = (expense.sha256Hash?.isNotEmpty ?? false) ||
                (expense.receiptAudit?.sha256Hash?.isNotEmpty ?? false);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: AppColor.surfaceSunken,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ExpenseDetailScreen.show(
                      context,
                      expense: expense,
                      appState: appState,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AdaptiveRow(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(iconData,
                              size: 18, color: AppColors.deepNavy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                merchantName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              AdaptiveRow(
                                children: [
                                  Text(
                                    '\$${expense.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                  if (expense.gstAmount != null &&
                                      expense.gstAmount! > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(incl. \$${expense.gstAmount!.toStringAsFixed(2)} GST)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (hasSha256)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColor.positiveTint,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColor.positiveTintStrong,
                                  width: 0.5),
                            ),
                            child: const AdaptiveRow(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.shieldCheck,
                                    size: 11, color: AppColor.positiveStrong),
                                SizedBox(width: 3),
                                Text(
                                  'SHA-256 Verified',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColor.positiveStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }


}
