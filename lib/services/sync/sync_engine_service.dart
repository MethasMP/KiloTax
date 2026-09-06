import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';

class SyncResult {
  final bool success;
  final int syncedTrips;
  final int syncedExpenses;
  final int rejectedOrIgnored;
  final String? errorMessage;

  SyncResult({
    required this.success,
    required this.syncedTrips,
    required this.syncedExpenses,
    required this.rejectedOrIgnored,
    this.errorMessage,
  });
}

class SyncEngineService {
  final String supabaseUrl;
  final String anonKey;
  final http.Client _httpClient;

  SyncEngineService({
    String? supabaseUrl,
    String? anonKey,
    http.Client? httpClient,
  })  : supabaseUrl = supabaseUrl ?? AppConstants.supabaseUrl,
        anonKey = anonKey ?? AppConstants.supabaseAnonKey,
        _httpClient = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=representation',
      };

  static String generateTripDedupKey(Trip trip) {
    final raw = '${trip.vehicleId}_${trip.date.toIso8601String()}_${trip.startOdometer}_${trip.endOdometer}_${trip.distanceKm}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static String generateExpenseDedupKey(VehicleExpense expense) {
    final raw = '${expense.vehicleId}_${expense.date.toIso8601String()}_${expense.amount}_${expense.category.name}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<SyncResult> syncToCloud({
    required Vehicle vehicle,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
  }) async {
    try {
      final eligibleTrips = trips.where((t) => t.isBusiness && !t.isDeleted).toList();
      final ignoredPersonalCount = trips.length - eligibleTrips.length;
      final eligibleExpenses = expenses.where((e) => !e.isDeleted).toList();

      int syncedTripCount = 0;
      int syncedExpenseCount = 0;

      if (eligibleTrips.isNotEmpty) {
        final tripPayloads = eligibleTrips.map((t) {
          final dedupId = t.clientDedupId ?? generateTripDedupKey(t);
          return {
            'id': t.id,
            'vehicle_id': vehicle.id,
            'date': t.date.toIso8601String(),
            'distance_km': t.distanceKm,
            'purpose': t.purpose,
            'start_odometer': t.startOdometer,
            'end_odometer': t.endOdometer,
            'classification': 'business',
            'origin_address': t.originAddress,
            'destination_address': t.destinationAddress,
            'client_dedup_id': dedupId,
            'deleted_at': t.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        }).toList();

        final tripUri = Uri.parse('$supabaseUrl/rest/v1/trips?on_conflict=client_dedup_id');
        final res = await _httpClient.post(
          tripUri,
          headers: _headers,
          body: jsonEncode(tripPayloads),
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          syncedTripCount = eligibleTrips.length;
        }
      }

      if (eligibleExpenses.isNotEmpty) {
        final expensePayloads = eligibleExpenses.map((e) {
          final dedupId = e.clientDedupId ?? generateExpenseDedupKey(e);
          return {
            'id': e.id,
            'vehicle_id': vehicle.id,
            'linked_trip_id': e.linkedTripId,
            'date': e.date.toIso8601String(),
            'amount': e.amount,
            'category': e.category.name,
            'notes': e.notes,
            'receipt_storage_path': e.receiptPath,
            'business_percentage': e.businessPercentage,
            'client_dedup_id': dedupId,
            'deleted_at': e.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        }).toList();

        final expUri = Uri.parse('$supabaseUrl/rest/v1/expenses?on_conflict=client_dedup_id');
        final expRes = await _httpClient.post(
          expUri,
          headers: _headers,
          body: jsonEncode(expensePayloads),
        );

        if (expRes.statusCode >= 200 && expRes.statusCode < 300) {
          syncedExpenseCount = eligibleExpenses.length;
        }
      }

      return SyncResult(
        success: true,
        syncedTrips: syncedTripCount,
        syncedExpenses: syncedExpenseCount,
        rejectedOrIgnored: ignoredPersonalCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: 0,
        errorMessage: e.toString(),
      );
    }
  }
}
