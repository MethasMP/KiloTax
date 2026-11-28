import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/job_site.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/user_profile.dart';
import 'package:kiloclaim/services/engine/tax_calculator_service.dart';
import 'package:kiloclaim/services/tracking/job_site_auto_learner.dart';

void main() {
  group('JobSiteAutoLearner', () {
    test('suggests a repeated business destination with >= 2 visits within 150m', () {
      final trips = [
        Trip(
          id: 't1',
          vehicleId: 'v1',
          date: DateTime(2026, 10, 1, 9, 0),
          distanceKm: 18.0,
          purpose: 'Site Work',
          destinationAddress: '44 Spencer St, Melbourne VIC',
          endLat: -37.8180,
          endLng: 144.9530,
          classification: TripClassification.business,
        ),
        Trip(
          id: 't2',
          vehicleId: 'v1',
          date: DateTime(2026, 10, 3, 9, 15),
          distanceKm: 18.2,
          purpose: 'Site Work',
          destinationAddress: '44 Spencer St, Melbourne VIC',
          endLat: -37.8182,
          endLng: 144.9531,
          classification: TripClassification.business,
        ),
      ];

      final suggestions = JobSiteAutoLearner.suggest(
        trips: trips,
        existingSites: const [],
      );

      expect(suggestions.length, 1);
      expect(suggestions.first.name, '44 Spencer St');
      expect(suggestions.first.visitCount, 2);
    });

    test('excludes already-saved JobSites and home coordinates', () {
      final profile = UserProfile(
        homeLatitude: -37.8000,
        homeLongitude: 144.9000,
      );
      final existingSite = JobSite(
        id: 'js_1',
        name: 'Saved Site',
        latitude: -37.8500,
        longitude: 144.9800,
        radiusMeters: 200.0,
      );
      final trips = [
        Trip(
          id: 't_home_1',
          vehicleId: 'v1',
          date: DateTime(2026, 10, 1),
          distanceKm: 12.0,
          purpose: 'Return',
          endLat: -37.8001,
          endLng: 144.9001,
          classification: TripClassification.business,
        ),
        Trip(
          id: 't_home_2',
          vehicleId: 'v1',
          date: DateTime(2026, 10, 2),
          distanceKm: 12.0,
          purpose: 'Return',
          endLat: -37.8002,
          endLng: 144.9001,
          classification: TripClassification.business,
        ),
        Trip(
          id: 't_saved_1',
          vehicleId: 'v1',
          date: DateTime(2026, 10, 3),
          distanceKm: 15.0,
          purpose: 'Work',
          endLat: -37.8501,
          endLng: 144.9801,
          classification: TripClassification.business,
        ),
        Trip(
          id: 't_saved_2',
          vehicleId: 'v1',
          date: DateTime(2026, 10, 4),
          distanceKm: 15.0,
          purpose: 'Work',
          endLat: -37.8502,
          endLng: 144.9802,
          classification: TripClassification.business,
        ),
      ];

      final suggestions = JobSiteAutoLearner.suggest(
        trips: trips,
        existingSites: [existingSite],
        userProfile: profile,
      );

      expect(suggestions, isEmpty);
    });
  });

  group('TaxCalculatorService.estimateAnnualUteRunningCost', () {
    test('calculates conservative fixed + per-km ute benchmark', () {
      expect(TaxCalculatorService.estimateAnnualUteRunningCost(0), 4200.0);
      expect(
        TaxCalculatorService.estimateAnnualUteRunningCost(15000),
        closeTo(7800.0, 0.01),
      );
    });
  });
}
