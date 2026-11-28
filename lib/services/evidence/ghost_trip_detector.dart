import 'package:flutter/foundation.dart';

import '../../data/models/trade_persona.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../tracking/trade_poi_resolver.dart';

/// An unlogged drive candidate inferred from a scanned receipt that has no
/// matching trip within the ±45 minute temporal window.
@immutable
class GhostTripCandidate {
  final String id;
  final VehicleExpense expense;
  final String merchantName;
  final DateTime receiptTimestamp;
  final double amount;
  final String suggestedPurpose;
  final int windowMinutes;
  final String confidenceLabel;
  final String promptText;

  const GhostTripCandidate({
    required this.id,
    required this.expense,
    required this.merchantName,
    required this.receiptTimestamp,
    required this.amount,
    required this.suggestedPurpose,
    required this.windowMinutes,
    required this.confidenceLabel,
    required this.promptText,
  });
}

/// Axis C: Receipt-Triggered Ghost Trip Detector
/// Cross-references scanned physical-travel receipts (fuel, tools/materials,
/// tolls/parking, servicing) against the Trip ledger within ±45 minutes to
/// surface unlogged drive candidates.
class GhostTripDetector {
  GhostTripDetector._();

  static const Duration defaultMatchWindow = Duration(minutes: 45);

  /// Detects receipts that imply vehicle travel but lack a linked or temporally
  /// matching trip within ±[matchWindow].
  static List<GhostTripCandidate> detectGhostTrips({
    required List<VehicleExpense> expenses,
    required List<Trip> trips,
    Duration matchWindow = defaultMatchWindow,
    TradePersona? persona,
  }) {
    final activeTrips = trips.where((t) => !t.isDeleted).toList();
    final candidates = <GhostTripCandidate>[];

    for (final expense in expenses) {
      if (expense.isDeleted) continue;
      if (!_impliesPhysicalTravel(expense.category)) continue;

      final hasLinkedTrip = activeTrips.any(
        (t) =>
            t.id == expense.linkedTripId ||
            t.linkedExpenseIds.contains(expense.id),
      );
      if (hasLinkedTrip) continue;

      final hasNearbyTrip = activeTrips.any((t) {
        if (t.vehicleId != expense.vehicleId) return false;
        final startDiff = t.date.difference(expense.date).abs();
        final endDiff = t.stoppedAt != null
            ? t.stoppedAt!.difference(expense.date).abs()
            : startDiff;
        return startDiff <= matchWindow || endDiff <= matchWindow;
      });
      if (hasNearbyTrip) continue;

      final merchant = (expense.supplier != null &&
              expense.supplier!.trim().isNotEmpty)
          ? expense.supplier!.trim()
          : expense.category.displayName;

      final tradeMatch = TradePoiResolver.resolve(merchant, persona: persona);
      final suggestedPurpose = tradeMatch?.suggestedPurpose ??
          (expense.category == ExpenseCategory.fuel
              ? 'Fuel / Refuelling Run'
              : expense.category == ExpenseCategory.maintenanceTyres
                  ? 'Vehicle Servicing / Repairs'
                  : 'Supplies Run');

      final confidence = (tradeMatch != null ||
              expense.category == ExpenseCategory.fuel)
          ? 'High — Trade/Fuel Receipt'
          : 'Medium — Expense Receipt';

      final hh = expense.date.hour.toString().padLeft(2, '0');
      final mm = expense.date.minute.toString().padLeft(2, '0');

      candidates.add(
        GhostTripCandidate(
          id: 'ghost_${expense.id}',
          expense: expense,
          merchantName: merchant,
          receiptTimestamp: expense.date,
          amount: expense.amount,
          suggestedPurpose: suggestedPurpose,
          windowMinutes: matchWindow.inMinutes,
          confidenceLabel: confidence,
          promptText:
              'You scanned a \$${expense.amount.toStringAsFixed(2)} receipt at $merchant at $hh:$mm — was there an unlogged drive there?',
        ),
      );
    }

    candidates
        .sort((a, b) => b.receiptTimestamp.compareTo(a.receiptTimestamp));
    return List.unmodifiable(candidates);
  }

  static bool _impliesPhysicalTravel(ExpenseCategory category) {
    return category == ExpenseCategory.fuel ||
        category == ExpenseCategory.toolsMaterials ||
        category == ExpenseCategory.tollsParking ||
        category == ExpenseCategory.maintenanceTyres;
  }
}
