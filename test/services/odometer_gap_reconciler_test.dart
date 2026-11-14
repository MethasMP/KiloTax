import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/tracking/odometer_gap_reconciler.dart';
import 'package:kilotax/state/app_state.dart';

Trip trip(String id, double start, double end,
        {String vehicle = 'ute', String source = 'manual_retroactive'}) =>
    Trip(
        id: id,
        vehicleId: vehicle,
        distanceKm: end - start,
        date: DateTime.now(),
        purpose: 'Client site',
        startOdometer: start,
        endOdometer: end,
        taxMethod: TaxMethod.logbook,
        evidenceSource: source);
AppState state() => AppState()
  ..addVehicle(Vehicle(
      id: 'ute',
      make: 'Ford',
      model: 'Ranger',
      regoPlate: 'TEST',
      initialOdometer: 1000,
      taxMethod: TaxMethod.logbook));

void main() {
  test(
      'legacy review recognizes known automatic markers without relabelling explicit user bridges',
      () {
    expect(
        OdometerGapReconciler.isInferredBridge(
            trip('gap_bridge_old_ui', 1020, 1050, source: 'auto_telemetry')
                .copyWith(purpose: 'Personal travel (Bridging)')),
        true);
    expect(
        OdometerGapReconciler.isInferredBridge(
            trip('gap_bridge_explicit', 1020, 1050, source: 'auto_telemetry')
                .copyWith(purpose: 'Personal travel')),
        false);
  });

  test(
      'ingestion keeps observed trips and exposes missing travel without inventing a personal record',
      () {
    final s = state()
      ..recordTrip(trip('a', 1000, 1020))
      ..recordTrip(trip('b', 1050, 1070));
    expect(s.trips.length, 2);
    expect(
        s.trips.where((t) => t.classification == TripClassification.personal),
        isEmpty);
    expect(s.findFirstOdometerGap()!.startOdo, 1020);
    expect(s.findFirstOdometerGap()!.endOdo, 1050);
    expect(s.isOdometerChainGapless, false);
  });

  test(
      'adding partial and historical travel reduces the gap and never rewinds the current odometer',
      () {
    final s = state()
      ..recordTrip(trip('a', 1000, 1020))
      ..recordTrip(trip('b', 1050, 1070));
    s.recordTrip(trip('partial', 1020, 1030));
    expect(s.findFirstOdometerGap()!.distance, 20);
    expect(s.currentOdometer, 1070);
    expect(s.hasOdometerMonotonicityViolation, false);
    s.recordTrip(trip('remaining', 1030, 1050));
    expect(s.pendingOdometerGaps, isEmpty);
    expect(s.isOdometerChainGapless, true);
    expect(s.currentOdometer, 1070);
  });

  test(
      'a recorded starting baseline survives first-trip ingestion and surfaces the initial missing span',
      () {
    final s = state();
    s.startLogbookPeriod(startDate: DateTime.now(), startingOdometer: 1000);
    s.recordTrip(trip('first', 1010, 1020));
    expect(s.startingOdometer, 1000);
    expect(s.activeLogbookPeriod!.startOdometer, 1000);
    expect(s.findFirstOdometerGap()!.distance, 10);
  });

  test(
      'gap detection is independent of insertion order and ignores deleted and other-vehicle records',
      () {
    final s = state()
      ..recordTrip(trip('later', 1050, 1070))
      ..recordTrip(trip('earlier', 1000, 1020));
    s.recordTrip(trip('other', 1020, 1050, vehicle: 'other'));
    s.recordTrip(
        trip('deleted', 1020, 1050).copyWith(deletedAt: DateTime.now()));
    expect(s.findFirstOdometerGap()!.distance, 30);
    expect(s.currentOdometer, 1070);
  });

  test(
      'zero-baseline/distance-only records do not produce imagined odometer gaps',
      () {
    final gaps =
        OdometerGapReconciler.findGaps(vehicleId: 'ute', baseline: 0, trips: [
      Trip(
          id: 'distance',
          vehicleId: 'ute',
          distanceKm: 12,
          date: DateTime.now(),
          purpose: 'Trip'),
      trip('first', 1000, 1020),
    ]);
    expect(gaps, isEmpty);
  });

  test(
      'legacy auto-classified bridges require review without rewriting stored records',
      () {
    final legacy = trip('legacy', 1020, 1050,
            source: OdometerGapReconciler.bridgeEvidenceSource)
        .copyWith(classification: TripClassification.personal);
    final s = state()
      ..recordTrip(trip('a', 1000, 1020))
      ..recordTrip(legacy)
      ..recordTrip(trip('b', 1050, 1070));
    expect(s.findFirstOdometerGap()!.legacyTripId, 'legacy');
    expect(s.trips.firstWhere((t) => t.id == 'legacy').evidenceSource,
        OdometerGapReconciler.bridgeEvidenceSource);
    s.recordTrip(legacy.copyWith(evidenceSource: 'user_confirmed_auto_gap'));
    expect(s.pendingOdometerGaps, isEmpty);
    expect(s.trips.length, 3);
  });

  test('stale gap spans cannot be offered after another record fills them', () {
    final s = state()
      ..recordTrip(trip('a', 1000, 1020))
      ..recordTrip(trip('b', 1050, 1070));
    expect(
        s.isUnrecordedOdometerSpan(
            vehicleId: 'ute', startOdo: 1020, endOdo: 1050),
        true);
    s.recordTrip(trip('fill', 1020, 1050));
    expect(
        s.isUnrecordedOdometerSpan(
            vehicleId: 'ute', startOdo: 1020, endOdo: 1050),
        false);
  });
}
