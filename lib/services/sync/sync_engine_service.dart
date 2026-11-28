import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../data/models/job_site.dart';
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
  final String? Function()? _tokenProvider;
  final ReceiptStorageService _receiptStorageService;

  bool get isAuthenticated => currentUser != null || currentAccessToken != null;
  ReceiptStorageService get receiptStorageService => _receiptStorageService;
  String? get currentAccessToken =>
      _tokenProvider != null ? _tokenProvider() : currentUser?.accessToken;

  SyncEngineService({
    String? supabaseUrl,
    String? anonKey,
    http.Client? httpClient,
    this.currentUser,
    String? Function()? tokenProvider,
    ReceiptStorageService? receiptStorageService,
  })  : supabaseUrl = supabaseUrl ?? AppConstants.supabaseUrl,
        anonKey = anonKey ?? AppConstants.supabaseAnonKey,
        _httpClient = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider,
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
    final raw = '${expense.vehicleId}_${expense.id}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Stable transport UUID for legacy local text IDs; preserve native UUIDs.
  static String cloudId(String localId, String? userId) {
    if (RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(localId)) {
      return localId;
    }
    final hex = sha256
        .convert(utf8.encode('kiloclaim:${userId ?? "local"}:$localId'))
        .toString();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-5${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
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
    final effectiveUserToken = userToken ?? currentAccessToken;

    if (requireAuth &&
        (!isAuthenticated ||
            (currentUser == null && currentAccessToken == null)) &&
        effectiveUserId == null) {
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
      // The deployed vehicles FK references profiles, not auth.users directly.
      // Ignore duplicates so syncing never overwrites a user's existing profile.
      if (effectiveUserId != null) {
        final profileRes = await _httpClient.post(
            Uri.parse('$supabaseUrl/rest/v1/profiles?on_conflict=id'),
            headers: {
              ...headers,
              'Prefer': 'resolution=ignore-duplicates,return=minimal'
            },
            body: jsonEncode([
              {
                'id': effectiveUserId,
                'full_name': currentUser?.displayName ?? ''
              }
            ]));
        if (profileRes.statusCode < 200 || profileRes.statusCode >= 300) {
          return SyncResult(
              success: false,
              syncedTrips: 0,
              syncedExpenses: 0,
              rejectedOrIgnored: 0,
              errorMessage:
                  'profiles sync failed (HTTP ${profileRes.statusCode}).');
        }
      }
      // Sync ALL non-deleted trips (both business and personal) so continuous odometer
      // and statutory business use percentage are strictly preserved on cloud restore.
      final eligibleTrips = trips
          .where((t) => !t.isDeleted && t.vehicleId == vehicle.id)
          .toList();
      final ignoredCount = trips.length - eligibleTrips.length;
      final eligibleExpenses = expenses
          .where((e) => !e.isDeleted && e.vehicleId == vehicle.id)
          .toList();

      final failures = <String>[];
      int syncedTripCount = 0;
      int syncedExpenseCount = 0;

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
      final vehicleUri =
          Uri.parse('$supabaseUrl/rest/v1/vehicles?on_conflict=id');
      final vehicleDedupId =
          vehicle.clientDedupId ?? cloudId(vehicle.id, effectiveUserId);
      final vehiclePayload = [
        {
          'id': cloudId(vehicle.id, effectiveUserId),
          'local_id': vehicle.id,
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

      final vehicleResponse = await _httpClient.post(
        vehicleUri,
        headers: headers,
        body: jsonEncode(vehiclePayload),
      );

      if (vehicleResponse.statusCode < 200 ||
          vehicleResponse.statusCode >= 300) {
        return SyncResult(
            success: false,
            syncedTrips: 0,
            syncedExpenses: 0,
            rejectedOrIgnored: ignoredCount,
            errorMessage:
                'vehicles sync failed (HTTP ${vehicleResponse.statusCode}).');
      }

      if (eligibleTrips.isNotEmpty) {
        final tripPayloads = eligibleTrips.map((t) {
          final isBiz = t.isBusiness;
          return {
            'id': cloudId(t.id, effectiveUserId),
            'local_id': t.id,
            if (effectiveUserId != null) 'user_id': effectiveUserId,
            'vehicle_id': cloudId(vehicle.id, effectiveUserId),
            'date': t.date.toIso8601String(),
            'distance_km': t.distanceKm,
            // Mask personal details for privacy while preserving statutory odometer
            'purpose': isBiz ? t.purpose : 'Personal',
            'start_odometer': t.startOdometer,
            'end_odometer': t.endOdometer,
            'classification': t.classification.name,
            'job_id': t.jobId,
            'job_reference': isBiz ? t.jobReference : null,
            'review': t.review,
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
            'client_dedup_id':
                t.clientDedupId ?? cloudId(t.id, effectiveUserId),
            'deleted_at': t.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        }).toList();

        final tripUri = Uri.parse('$supabaseUrl/rest/v1/trips?on_conflict=id');
        final res = await _httpClient.post(
          tripUri,
          headers: headers,
          body: jsonEncode(tripPayloads),
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          syncedTripCount = eligibleTrips.length;
        } else {
          failures.add('trips sync failed (HTTP ${res.statusCode}).');
        }
      }

      if (eligibleExpenses.isNotEmpty) {
        final expensePayloads = <Map<String, dynamic>>[];
        for (final e in eligibleExpenses) {
          if (e.allocationError != null) {
            failures.add('expenses: ${e.allocationError}');
            continue;
          }
          final dedupId = e.clientDedupId ?? cloudId(e.id, effectiveUserId);
          String? cloudReceiptPath = e.receiptPath;
          String? computedSha256 = e.sha256Hash;

          // If local receipt file exists on disk, upload binary to Supabase Storage and compute SHA-256
          if (cloudReceiptPath != null && cloudReceiptPath.isNotEmpty) {
            final localFile = File(cloudReceiptPath);
            if (localFile.existsSync()) {
              final uploadResult =
                  await _receiptStorageService.uploadExpenseReceiptWithHash(
                file: localFile,
                userId: effectiveUserId ?? 'anon',
                expenseId: e.id,
                userToken: effectiveUserToken,
              );
              if (uploadResult.remotePath != null) {
                cloudReceiptPath = uploadResult.remotePath;
                computedSha256 = e.sha256Hash ?? uploadResult.sha256Hash;
              } else {
                failures.add('expenses: receipt upload failed.');
                continue;
              }
            } else if (cloudReceiptPath.startsWith('/')) {
              failures.add('expenses: local receipt photo is missing.');
              continue;
            }
          }

          final cloudAudit = e.receiptAudit?.toJson();
          final localPages = e.receiptAudit?.currentFields['pagePaths'];
          if (cloudAudit != null &&
              localPages is List &&
              localPages.isNotEmpty) {
            final remotePages = <String>[];
            final transportHashes = <String?>[];
            var pageUploadFailed = false;
            for (var page = 0; page < localPages.length; page++) {
              final path = localPages[page] as String;
              final local = File(path);
              if (await local.exists()) {
                final uploaded =
                    await _receiptStorageService.uploadExpenseReceiptWithHash(
                        file: local,
                        userId: effectiveUserId ?? 'anon',
                        expenseId: '${e.id}-page-${page + 1}',
                        userToken: effectiveUserToken);
                if (uploaded.remotePath == null) {
                  pageUploadFailed = true;
                  break;
                }
                remotePages.add(uploaded.remotePath!);
                transportHashes.add(uploaded.sha256Hash);
              } else if (!path.startsWith('/')) {
                remotePages.add(path);
                final saved =
                    e.receiptAudit?.currentFields['transportPageHashes'];
                transportHashes.add(saved is List && page < saved.length
                    ? saved[page] as String?
                    : null);
              } else {
                pageUploadFailed = true;
                break;
              }
            }
            if (pageUploadFailed) {
              failures.add('expenses: receipt page upload failed.');
              continue;
            }
            cloudAudit['currentFields'] = {
              ...e.receiptAudit!.currentFields,
              'pagePaths': remotePages,
              'transportPageHashes': transportHashes,
            };
          }

          expensePayloads.add({
            'id': cloudId(e.id, effectiveUserId),
            'local_id': e.id,
            if (effectiveUserId != null) 'user_id': effectiveUserId,
            'vehicle_id': cloudId(vehicle.id, effectiveUserId),
            'job_id': e.jobId,
            'linked_trip_id': e.linkedTripId == null
                ? null
                : cloudId(e.linkedTripId!, effectiveUserId),
            'date': e.date.toIso8601String(),
            'amount': e.amount,
            'gst_amount': e.gstAmount,
            'currency': e.currency,
            'supplier_abn': e.supplierAbn,
            'invoice_number': e.invoiceNumber,
            'category': e.category.name,
            'supplier': e.supplier ?? e.receiptAudit?.ocrMerchant,
            'allocations': e.allocations.map((line) => line.toJson()).toList(),
            'receipt_audit': cloudAudit,
            'is_vault_only': e.isVaultOnly,
            'vault_reason': e.vaultReason,
            'notes': e.notes,
            'receipt_storage_path': cloudReceiptPath,
            'sha256_hash': computedSha256,
            'business_percentage': e.businessPercentage,
            'client_dedup_id': dedupId,
            'deleted_at': e.deletedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        final expUri =
            Uri.parse('$supabaseUrl/rest/v1/expenses?on_conflict=id');
        final expRes = await _httpClient.post(
          expUri,
          headers: headers,
          body: jsonEncode(expensePayloads),
        );

        if (expRes.statusCode >= 200 && expRes.statusCode < 300) {
          syncedExpenseCount = expensePayloads.length;
        } else {
          failures.add('expenses sync failed (HTTP ${expRes.statusCode}).');
        }
      }

      return SyncResult(
        success: failures.isEmpty,
        errorMessage: failures.isEmpty ? null : failures.join(' '),
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

  /// EVIDENCE GRAPH: Sync JobSites (POIs) to Supabase Cloud
  /// Conforms to `public.job_sites` table with non-blocking failure handling.
  Future<SyncResult> syncJobSitesToCloud({
    required List<JobSite> jobSites,
    String? userToken,
    String? userId,
    bool requireAuth = false,
  }) async {
    final effectiveUserId = userId ?? currentUser?.id;
    final effectiveUserToken = userToken ?? currentAccessToken;

    if (requireAuth &&
        (!isAuthenticated ||
            (currentUser == null && currentAccessToken == null)) &&
        effectiveUserId == null) {
      return SyncResult(
        success: false,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: 0,
        errorMessage: 'User is not authenticated. JobSite sync aborted.',
      );
    }

    if (jobSites.isEmpty) {
      return SyncResult(
        success: true,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: 0,
      );
    }

    try {
      final headers = _buildHeaders(effectiveUserToken);
      final payloads = jobSites
          .map((s) => {
                'id': cloudId(s.id, effectiveUserId),
                'local_id': s.id,
                if (effectiveUserId != null) 'user_id': effectiveUserId,
                'name': s.name,
                'client_name': s.clientName,
                'project_code': s.projectCode,
                'address': s.address,
                'latitude': s.latitude,
                'longitude': s.longitude,
                'radius_meters': s.radiusMeters,
                'is_active': s.isActive,
                'tracking_enabled': s.trackingEnabled,
                'created_at': s.createdAt.toIso8601String(),
                'updated_at': s.updatedAt.toIso8601String(),
              })
          .toList();

      final uri = Uri.parse('$supabaseUrl/rest/v1/job_sites?on_conflict=id');
      final res = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(payloads),
      );

      final isSuccess = res.statusCode >= 200 && res.statusCode < 300;
      return SyncResult(
        success: isSuccess,
        syncedTrips: 0,
        syncedExpenses: isSuccess ? jobSites.length : 0,
        rejectedOrIgnored: isSuccess ? 0 : jobSites.length,
        errorMessage: isSuccess
            ? null
            : 'Supabase returned HTTP ${res.statusCode}: ${res.body}',
      );
    } catch (e, stack) {
      debugPrint(
          '[SyncEngine] Non-blocking error syncing job sites: $e\n$stack');
      return SyncResult(
        success: false,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: jobSites.length,
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
    final effectiveUserToken = userToken ?? currentAccessToken;

    if (requireAuth &&
        (!isAuthenticated ||
            (currentUser == null && currentAccessToken == null)) &&
        effectiveUserId == null) {
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
      final userFilter =
          effectiveUserId != null ? '&user_id=eq.$effectiveUserId' : '';

      final vehUri =
          Uri.parse('$supabaseUrl/rest/v1/vehicles?select=*$userFilter');
      final vehRes = await _httpClient.get(vehUri, headers: headers);

      int failedRecords = 0;

      final vehicleIds = <String, String>{};
      final tripIds = <String, String>{};
      final List<Vehicle> restoredVehicles = [];
      if (vehRes.statusCode >= 200 && vehRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(vehRes.body);
        for (final item in data) {
          try {
            final row = Map<String, dynamic>.from(item as Map);
            vehicleIds[row['id'] as String] =
                (row['local_id'] ?? row['id']) as String;
            row['id'] = row['local_id'] ?? row['id'];
            restoredVehicles.add(Vehicle.fromJson(row));
          } catch (e, stack) {
            failedRecords++;
            debugPrint(
                '[SyncEngine] Warning parsing vehicle record: $e\n$stack');
          }
        }
      }

      if (vehRes.statusCode < 200 || vehRes.statusCode >= 300) failedRecords++;
      final tripFilter = vehicleId != null
          ? '&vehicle_id=eq.${cloudId(vehicleId, effectiveUserId)}'
          : '';
      final tripUri = Uri.parse(
          '$supabaseUrl/rest/v1/trips?select=*$userFilter$tripFilter&order=date.asc');
      final tripRes = await _httpClient.get(tripUri, headers: headers);

      final List<Trip> restoredTrips = [];
      if (tripRes.statusCode >= 200 && tripRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(tripRes.body);
        for (final item in data) {
          try {
            final row = Map<String, dynamic>.from(item as Map);
            tripIds[row['id'] as String] =
                (row['local_id'] ?? row['id']) as String;
            row['id'] = row['local_id'] ?? row['id'];
            row['vehicle_id'] =
                vehicleIds[row['vehicle_id']] ?? row['vehicle_id'];
            restoredTrips.add(Trip.fromJson(row));
          } catch (e, stack) {
            failedRecords++;
            debugPrint('[SyncEngine] Warning parsing trip record: $e\n$stack');
          }
        }
      }

      if (tripRes.statusCode < 200 || tripRes.statusCode >= 300) {
        failedRecords++;
      }
      final expFilter = vehicleId != null
          ? '&vehicle_id=eq.${cloudId(vehicleId, effectiveUserId)}'
          : '';
      final expUri = Uri.parse(
          '$supabaseUrl/rest/v1/expenses?select=*$userFilter$expFilter&order=date.asc');
      final expRes = await _httpClient.get(expUri, headers: headers);

      final List<VehicleExpense> restoredExpenses = [];
      if (expRes.statusCode >= 200 && expRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(expRes.body);
        for (final item in data) {
          try {
            final row = Map<String, dynamic>.from(item as Map);
            row['id'] = row['local_id'] ?? row['id'];
            row['vehicle_id'] =
                vehicleIds[row['vehicle_id']] ?? row['vehicle_id'];
            row['linked_trip_id'] =
                tripIds[row['linked_trip_id']] ?? row['linked_trip_id'];
            restoredExpenses.add(VehicleExpense.fromJson(row));
          } catch (e, stack) {
            failedRecords++;
            debugPrint(
                '[SyncEngine] Warning parsing expense record: $e\n$stack');
          }
        }
      }

      if (expRes.statusCode < 200 || expRes.statusCode >= 300) failedRecords++;
      for (var i = 0; i < restoredTrips.length; i++) {
        final trip = restoredTrips[i];
        restoredTrips[i] = trip.copyWith(
            linkedExpenseIds: restoredExpenses
                .where((e) => e.linkedTripId == trip.id && !e.isDeleted)
                .map((e) => e.id)
                .toList());
      }

      final jobSiteUri = Uri.parse(
          '$supabaseUrl/rest/v1/job_sites?select=*$userFilter&order=created_at.asc');
      final jobSiteRes = await _httpClient.get(jobSiteUri, headers: headers);

      final List<JobSite> restoredJobSites = [];
      if (jobSiteRes.statusCode >= 200 && jobSiteRes.statusCode < 300) {
        final List<dynamic> data = jsonDecode(jobSiteRes.body);
        for (final item in data) {
          try {
            restoredJobSites
                .add(JobSite.fromJson(item as Map<String, dynamic>));
          } catch (e, stack) {
            failedRecords++;
            debugPrint(
                '[SyncEngine] Warning parsing job site record: $e\n$stack');
          }
        }
      }

      if (localCacheDir != null) {
        for (int i = 0; i < restoredExpenses.length; i++) {
          final exp = restoredExpenses[i];
          final audit = exp.receiptAudit;
          final remotePages = audit?.currentFields['pagePaths'];
          if (audit != null && remotePages is List && remotePages.isNotEmpty) {
            final localPages = <String>[];
            final hashes = audit.currentFields['transportPageHashes'];
            var pagesFailed = false;
            for (var page = 0; page < remotePages.length; page++) {
              final path = remotePages[page] as String;
              final expected = hashes is List && page < hashes.length
                  ? hashes[page] as String?
                  : null;
              if (await File(path).exists()) {
                if (expected != null &&
                    sha256.convert(await File(path).readAsBytes()).toString() !=
                        expected) {
                  pagesFailed = true;
                  break;
                }
                localPages.add(path);
                continue;
              }
              final target = ReceiptStorageService.getCachedReceiptFile(
                  cacheDirectory: localCacheDir,
                  sha256Hash: expected,
                  fallbackId: '${exp.id}-page-${page + 1}');
              final cached =
                  await _receiptStorageService.downloadAndCacheReceipt(
                      remotePath: path,
                      targetLocalPath: target.path,
                      userToken: effectiveUserToken,
                      expectedSha256: expected);
              if (cached == null) {
                pagesFailed = true;
                break;
              }
              localPages.add(cached.path);
            }
            if (pagesFailed) {
              failedRecords++;
            } else {
              final json = audit.toJson();
              json['currentFields'] = {
                ...audit.currentFields,
                'pagePaths': localPages
              };
              restoredExpenses[i] = exp.copyWith(
                  receiptPath: localPages.first,
                  receiptAudit: ReceiptAuditTrail.fromJson(json));
            }
            continue;
          }
          if (exp.receiptPath != null && exp.receiptPath!.isNotEmpty) {
            final f = File(exp.receiptPath!);
            if (!f.existsSync()) {
              final targetFile = ReceiptStorageService.getCachedReceiptFile(
                cacheDirectory: localCacheDir,
                sha256Hash: exp.sha256Hash,
                fallbackId: exp.id,
              );
              final cached =
                  await _receiptStorageService.downloadAndCacheReceipt(
                remotePath: exp.receiptPath!,
                targetLocalPath: targetFile.path,
                userToken: effectiveUserToken,
                expectedSha256: exp.sha256Hash,
              );
              if (cached != null) {
                restoredExpenses[i] = exp.copyWith(receiptPath: cached.path);
              } else {
                failedRecords++;
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
              final cached =
                  await _receiptStorageService.downloadAndCacheReceipt(
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
              final cached =
                  await _receiptStorageService.downloadAndCacheReceipt(
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
        jobSites: restoredJobSites,
        corruptedRecordsCount: failedRecords,
        errorMessage: failedRecords > 0
            ? '$failedRecords records or receipt files could not be restored completely. Available records were returned.'
            : null,
      );
    } catch (e, stack) {
      debugPrint('[SyncEngine] Warning during restoreFromCloud: $e\n$stack');
      return CloudRestoreResult(
        success: false,
        vehicles: [],
        trips: [],
        expenses: [],
        jobSites: [],
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
  final List<JobSite> jobSites;
  final int corruptedRecordsCount;
  final String? errorMessage;

  CloudRestoreResult({
    required this.success,
    required this.vehicles,
    required this.trips,
    required this.expenses,
    this.jobSites = const [],
    this.corruptedRecordsCount = 0,
    this.errorMessage,
  });
}
