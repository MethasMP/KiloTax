import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_expense.dart';
import '../../../../state/app_state.dart';

class HomeRecentActivity extends StatelessWidget {
  final AppState appState;

  const HomeRecentActivity({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final primaryVehId = appState.primaryVehicle?.id;
    // Vehicle-isolated streams to prevent cross-vehicle evidence bleeding
    final trips = primaryVehId != null
        ? appState.trips.where((t) => t.vehicleId == primaryVehId).toList()
        : appState.trips;
    final expenses = primaryVehId != null
        ? appState.expenses.where((e) => e.vehicleId == primaryVehId).toList()
        : appState.expenses;
    final hasActivity = trips.isNotEmpty || expenses.isNotEmpty;

    final isCpk = appState.primaryVehicle?.taxMethod == TaxMethod.centsPerKm;
    final countLabel = isCpk
        ? '${trips.length} drives'
        : '${trips.length} drives • ${expenses.length} receipts';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Evidence',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
            ),
            Text(
              countLabel,
              style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!hasActivity)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(LucideIcons.carFront, color: AppColors.muted, size: 28),
                  SizedBox(height: 10),
                  Text(
                    'No drives recorded yet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your work drives and tax evidence will appear here',
                    style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Show up to 3 trips
                for (int i = 0; i < trips.take(3).length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _buildTripActivityRow(trips.elementAt(i)),
                ],
                // Show up to 2 latest expenses if any
                for (int i = 0; i < expenses.take(2).length; i++) ...[
                  if (trips.isNotEmpty || i > 0) const Divider(height: 1, color: AppColors.border),
                  _buildExpenseActivityRow(expenses.elementAt(i)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTripActivityRow(Trip trip) {
    final isBusiness = trip.classification == TripClassification.business;
    final time = Formatters.date(trip.date);
    final destination = '${trip.originAddress ?? "Origin"} → ${trip.destinationAddress ?? "Destination"}';
    final type = trip.purpose.isNotEmpty ? trip.purpose : (isBusiness ? 'Work drive' : 'Personal');
    final distance = '${trip.distanceKm.toStringAsFixed(1)} km';
    final claimValue = Formatters.currency(trip.distanceKm * appState.activeTaxRule.centsPerKmRate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.navigation, size: 18, color: AppColors.deepNavy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '$time · $type',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'GPS ✓',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                distance,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                claimValue,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: AppColors.emerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseActivityRow(VehicleExpense expense) {
    final time = Formatters.date(expense.date);
    final category = expense.category.displayName;
    final hasReceipt = expense.receiptPath != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.emeraldLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.receipt, size: 18, color: AppColors.emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (expense.notes != null && expense.notes!.isNotEmpty) ? expense.notes! : category,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasReceipt) ...[
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.checkCircle2, size: 12, color: AppColors.emerald),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$time · $category',
                  style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.currency(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.emerald),
          ),
        ],
      ),
    );
  }
}
