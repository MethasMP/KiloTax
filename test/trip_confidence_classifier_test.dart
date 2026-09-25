import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/services/engine/trip_confidence_classifier.dart';

void main() {
  group('TripConfidenceClassifier (Sentinel Risk Gatekeeper)', () {
    test('Weekdays to trade merchants classified as highConfidenceWork', () {
      final trip = Trip(
        id: 't_bunnings',
        vehicleId: 'v1',
        distanceKm: 12.0,
        // Wednesday at 10:30 AM
        date: DateTime(2026, 9, 23, 10, 30),
        purpose: '?',
        originAddress: 'Home Base',
        destinationAddress: 'Bunnings Warehouse Notting Hill',
        classification: TripClassification.unclassified,
      );

      final assessment = TripConfidenceClassifier.assess(trip);
      expect(assessment.isHighConfidence, isTrue);
      expect(assessment.suggestedPurpose, 'Supplies Run');
    });

    test('Weekend travel strictly held for user decision (Sentinel Guard)', () {
      final trip = Trip(
        id: 't_sunday_drive',
        vehicleId: 'v1',
        distanceKm: 18.5,
        // Sunday at 2:00 PM
        date: DateTime(2026, 9, 27, 14, 0),
        purpose: '?',
        originAddress: 'Home Base',
        destinationAddress: 'Client Site Richmond',
        classification: TripClassification.unclassified,
      );

      final assessment = TripConfidenceClassifier.assess(trip);
      expect(assessment.isHighConfidence, isFalse);
      expect(assessment.tier, ConfidenceTier.requiresUserDecision);
      expect(assessment.decisionReason, contains('Weekend drive requires explicit trade confirmation'));
    });

    test('Late night travel held for user confirmation', () {
      final trip = Trip(
        id: 't_late_night',
        vehicleId: 'v1',
        distanceKm: 15.0,
        // Wednesday at 11:30 PM (after hours)
        date: DateTime(2026, 9, 23, 23, 30),
        purpose: '?',
        originAddress: 'Site A',
        destinationAddress: 'Site B',
        classification: TripClassification.unclassified,
      );

      final assessment = TripConfidenceClassifier.assess(trip);
      expect(assessment.isHighConfidence, isFalse);
      expect(assessment.tier, ConfidenceTier.requiresUserDecision);
      expect(assessment.suggestedPurpose, 'Emergency Trade Callout');
    });

    test('Weekday job site travel is high confidence', () {
      final trip = Trip(
        id: 't_site',
        vehicleId: 'v1',
        distanceKm: 25.0,
        // Tuesday at 8:00 AM
        date: DateTime(2026, 9, 22, 8, 0),
        purpose: '?',
        originAddress: 'Workshop Depot',
        destinationAddress: 'Client Site Hawthorn',
        classification: TripClassification.unclassified,
      );

      final assessment = TripConfidenceClassifier.assess(trip);
      expect(assessment.isHighConfidence, isTrue);
      expect(assessment.suggestedPurpose, 'Client Site');
    });
  });
}
