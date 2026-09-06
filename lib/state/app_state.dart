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

  TaxSummary get taxSummary => TaxCalculatorService.evaluateSummary(
        trips: _trips,
        expenses: _expenses,
      );
}
