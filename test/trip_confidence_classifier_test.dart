import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/services/engine/trip_confidence_classifier.dart';

void main() {
  Trip journey(String origin, String destination, DateTime date,
          {TripClassification classification =
              TripClassification.unclassified}) =>
      Trip(
        id: 'trip',
        vehicleId: 'vehicle',
        distanceKm: 12,
        date: date,
        purpose: '?',
        originAddress: origin,
        destinationAddress: destination,
        classification: classification,
      );

  test('merchant and site names never preselect unresolved business claims',
      () {
    for (final destination in [
      'Bunnings Warehouse',
      'Client Site Hawthorn',
      'New location'
    ]) {
      final trip = journey('Workshop', destination, DateTime(2026, 9, 23, 10));
      final result = TripConfidenceClassifier.assess(trip);
      expect(result.isHighConfidence, isFalse);
      expect(result.suggestedBulkyTools, isFalse);
      expect(result.trip.classification, TripClassification.unclassified);
      expect(result.trip.purpose, '?');
    }
  });

  test(
      'home in either direction requires review without inventing tool transport',
      () {
    for (final addresses in [
      ['Home', 'Client Site'],
      ['Client Site', 'Residence']
    ]) {
      final result = TripConfidenceClassifier.assess(
        journey(addresses[0], addresses[1], DateTime(2026, 9, 23, 8)),
      );
      expect(result.isHighConfidence, isFalse);
      expect(result.decisionReason, contains('exception'));
      expect(result.suggestedBulkyTools, isFalse);
      expect(result.suggestedPurpose, isNot('Tool Transport'));
    }
  });

  test('time does not invent an emergency callout or tools', () {
    for (final date in [DateTime(2026, 9, 27, 14), DateTime(2026, 9, 23, 23)]) {
      final result =
          TripConfidenceClassifier.assess(journey('Site A', 'Site B', date));
      expect(result.isHighConfidence, isFalse);
      expect(result.suggestedPurpose, isNot('Emergency Trade Callout'));
      expect(result.suggestedBulkyTools, isFalse);
    }
  });

  test('personal visits to merchants remain personal', () {
    final result = TripConfidenceClassifier.assess(journey(
      'Home',
      'Bunnings Warehouse',
      DateTime(2026, 9, 23, 10),
      classification: TripClassification.personal,
    ));
    expect(result.suggestedPurpose, 'Personal');
    expect(result.isHighConfidence, isFalse);
    expect(result.trip.isBusiness, isFalse);
  });
}
