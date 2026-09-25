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

  Map<String, String> _buildHeaders([String? userToken]) => {
        'apikey': anonKey,
        'Authorization': 'Bearer ${userToken ?? anonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=representation',
      };

  Map<String, String> get headers => _buildHeaders();

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
    String? userToken,
    String? userId,
  }) async {
    try {
      final headers = _buildHeaders(userToken);
      final eligibleTrips = trips.where((t) => t.isBusiness && !t.isDeleted).toList();
      final ignoredPersonalCount = trips.length - eligibleTrips.length;
      final eligibleExpenses = expenses.where((e) => !e.isDeleted).toList();

      int syncedTripCount = 0;
      int syncedExpenseCount = 0;

      // 1. Ensure Vehicle exists in Cloud (FK Dependency)
      final vehicleUri = Uri.parse('$supabaseUrl/rest/v1/vehicles?on_conflict=client_dedup_id');
      final vehicleDedupId = vehicle.clientDedupId ?? 'veh_${vehicle.regoPlate.trim().toUpperCase()}';
      final vehiclePayload = [
        {
          'id': vehicle.id,
          if (userId != null) 'user_id': userId,
          'make': vehicle.make,
          'model': vehicle.model,
          'rego_plate': vehicle.regoPlate,
          'initial_odometer': vehicle.initialOdometer,
          'engine_capacity': vehicle.engineCapacity,
          'vehicle_type': vehicle.vehicleType.name,
          'bluetooth_device_name': vehicle.bluetoothDeviceName,
          'is_primary': vehicle.isPrimary,
          'tax_method': vehicle.taxMethod.name,
          'logbook_start_date': vehicle.logbookStartDate?.toIso8601String(),
          'client_dedup_id': vehicleDedupId,
          'updated_at': DateTime.now().toIso8601String(),
        }
      ];

      await _httpClient.post(
        vehicleUri,
        headers: headers,
        body: jsonEncode(vehiclePayload),
      );

      if (eligibleTrips.isNotEmpty) {
        final tripPayloads = eligibleTrips.map((t) {
          final dedupId = t.clientDedupId ?? generateTripDedupKey(t);
          return {
            'id': t.id,
            if (userId != null) 'user_id': userId,
            'vehicle_id': vehicle.id,
            'date': t.date.toIso8601String(),
            'distance_km': t.distanceKm,
            'purpose': t.purpose,
            'start_odometer': t.startOdometer,
            'end_odometer': t.endOdometer,
            'classification': 'business',
            'origin_address': t.originAddress,
            'destination_address': t.destinationAddress,
            'tax_method': t.taxMethod.name,
            'evidence_source': t.evidenceSource,
            'client_dedup_id': dedupId,
            'deleted_at': t.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        }).toList();

        final tripUri = Uri.parse('$supabaseUrl/rest/v1/trips?on_conflict=client_dedup_id');
        final res = await _httpClient.post(
          tripUri,
          headers: headers,
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
            if (userId != null) 'user_id': userId,
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
          headers: headers,
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

  /// RESTORE FROM CLOUD: Pulls existing vehicles, trips, and expenses
  /// Allows instant data recovery when reinstalling the app or switching devices.
  Future<CloudRestoreResult> restoreFromCloud({
    String? vehicleId,
    String? userToken,
    String? userId,
  }) async {
    try {
      final headers = _buildHeaders(userToken);
      final userFilter = userId != null ? '&user_id=eq.$userId' : '';

      // 1. Fetch Vehicles
      final vehUri = Uri.parse('$supabaseUrl/rest/v1/vehicles?select=*$userFilter');
      final vehRes = await _httpClient.get(vehUri, headers: headers);

      final List<Vehicle> restoredVehicles = [];
      if (vehRes.statusCode >= 200 && vehRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(vehRes.body);
        for (final item in data) {
          try {
            restoredVehicles.add(Vehicle.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }

      // 2. Fetch Trips
      final tripFilter = vehicleId != null ? '&vehicle_id=eq.$vehicleId' : '';
      final tripUri = Uri.parse('$supabaseUrl/rest/v1/trips?select=*$userFilter$tripFilter&order=date.asc');
      final tripRes = await _httpClient.get(tripUri, headers: headers);

      final List<Trip> restoredTrips = [];
      if (tripRes.statusCode >= 200 && tripRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(tripRes.body);
        for (final item in data) {
          try {
            restoredTrips.add(Trip.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }

      // 3. Fetch Expenses
      final expFilter = vehicleId != null ? '&vehicle_id=eq.$vehicleId' : '';
      final expUri = Uri.parse('$supabaseUrl/rest/v1/expenses?select=*$userFilter$expFilter&order=date.asc');
      final expRes = await _httpClient.get(expUri, headers: headers);

      final List<VehicleExpense> restoredExpenses = [];
      if (expRes.statusCode >= 200 && expRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(expRes.body);
        for (final item in data) {
          try {
            restoredExpenses.add(VehicleExpense.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }

      return CloudRestoreResult(
        success: true,
        vehicles: restoredVehicles,
        trips: restoredTrips,
        expenses: restoredExpenses,
      );
    } catch (e) {
      return CloudRestoreResult(
        success: false,
        vehicles: [],
        trips: [],
        expenses: [],
        errorMessage: e.toString(),
      );
    }
  }
}

class CloudRestoreResult {
  final bool success;
  final List<Vehicle> vehicles;
  final List<Trip> trips;
  final List<VehicleExpense> expenses;
  final String? errorMessage;

  CloudRestoreResult({
    required this.success,
    required this.vehicles,
    required this.trips,
    required this.expenses,
    this.errorMessage,
  });
}
