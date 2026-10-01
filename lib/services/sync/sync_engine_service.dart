import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';
import '../auth/supabase_auth_service.dart';
import '../storage/receipt_storage_service.dart';

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
  final AuthUser? currentUser;
  final ReceiptStorageService _receiptStorageService;

  bool get isAuthenticated => currentUser != null;
  ReceiptStorageService get receiptStorageService => _receiptStorageService;

  SyncEngineService({
    String? supabaseUrl,
    String? anonKey,
    http.Client? httpClient,
    this.currentUser,
    ReceiptStorageService? receiptStorageService,
  })  : supabaseUrl = supabaseUrl ?? AppConstants.supabaseUrl,
        anonKey = anonKey ?? AppConstants.supabaseAnonKey,
        _httpClient = httpClient ?? http.Client(),
        _receiptStorageService = receiptStorageService ??
            ReceiptStorageService(
              supabaseUrl: supabaseUrl,
              anonKey: anonKey,
              httpClient: httpClient,
            );

  Map<String, String> _buildHeaders([String? userToken]) => {
        'apikey': anonKey,
        'Authorization': 'Bearer ${userToken ?? anonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=representation',
      };

  Map<String, String> get headers => _buildHeaders();

  static String generateTripDedupKey(Trip trip) {
    final raw =
        '${trip.vehicleId}_${trip.date.toIso8601String()}_${trip.startOdometer}_${trip.endOdometer}_${trip.distanceKm}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static String generateExpenseDedupKey(VehicleExpense expense) {
    final raw =
        '${expense.vehicleId}_${expense.date.toIso8601String()}_${expense.amount}_${expense.category.name}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<SyncResult> syncToCloud({
    required Vehicle vehicle,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    String? userToken,
    String? userId,
    bool requireAuth = false,
  }) async {
    final effectiveUserId = userId ?? currentUser?.id;
    final effectiveUserToken = userToken ?? currentUser?.accessToken;

    if (requireAuth && (!isAuthenticated || currentUser == null) && effectiveUserId == null) {
      return SyncResult(
        success: false,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: 0,
        errorMessage: 'User is not authenticated. Sync aborted.',
      );
    }

    try {
      final headers = _buildHeaders(effectiveUserToken);
      // Sync ALL non-deleted trips (both business and personal) so continuous odometer
      // and statutory business use percentage are strictly preserved on cloud restore.
      final eligibleTrips = trips.where((t) => !t.isDeleted).toList();
      final ignoredCount = trips.length - eligibleTrips.length;
      final eligibleExpenses = expenses.where((e) => !e.isDeleted).toList();

      int syncedTripCount = 0;
      int syncedExpenseCount = 0;

      // 1. Upload vehicle start/finish odometer photos to Supabase Storage if local files exist
      String? startOdoCloudPath = vehicle.startOdometerPhotoPath;
      if (startOdoCloudPath != null && startOdoCloudPath.isNotEmpty) {
        final f = File(startOdoCloudPath);
        if (f.existsSync()) {
          final uploaded = await _receiptStorageService.uploadOdometerPhoto(
            file: f,
            userId: effectiveUserId ?? 'anon',
            vehicleId: vehicle.id,
            isStart: true,
            userToken: effectiveUserToken,
          );
          if (uploaded != null) {
            startOdoCloudPath = uploaded;
          }
        }
      }

      String? endOdoCloudPath = vehicle.endOdometerPhotoPath;
      if (endOdoCloudPath != null && endOdoCloudPath.isNotEmpty) {
        final f = File(endOdoCloudPath);
        if (f.existsSync()) {
          final uploaded = await _receiptStorageService.uploadOdometerPhoto(
            file: f,
            userId: effectiveUserId ?? 'anon',
            vehicleId: vehicle.id,
            isStart: false,
            userToken: effectiveUserToken,
          );
          if (uploaded != null) {
            endOdoCloudPath = uploaded;
          }
        }
      }

      // Ensure Vehicle exists in Cloud (FK Dependency)
      final vehicleUri = Uri.parse(
          '$supabaseUrl/rest/v1/vehicles?on_conflict=client_dedup_id');
      final vehicleDedupId = vehicle.clientDedupId ??
          'veh_${vehicle.regoPlate.trim().toUpperCase()}';
      final vehiclePayload = [
        {
          'id': vehicle.id,
          if (effectiveUserId != null) 'user_id': effectiveUserId,
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
          'start_odometer_photo_path': startOdoCloudPath,
          'start_odometer_verified_at':
              vehicle.startOdometerVerifiedAt?.toIso8601String(),
          'start_odometer_image_hash': vehicle.startOdometerImageHash,
          'end_odometer_photo_path': endOdoCloudPath,
          'end_odometer_verified_at':
              vehicle.endOdometerVerifiedAt?.toIso8601String(),
          'end_odometer_image_hash': vehicle.endOdometerImageHash,
          'updated_at': DateTime.now().toIso8601String(),
        }
      ];

      await _httpClient.post(
        vehicleUri,
        headers: headers,
        body: jsonEncode(vehiclePayload),
      );

      // 2. Sync Trips (personal and business)
      if (eligibleTrips.isNotEmpty) {
        final tripPayloads = eligibleTrips.map((t) {
          final dedupId = t.clientDedupId ?? generateTripDedupKey(t);
          final isBiz = t.isBusiness;
          return {
            'id': t.id,
            if (effectiveUserId != null) 'user_id': effectiveUserId,
            'vehicle_id': vehicle.id,
            'date': t.date.toIso8601String(),
            'distance_km': t.distanceKm,
            // Mask personal details for privacy while preserving statutory odometer
            'purpose': isBiz ? t.purpose : 'Personal',
            'start_odometer': t.startOdometer,
            'end_odometer': t.endOdometer,
            'classification': isBiz ? 'business' : 'personal',
            'origin_address': isBiz
                ? t.originAddress
                : (t.originAddress != null && t.originAddress!.isNotEmpty
                    ? 'Personal Location'
                    : null),
            'destination_address': isBiz
                ? t.destinationAddress
                : (t.destinationAddress != null &&
                        t.destinationAddress!.isNotEmpty
                    ? 'Personal Destination'
                    : null),
            'tax_method': t.taxMethod.name,
            'evidence_source': t.evidenceSource,
            'client_dedup_id': dedupId,
            'deleted_at': t.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        }).toList();

        final tripUri =
            Uri.parse('$supabaseUrl/rest/v1/trips?on_conflict=client_dedup_id');
        final res = await _httpClient.post(
          tripUri,
          headers: headers,
          body: jsonEncode(tripPayloads),
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          syncedTripCount = eligibleTrips.length;
        }
      }

      // 3. Sync Expenses and upload receipt binaries
      if (eligibleExpenses.isNotEmpty) {
        final expensePayloads = <Map<String, dynamic>>[];
        for (final e in eligibleExpenses) {
          final dedupId = e.clientDedupId ?? generateExpenseDedupKey(e);
          String? cloudReceiptPath = e.receiptPath;

          // If local receipt file exists on disk, upload binary to Supabase Storage
          if (cloudReceiptPath != null && cloudReceiptPath.isNotEmpty) {
            final localFile = File(cloudReceiptPath);
            if (localFile.existsSync()) {
              final uploaded = await _receiptStorageService.uploadExpenseReceipt(
                file: localFile,
                userId: effectiveUserId ?? 'anon',
                expenseId: e.id,
                userToken: effectiveUserToken,
              );
              if (uploaded != null) {
                cloudReceiptPath = uploaded;
              }
            }
          }

          expensePayloads.add({
            'id': e.id,
            if (effectiveUserId != null) 'user_id': effectiveUserId,
            'vehicle_id': vehicle.id,
            'linked_trip_id': e.linkedTripId,
            'date': e.date.toIso8601String(),
            'amount': e.amount,
            'gst_amount': e.gstAmount,
            'category': e.category.name,
            'notes': e.notes,
            'receipt_storage_path': cloudReceiptPath,
            'business_percentage': e.businessPercentage,
            'client_dedup_id': dedupId,
            'deleted_at': e.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        final expUri = Uri.parse(
            '$supabaseUrl/rest/v1/expenses?on_conflict=client_dedup_id');
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
        rejectedOrIgnored: ignoredCount,
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
    bool requireAuth = false,
    Directory? localCacheDir,
  }) async {
    final effectiveUserId = userId ?? currentUser?.id;
    final effectiveUserToken = userToken ?? currentUser?.accessToken;

    if (requireAuth && (!isAuthenticated || currentUser == null) && effectiveUserId == null) {
      return CloudRestoreResult(
        success: false,
        vehicles: [],
        trips: [],
        expenses: [],
        corruptedRecordsCount: 0,
        errorMessage: 'User is not authenticated. Restore aborted.',
      );
    }

    try {
      final headers = _buildHeaders(effectiveUserToken);
      final userFilter = effectiveUserId != null ? '&user_id=eq.$effectiveUserId' : '';

      // 1. Fetch Vehicles
      final vehUri =
          Uri.parse('$supabaseUrl/rest/v1/vehicles?select=*$userFilter');
      final vehRes = await _httpClient.get(vehUri, headers: headers);

      int failedRecords = 0;

      final List<Vehicle> restoredVehicles = [];
      if (vehRes.statusCode >= 200 && vehRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(vehRes.body);
        for (final item in data) {
          try {
            restoredVehicles
                .add(Vehicle.fromJson(item as Map<String, dynamic>));
          } catch (e, stack) {
            failedRecords++;
            debugPrint(
                '[SyncEngine] Warning parsing vehicle record: $e\n$stack');
          }
        }
      }

      // 2. Fetch Trips
      final tripFilter = vehicleId != null ? '&vehicle_id=eq.$vehicleId' : '';
      final tripUri = Uri.parse(
          '$supabaseUrl/rest/v1/trips?select=*$userFilter$tripFilter&order=date.asc');
      final tripRes = await _httpClient.get(tripUri, headers: headers);

      final List<Trip> restoredTrips = [];
      if (tripRes.statusCode >= 200 && tripRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(tripRes.body);
        for (final item in data) {
          try {
            restoredTrips.add(Trip.fromJson(item as Map<String, dynamic>));
          } catch (e, stack) {
            failedRecords++;
            debugPrint('[SyncEngine] Warning parsing trip record: $e\n$stack');
          }
        }
      }

      // 3. Fetch Expenses
      final expFilter = vehicleId != null ? '&vehicle_id=eq.$vehicleId' : '';
      final expUri = Uri.parse(
          '$supabaseUrl/rest/v1/expenses?select=*$userFilter$expFilter&order=date.asc');
      final expRes = await _httpClient.get(expUri, headers: headers);

      final List<VehicleExpense> restoredExpenses = [];
      if (expRes.statusCode >= 200 && expRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(expRes.body);
        for (final item in data) {
          try {
            restoredExpenses
                .add(VehicleExpense.fromJson(item as Map<String, dynamic>));
          } catch (e, stack) {
            failedRecords++;
            debugPrint(
                '[SyncEngine] Warning parsing expense record: $e\n$stack');
          }
        }
      }

      // 4. Download and cache remote receipt images and odometer photos if cache dir provided
      if (localCacheDir != null) {
        for (int i = 0; i < restoredExpenses.length; i++) {
          final exp = restoredExpenses[i];
          if (exp.receiptPath != null && exp.receiptPath!.isNotEmpty) {
            final f = File(exp.receiptPath!);
            if (!f.existsSync()) {
              final targetLocal = '${localCacheDir.path}/${exp.id}.webp';
              final cached = await _receiptStorageService.downloadAndCacheReceipt(
                remotePath: exp.receiptPath!,
                targetLocalPath: targetLocal,
                userToken: effectiveUserToken,
              );
              if (cached != null) {
                restoredExpenses[i] = exp.copyWith(receiptPath: cached.path);
              }
            }
          }
        }

        for (int i = 0; i < restoredVehicles.length; i++) {
          var veh = restoredVehicles[i];
          if (veh.startOdometerPhotoPath != null &&
              veh.startOdometerPhotoPath!.isNotEmpty) {
            final f = File(veh.startOdometerPhotoPath!);
            if (!f.existsSync()) {
              final targetLocal =
                  '${localCacheDir.path}/odometer_${veh.id}_start.webp';
              final cached = await _receiptStorageService.downloadAndCacheReceipt(
                remotePath: veh.startOdometerPhotoPath!,
                targetLocalPath: targetLocal,
                userToken: effectiveUserToken,
              );
              if (cached != null) {
                veh = veh.copyWith(startOdometerPhotoPath: cached.path);
              }
            }
          }
          if (veh.endOdometerPhotoPath != null &&
              veh.endOdometerPhotoPath!.isNotEmpty) {
            final f = File(veh.endOdometerPhotoPath!);
            if (!f.existsSync()) {
              final targetLocal =
                  '${localCacheDir.path}/odometer_${veh.id}_finish.webp';
              final cached = await _receiptStorageService.downloadAndCacheReceipt(
                remotePath: veh.endOdometerPhotoPath!,
                targetLocalPath: targetLocal,
                userToken: effectiveUserToken,
              );
              if (cached != null) {
                veh = veh.copyWith(endOdometerPhotoPath: cached.path);
              }
            }
          }
          restoredVehicles[i] = veh;
        }
      }

      return CloudRestoreResult(
        success: failedRecords == 0,
        vehicles: restoredVehicles,
        trips: restoredTrips,
        expenses: restoredExpenses,
        corruptedRecordsCount: failedRecords,
        errorMessage: failedRecords > 0
            ? '$failedRecords remote records were corrupted or unparseable.'
            : null,
      );
    } catch (e, stack) {
      debugPrint('[SyncEngine] Warning during restoreFromCloud: $e\n$stack');
      return CloudRestoreResult(
        success: false,
        vehicles: [],
        trips: [],
        expenses: [],
        corruptedRecordsCount: 0,
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
  final int corruptedRecordsCount;
  final String? errorMessage;

  CloudRestoreResult({
    required this.success,
    required this.vehicles,
    required this.trips,
    required this.expenses,
    this.corruptedRecordsCount = 0,
    this.errorMessage,
  });
}
