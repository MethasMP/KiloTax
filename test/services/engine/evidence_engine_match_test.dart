import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/services/engine/evidence_engine.dart';

void main() {
  group('EvidenceEngine Receipt Auto-Link Tests (INV-B01, INV-B02, INV-B04)', () {
    final tripTime = DateTime(2026, 11, 20, 10, 0);

    test('links receipt within 15km and 4h of trip', () {
      final trip = Trip(
        id: 'trip_1',
        vehicleId: 'veh_1',
        date: tripTime,
        purpose: 'Client inspection',
        originLat: -33.8688,
        originLng: 151.2093,
        destLat: -33.8150,
        destLng: 151.0000,
      );
      final receipt = Receipt(
        id: 'rec_1',
        capturedAt: tripTime.add(const Duration(hours: 2)),
        merchantLat: -33.8650, // ~500m from origin
        merchantLng: 151.2090,
      );

      final matches = autoLinkReceipts([receipt], [trip]);
      expect(matches, hasLength(1));
      expect(matches.first.tripId, equals('trip_1'));
      expect(matches.first.receiptId, equals('rec_1'));
      expect(matches.first.confidenceScore, greaterThan(0.0));
      expect(matches.first.associationMethod, isNotEmpty);
    });

    test('does NOT link receipt 16km from trip route', () {
      final trip = Trip(
        id: 'trip_1',
        vehicleId: 'veh_1',
        date: tripTime,
        purpose: 'Client inspection',
        originLat: -33.8688,
        originLng: 151.2093,
        destLat: -33.8688,
        destLng: 151.2093,
      );
      // Roughly ~21km away
      final receipt = Receipt(
        id: 'rec_far',
        capturedAt: tripTime.add(const Duration(hours: 1)),
        merchantLat: -33.7000,
        merchantLng: 151.1000,
      );

      final matches = autoLinkReceipts([receipt], [trip]);
      expect(matches, isEmpty);
    });

    test('does NOT link receipt trip.date + 5h', () {
      final trip = Trip(
        id: 'trip_1',
        vehicleId: 'veh_1',
        date: tripTime,
        purpose: 'Client inspection',
        originLat: -33.8688,
        originLng: 151.2093,
        destLat: -33.8150,
        destLng: 151.0000,
      );
      final receipt = Receipt(
        id: 'rec_late',
        capturedAt: tripTime.add(const Duration(hours: 5)),
        merchantLat: -33.8650,
        merchantLng: 151.2090,
      );

      final matches = autoLinkReceipts([receipt], [trip]);
      expect(matches, isEmpty);
    });

    test('link is idempotent for same (tripId, receiptId)', () {
      final trip = Trip(
        id: 'trip_1',
        vehicleId: 'veh_1',
        date: tripTime,
        purpose: 'Client inspection',
        originLat: -33.8688,
        originLng: 151.2093,
        destLat: -33.8150,
        destLng: 151.0000,
      );
      final receipt = Receipt(
        id: 'rec_1',
        capturedAt: tripTime.add(const Duration(hours: 1)),
        merchantLat: -33.8650,
        merchantLng: 151.2090,
      );

      // Pass duplicate receipts and trips
      final matches1 = autoLinkReceipts([receipt, receipt], [trip, trip]);
      expect(matches1, hasLength(1));

      // Repeated invocations yield identical result
      final matches2 = autoLinkReceipts([receipt], [trip]);
      expect(matches1.first.tripId, equals(matches2.first.tripId));
      expect(matches1.first.receiptId, equals(matches2.first.receiptId));
    });
  });
}
