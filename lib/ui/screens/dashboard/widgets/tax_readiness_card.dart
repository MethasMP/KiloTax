import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_expense.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_quick_resolve_sheet.dart';
import '../../trips/trip_review_sheet.dart';

class TaxReadinessCard extends StatelessWidget {
  final AppState appState;

  const TaxReadinessCard({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;
    final missingTrips = appState.missingComplianceTrips;
    final missingExpenses = isLogbook ? appState.unclassifiedExpenses : <VehicleExpense>[];
    final totalActionItems = missingTrips.length + missingExpenses.length;
    final score = appState.taxReadinessScore;

    if (totalActionItems == 0) {
      return const SizedBox.shrink();
    }

    String headline;
    if (missingTrips.isNotEmpty && missingExpenses.isNotEmpty) {
      headline = '${missingTrips.length} trips & ${missingExpenses.length} receipts need attention';
    } else if (missingTrips.isNotEmpty) {
      headline = '${missingTrips.length} ${missingTrips.length == 1 ? "trip needs" : "trips need"} a purpose';
    } else {
      headline = '${missingExpenses.length} ${missingExpenses.length == 1 ? "receipt needs" : "receipts need"} backup photo';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.alertTriangle, color: AppColors.amberDark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'NEEDS ATTENTION',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.amberDark, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amberDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$score%',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.ink),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              if (missingTrips.isNotEmpty) {
                TripQuickResolveSheet.show(context, trip: missingTrips.first, appState: appState);
              } else {
                TripReviewSheet.show(context, appState);
              }
            },
            child: const Row(
              children: [
                Text('Fix now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.deepNavy)),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.deepNavy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
