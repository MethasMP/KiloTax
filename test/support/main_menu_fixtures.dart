import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';

class AuditState extends AppState {
  @override
  void prewarmAuthConnection() {}
}

Future<AppState> seed(TaxMethod method, {bool empty = false}) async {
  final state = AuditState();
  await state.addVehicle(Vehicle(
      id: 'audit',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'DEMO',
      initialOdometer: 42000,
      taxMethod: method));
  if (empty) return state;
  final now = DateTime.now();
  state.recordTrip(Trip(
      id: 'work',
      vehicleId: 'audit',
      date: now,
      distanceKm: 18.4,
      purpose: 'Deliver timber to Smith renovation',
      classification: TripClassification.business,
      startOdometer: 42000,
      endOdometer: 42018.4,
      originAddress: 'Bunnings Trade, Alexandria NSW',
      destinationAddress: 'Smith renovation, Bondi NSW'));
  state.recordTrip(Trip(
      id: 'pending',
      vehicleId: 'audit',
      date: now,
      distanceKm: 9.8,
      purpose: '',
      classification: TripClassification.unclassified,
      startOdometer: 42018.4,
      endOdometer: 42028.2));
  state.recordTrip(Trip(
      id: 'personal',
      vehicleId: 'audit',
      date: now,
      distanceKm: 4.2,
      purpose: 'Grocery shopping',
      classification: TripClassification.personal,
      startOdometer: 42028.2,
      endOdometer: 42032.4));
  state.recordExpense(VehicleExpense(
      id: 'parking',
      vehicleId: 'audit',
      date: now,
      amount: 24.5,
      category: ExpenseCategory.tollsParking,
      notes: 'Wilson Parking'));
  state.recordExpense(VehicleExpense(
      id: 'fuel',
      vehicleId: 'audit',
      date: now,
      amount: 96.35,
      category: ExpenseCategory.fuel,
      notes: 'Ampol Alexandria'));
  return state;
}
