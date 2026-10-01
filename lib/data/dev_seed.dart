// DEV SEED — CPK Tradie Demo Data
// To remove: delete this file and remove `DevSeed.inject(this)` from app_state.dart init()
// Data auto-deletes with the account (LocalStorage is user-scoped)

import '../data/models/trip.dart';
import '../data/models/vehicle.dart';

class DevSeed {
  DevSeed._();

  static bool enableSeed = false;

  static void inject(dynamic appState) {
    if (!enableSeed) return;
    // Only inject if no vehicle + no trips yet (truly empty account)
    if (appState.hasVehicle || appState.trips.isNotEmpty) return;

    const vehicleId = 'dev_seed_v1';

    final vehicle = Vehicle(
      id: vehicleId,
      make: 'Ford',
      model: 'Ranger (2024)',
      regoPlate: '1GTF892',
      initialOdometer: 42150.0,
      vehicleType: VehicleType.ute,
      bluetoothDeviceName: 'Ford SYNC',
      isPrimary: true,
      taxMethod: TaxMethod.centsPerKm,
      clientDedupId: 'veh_1GTF892',
    );

    appState.addVehicle(vehicle);

    // Gapless odometer chain starting at 42150.0
    final trips = <Trip>[
      // 1 — Business: Bunnings → Bondi Reno
      Trip(
        id: 'seed_t1',
        vehicleId: vehicleId,
        distanceKm: 18.4,
        date: DateTime(2026, 9, 22, 7, 12),
        purpose: 'Collect timber & fixings for Bondi residential reno',
        startOdometer: 42150.0,
        endOdometer: 42168.4,
        classification: TripClassification.business,
        originAddress: 'Bunnings Trade, Alexandria NSW',
        destinationAddress: 'Bondi Residential Reno, Bond St, Bondi NSW',
        evidenceSource: 'bluetooth_auto',
        jobReference: 'JOB-BNR-220926',
      ),
      // 2 — Business: Bondi → North Sydney Office Fitout
      Trip(
        id: 'seed_t2',
        vehicleId: vehicleId,
        distanceKm: 24.2,
        date: DateTime(2026, 9, 22, 14, 35),
        purpose: 'Site inspection — North Sydney office fitout',
        startOdometer: 42168.4,
        endOdometer: 42192.6,
        classification: TripClassification.business,
        originAddress: 'Bondi Residential Reno, Bond St, Bondi NSW',
        destinationAddress: 'North Sydney Office Fitout, Walker St, North Sydney NSW',
        evidenceSource: 'bluetooth_auto',
        jobReference: 'JOB-NSO-220926',
      ),
      // 3 — Business: Depot Parramatta → Reece Plumbing Artarmon
      Trip(
        id: 'seed_t3',
        vehicleId: vehicleId,
        distanceKm: 31.5,
        date: DateTime(2026, 9, 23, 6, 58),
        purpose: 'Collect PEX fittings & copper pipe — plumbing job',
        startOdometer: 42192.6,
        endOdometer: 42224.1,
        classification: TripClassification.business,
        originAddress: 'Depot, Parramatta NSW',
        destinationAddress: 'Reece Plumbing, Artarmon NSW',
        evidenceSource: 'bluetooth_auto',
        jobReference: 'JOB-PLB-230926',
      ),
      // 4 — Needs Review (unclassified): Bondi → Depot
      Trip(
        id: 'seed_t4',
        vehicleId: vehicleId,
        distanceKm: 33.0,
        date: DateTime(2026, 9, 25, 17, 4),
        purpose: '',
        startOdometer: 42224.1,
        endOdometer: 42257.1,
        classification: TripClassification.unclassified,
        originAddress: 'Bondi Residential Reno, Bond St, Bondi NSW',
        destinationAddress: 'Depot, Parramatta NSW',
        evidenceSource: 'auto_telemetry',
      ),
      // 5 — Personal: Surry Hills → Gym Newtown
      Trip(
        id: 'seed_t5',
        vehicleId: vehicleId,
        distanceKm: 4.8,
        date: DateTime(2026, 9, 26, 18, 20),
        purpose: 'Personal',
        startOdometer: 42257.1,
        endOdometer: 42261.9,
        classification: TripClassification.personal,
        originAddress: 'Personal Location',
        destinationAddress: 'Personal Location',
        evidenceSource: 'auto_telemetry',
      ),
      // 6 — Business: Penrith Job Site → Eastern Creek Bunnings
      Trip(
        id: 'seed_t6',
        vehicleId: vehicleId,
        distanceKm: 21.3,
        date: DateTime(2026, 9, 27, 8, 45),
        purpose: 'Pick up structural steel brackets — Penrith warehouse fitout',
        startOdometer: 42261.9,
        endOdometer: 42283.2,
        classification: TripClassification.business,
        originAddress: 'Penrith Warehouse Fitout, Station St, Penrith NSW',
        destinationAddress: 'Bunnings Trade, Eastern Creek NSW',
        evidenceSource: 'bluetooth_auto',
        jobReference: 'JOB-PWH-270926',
      ),
    ];

    for (final t in trips) {
      appState.recordTrip(t);
    }
  }
}
