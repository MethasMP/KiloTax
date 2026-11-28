import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/audit_evidence.dart';
import '../../data/models/annual_odometer.dart';
import '../../data/models/in_flight_trip.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/job_site.dart';
import '../../data/models/logbook_period.dart';

/// Production-ready local persistent storage service.
/// Ensures all records (Vehicles, Trips, Expenses) survive app termination.
class LocalStorageService {
  static const String _keyVehicles = 'kiloclaim_vehicles_v1';
  static const String _keyPrimaryVehicleId = 'kiloclaim_primary_vehicle_id_v1';
  static const String _keyTrips = 'kiloclaim_trips_v1';
  static const String _keyExpenses = 'kiloclaim_expenses_v1';
  static const String _keyEvidence = 'kiloclaim_audit_evidence_v1';
  static const String _keyAnnualOdometers = 'kiloclaim_annual_odometers_v1';
  static const String _keyUserProfile = 'kiloclaim_user_profile_v1';
  static const String _keyJobSites = 'kiloclaim_job_sites_v1';
  static const String _keyLogbookPeriods = 'kiloclaim_logbook_periods_v1';
  static const String _keyHasSeenOnboarding = 'kiloclaim_has_seen_onboarding_v1';
  static const String _keyIsGuestMode = 'kiloclaim_is_guest_mode_v1';

  final SharedPreferences _prefs;
  bool _expenseReadCorrupt = false;
  String? get expenseRecoveryWarning => _expenseReadCorrupt
      ? 'Expense storage needs recovery. Existing data is preserved; restore a backup before adding records.'
      : null;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // --- ONBOARDING FTUE STATE ---
  bool hasSeenOnboarding() {
    return _prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  Future<bool> setHasSeenOnboarding(bool seen) {
    return _prefs.setBool(_keyHasSeenOnboarding, seen);
  }

  // --- GUEST / 100% LOCAL-FIRST MODE ---
  bool isGuestMode() {
    return _prefs.getBool(_keyIsGuestMode) ?? false;
  }

  Future<bool> setGuestMode(bool isGuest) {
    return _prefs.setBool(_keyIsGuestMode, isGuest);
  }

  // --- VEHICLES ---
  List<Vehicle> loadVehicles() {
    final raw = _prefs.getString(_keyVehicles);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => Vehicle.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[LocalStorageService] Warning loading vehicles: $e\n$stack');
      return [];
    }
  }

  Future<bool> saveVehicles(List<Vehicle> vehicles) {
    final raw = jsonEncode(vehicles.map((v) => v.toJson()).toList());
    return _prefs.setString(_keyVehicles, raw);
  }

  String? loadPrimaryVehicleId() {
    return _prefs.getString(_keyPrimaryVehicleId);
  }

  Future<bool> savePrimaryVehicleId(String? id) {
    if (id == null) {
      return _prefs.remove(_keyPrimaryVehicleId);
    }
    return _prefs.setString(_keyPrimaryVehicleId, id);
  }

  // --- TRIPS ---
  List<Trip> loadTrips() {
    final raw = _prefs.getString(_keyTrips);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => Trip.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[LocalStorageService] Warning loading trips: $e\n$stack');
      return [];
    }
  }

  Future<bool> saveTrips(List<Trip> trips) {
    final raw = jsonEncode(trips.map((t) => t.toJson()).toList());
    return _prefs.setString(_keyTrips, raw);
  }

  // --- EXPENSES ---
  List<VehicleExpense> loadExpenses() {
    final raw = _prefs.getString(_keyExpenses);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => VehicleExpense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _expenseReadCorrupt = true;
      _prefs.setString('kiloclaim_expenses_recovery_v1', raw);
      debugPrint(
          '[LocalStorageService] Expense data preserved for recovery: $e');
      return [];
    }
  }

  Future<bool> saveExpenses(List<VehicleExpense> expenses) {
    if (_expenseReadCorrupt) return Future.value(false);
    final raw = jsonEncode(expenses.map((e) => e.toJson()).toList());
    return _prefs.setString(_keyExpenses, raw);
  }

  // --- AUDIT EVIDENCE VAULT ---
  List<AuditEvidence> loadEvidence() {
    final raw = _prefs.getString(_keyEvidence);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => AuditEvidence.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint(
          '[LocalStorageService] Warning loading audit evidence: $e\n$stack');
      return [];
    }
  }

  Future<bool> saveEvidence(List<AuditEvidence> evidenceList) {
    final raw = jsonEncode(evidenceList.map((e) => e.toJson()).toList());
    return _prefs.setString(_keyEvidence, raw);
  }

  // --- ANNUAL ODOMETERS (ITAA 1997 s 28-125) ---
  List<AnnualVehicleOdometer> loadAnnualOdometers() {
    final raw = _prefs.getString(_keyAnnualOdometers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) =>
              AnnualVehicleOdometer.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint(
          '[LocalStorageService] Warning loading annual odometers: $e\n$stack');
      return [];
    }
  }

  Future<bool> saveAnnualOdometers(List<AnnualVehicleOdometer> list) {
    final raw = jsonEncode(list.map((o) => o.toJson()).toList());
    return _prefs.setString(_keyAnnualOdometers, raw);
  }

  // --- IN-FLIGHT TRIP (ANTI-CRASH & KILL RESURRECTION) ---
  static const String _keyInFlightTrip = 'kiloclaim_in_flight_trip_v1';

  InFlightTrip? loadInFlightTrip() {
    final raw = _prefs.getString(_keyInFlightTrip);
    return InFlightTrip.deserialize(raw);
  }

  Future<bool> saveInFlightTrip(InFlightTrip? trip) {
    if (trip == null) {
      return _prefs.remove(_keyInFlightTrip);
    }
    return _prefs.setString(_keyInFlightTrip, trip.serialize());
  }

  Future<bool> clearInFlightTrip() {
    return _prefs.remove(_keyInFlightTrip);
  }

  // --- USER PROFILE (HOME BASE GEOFENCING) ---
  UserProfile loadUserProfile() {
    final raw = _prefs.getString(_keyUserProfile);
    if (raw == null || raw.isEmpty) return const UserProfile();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (e, stack) {
      debugPrint(
          '[LocalStorageService] Warning loading user profile: $e\n$stack');
      return const UserProfile();
    }
  }

  Future<bool> saveUserProfile(UserProfile profile) {
    final raw = jsonEncode(profile.toJson());
    return _prefs.setString(_keyUserProfile, raw);
  }

  // --- JOB SITES (POI GEOFENCING) ---
  List<JobSite> loadJobSites() {
    final raw = _prefs.getString(_keyJobSites);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => JobSite.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[LocalStorageService] Warning loading job sites: $e\n$stack');
      return [];
    }
  }

  Future<bool> saveJobSites(List<JobSite> jobSites) {
    final raw = jsonEncode(jobSites.map((s) => s.toJson()).toList());
    return _prefs.setString(_keyJobSites, raw);
  }

  // --- LOGBOOK PERIODS (12-WEEK STATUTORY LOGBOOK) ---
  List<LogbookPeriod> loadLogbookPeriods() {
    final raw = _prefs.getString(_keyLogbookPeriods);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => LogbookPeriod.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint(
          '[LocalStorageService] Warning loading logbook periods: $e\n$stack');
      return [];
    }
  }

  Future<bool> saveLogbookPeriods(List<LogbookPeriod> periods) {
    final raw = jsonEncode(periods.map((p) => p.toJson()).toList());
    return _prefs.setString(_keyLogbookPeriods, raw);
  }

  // --- RAW STRING HELPERS (For Tax Rules & Dynamic Caches) ---
  String? loadRawString(String key) => _prefs.getString(key);
  Future<bool> saveRawString(String key, String value) =>
      _prefs.setString(key, value);

  // --- RESET ALL DATA (For clean logout / account reset) ---
  Future<void> recoverRestoreIntent() async {
    final raw = _prefs.getString('kiloclaim_restore_intent_v2');
    if (raw == null) return;
    final writes = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    for (final entry in writes.entries) {
      if (entry.value == null) {
        if (!await _prefs.remove(entry.key)) {
          throw StateError('Could not finish backup recovery.');
        }
      } else if (!await _prefs.setString(entry.key, entry.value as String)) {
        throw StateError('Could not finish backup recovery.');
      }
    }
    if (!await _prefs.remove('kiloclaim_restore_intent_v2')) {
      throw StateError('Could not finish backup recovery.');
    }
    _expenseReadCorrupt = false;
  }

  Future<void> restoreSnapshot(Map<String, dynamic> payload) async {
    final writes = <String, dynamic>{
      _keyVehicles: jsonEncode(payload['vehicles']),
      _keyTrips: jsonEncode(payload['trips']),
      _keyExpenses: jsonEncode(payload['expenses']),
      _keyEvidence: jsonEncode(payload['evidence']),
      _keyAnnualOdometers: jsonEncode(payload['annualOdometers'] ?? []),
      _keyJobSites: jsonEncode(payload['jobSites'] ?? []),
      if (payload['userProfile'] != null)
        _keyUserProfile: jsonEncode(payload['userProfile']),
      _keyPrimaryVehicleId: payload['primaryVehicleId'],
    };
    if (!await _prefs.setString(
        'kiloclaim_restore_intent_v2', jsonEncode(writes))) {
      throw StateError(
          'Could not prepare backup recovery. Existing records are unchanged.');
    }
    await recoverRestoreIntent();
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
