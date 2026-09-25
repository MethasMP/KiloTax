import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/audit_evidence.dart';

/// Production-ready local persistent storage service.
/// Ensures all records (Vehicles, Trips, Expenses) survive app termination.
class LocalStorageService {
  static const String _keyVehicles = 'kilotax_vehicles_v1';
  static const String _keyPrimaryVehicleId = 'kilotax_primary_vehicle_id_v1';
  static const String _keyTrips = 'kilotax_trips_v1';
  static const String _keyExpenses = 'kilotax_expenses_v1';
  static const String _keyEvidence = 'kilotax_audit_evidence_v1';
  static const String _keyHasSeenOnboarding = 'kilotax_has_seen_onboarding_v1';

  final SharedPreferences _prefs;

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

  // --- VEHICLES ---
  List<Vehicle> loadVehicles() {
    final raw = _prefs.getString(_keyVehicles);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => Vehicle.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
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
      return list.map((item) => Trip.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
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
      return list.map((item) => VehicleExpense.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveExpenses(List<VehicleExpense> expenses) {
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
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveEvidence(List<AuditEvidence> evidenceList) {
    final raw = jsonEncode(evidenceList.map((e) => e.toJson()).toList());
    return _prefs.setString(_keyEvidence, raw);
  }

  // --- RAW STRING HELPERS (For Tax Rules & Dynamic Caches) ---
  String? loadRawString(String key) => _prefs.getString(key);
  Future<bool> saveRawString(String key, String value) => _prefs.setString(key, value);

  // --- RESET ALL DATA (For clean logout / account reset) ---
  Future<void> clearAll() async {
    await _prefs.remove(_keyVehicles);
    await _prefs.remove(_keyPrimaryVehicleId);
    await _prefs.remove(_keyTrips);
    await _prefs.remove(_keyExpenses);
    await _prefs.remove(_keyEvidence);
  }
}
