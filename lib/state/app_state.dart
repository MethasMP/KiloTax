import 'package:flutter/material.dart';
import '../data/models/vehicle.dart';
import '../data/models/trip.dart';
import '../data/models/vehicle_expense.dart';
import '../data/models/tax_summary.dart';
import '../services/engine/evidence_engine.dart';
import '../services/engine/tax_calculator_service.dart';

class AppState extends ChangeNotifier {
  Vehicle? _primaryVehicle;
  final List<Vehicle> _vehicles = [];
  final List<Trip> _trips = [];
  final List<VehicleExpense> _expenses = [];

  Vehicle? get primaryVehicle => _primaryVehicle;
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<Trip> get trips => List.unmodifiable(_trips);
  List<VehicleExpense> get expenses => List.unmodifiable(_expenses);

  bool get hasVehicle => _primaryVehicle != null;

  Future<void> addVehicle(Vehicle vehicle) async {
    _vehicles.add(vehicle);
    if (vehicle.isPrimary || _primaryVehicle == null) {
      _primaryVehicle = vehicle;
    }
    notifyListeners();
  }

  void selectVehicle(String vehicleId) {
    final found = _vehicles.firstWhere((v) => v.id == vehicleId, orElse: () => _primaryVehicle!);
    _primaryVehicle = found;
    notifyListeners();
  }

  void recordTrip(Trip trip) {
    _trips.add(trip);
    notifyListeners();
  }

  /// EVIDENCE GRAPH: Connect an expense (e.g. Bunnings/Fuel receipt) to a specific Trip
  void linkExpenseToTrip({required String expenseId, required String tripId}) {
    final expIndex = _expenses.indexWhere((e) => e.id == expenseId);
    if (expIndex != -1) {
      final oldExp = _expenses[expIndex];
      _expenses[expIndex] = VehicleExpense(
        id: oldExp.id,
        vehicleId: oldExp.vehicleId,
        amount: oldExp.amount,
        category: oldExp.category,
        date: oldExp.date,
        receiptPath: oldExp.receiptPath,
        businessPercentage: oldExp.businessPercentage,
        notes: oldExp.notes,
        linkedTripId: tripId,
      );
    }

    final tripIndex = _trips.indexWhere((t) => t.id == tripId);
    if (tripIndex != -1) {
      final oldTrip = _trips[tripIndex];
      if (!oldTrip.linkedExpenseIds.contains(expenseId)) {
        _trips[tripIndex] = Trip(
          id: oldTrip.id,
          vehicleId: oldTrip.vehicleId,
          distanceKm: oldTrip.distanceKm,
          date: oldTrip.date,
          purpose: oldTrip.purpose,
          startOdometer: oldTrip.startOdometer,
          endOdometer: oldTrip.endOdometer,
          classification: oldTrip.classification,
          originAddress: oldTrip.originAddress,
          destinationAddress: oldTrip.destinationAddress,
          linkedExpenseIds: [...oldTrip.linkedExpenseIds, expenseId],
        );
      }
    }
    notifyListeners();
  }

  void recordExpense(VehicleExpense expense) {
    _expenses.add(expense);
    notifyListeners();
  }

  EvidenceEngine createEvidenceEngine() {
    final vehicle = _primaryVehicle ??
        Vehicle(
          id: 'default',
          make: 'Toyota',
          model: 'Hilux',
          regoPlate: 'TRADIE-1',
          initialOdometer: 10000.0,
        );

    final engine = EvidenceEngine(vehicle: vehicle);
    for (final t in _trips) {
      engine.recordTrip(t);
    }
    for (final e in _expenses) {
      engine.recordExpense(e);
    }
    return engine;
  }


  /// 12-WEEK STATUTORY COMPLIANCE: Current week in 12-week period (1-12)
  int get currentLogbookWeek {
    final start = _primaryVehicle?.logbookStartDate ?? DateTime.now().subtract(const Duration(days: 21)); // default week 4
    final diffDays = DateTime.now().difference(start).inDays;
    final week = (diffDays / 7).floor() + 1;
    return week.clamp(1, 12);
  }

  /// 12-WEEK STATUTORY COMPLIANCE: Progress percentage (0.0 - 1.0)
  double get logbookProgressPercentage => currentLogbookWeek / 12.0;

  /// COMPLIANCE STATE: Trips with missing purpose or unclassified status
  List<Trip> get missingComplianceTrips => _trips
      .where((t) =>
          t.purpose.trim().isEmpty ||
          t.purpose.contains('?') ||
          t.classification == TripClassification.unclassified)
      .toList();

  /// Fix a trip purpose directly in 1 tap
  void resolveTripPurpose(String tripId, String newPurpose) {
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx != -1) {
      final old = _trips[idx];
      _trips[idx] = Trip(
        id: old.id,
        vehicleId: old.vehicleId,
        distanceKm: old.distanceKm,
        date: old.date,
        purpose: newPurpose,
        startOdometer: old.startOdometer,
        endOdometer: old.endOdometer,
        classification: TripClassification.business,
        originAddress: old.originAddress,
        destinationAddress: old.destinationAddress,
        linkedExpenseIds: old.linkedExpenseIds,
      );
      notifyListeners();
    }
  }

  /// Switch active Tax Method for Primary Vehicle
  void updatePrimaryVehicleTaxMethod(TaxMethod newMethod) {
    if (_primaryVehicle == null) return;
    final old = _primaryVehicle!;
    _primaryVehicle = Vehicle(
      id: old.id,
      make: old.make,
      model: old.model,
      regoPlate: old.regoPlate,
      initialOdometer: old.initialOdometer,
      engineCapacity: old.engineCapacity,
      vehicleType: old.vehicleType,
      bluetoothDeviceName: old.bluetoothDeviceName,
      isPrimary: old.isPrimary,
      taxMethod: newMethod,
      logbookStartDate: old.logbookStartDate ?? DateTime.now().subtract(const Duration(days: 21)),
    );
    notifyListeners();
  }

  TaxSummary get taxSummary => TaxCalculatorService.evaluateSummary(
        trips: _trips,
        expenses: _expenses,
      );
}
