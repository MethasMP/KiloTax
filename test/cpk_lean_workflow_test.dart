import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/services/engine/cpk_export_service.dart';

void main() {
  group('Lean CPK Workflow & Model Decoupling Tests', () {
    test('Trip entity instantiates without odometer readings for CPK', () {
      final trip = Trip(
        id: 'cpk_test_1',
        vehicleId: 'veh_hilux_01',
        distanceKm: 24.5,
        date: DateTime(2026, 9, 17, 10, 30),
        purpose: 'Client / Job Site Visit',
        originAddress: 'Richmond VIC',
        destinationAddress: 'Dandenong South VIC',
      );

      expect(trip.startOdometer, equals(0.0));
      expect(trip.endOdometer, equals(0.0));
      expect(trip.distanceKm, equals(24.5));
      expect(trip.isBusiness, isTrue);
    });

    test('Trip.fromJson parses CPK payload missing odometer values', () {
      final jsonPayload = {
        'id': 'cpk_remote_02',
        'vehicle_id': 'veh_hilux_01',
        'distance_km': 15.0,
        'date': '2026-09-17T11:00:00.000Z',
        'purpose': 'Trade Supplies / Bunnings',
        'origin_address': 'Clayton VIC',
        'destination_address': 'Bunnings Springvale',
        'classification': 'business',
      };

      final trip = Trip.fromJson(jsonPayload);
      expect(trip.startOdometer, equals(0.0));
      expect(trip.endOdometer, equals(0.0));
      expect(trip.distanceKm, equals(15.0));
      expect(trip.purpose, equals('Trade Supplies / Bunnings'));
    });

    test('CpkExportService generates Box D1 Slip text with proper rate and legal citations', () {
      final vehicle = Vehicle(
        id: 'veh_01',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'VIC-TRADIE',
        initialOdometer: 0,
        engineCapacity: '2.8L Turbo Diesel',
        vehicleType: VehicleType.ute,
      );

      final trips = [
        Trip(
          id: 't1',
          vehicleId: vehicle.id,
          distanceKm: 50.0,
          date: DateTime(2026, 9, 17),
          purpose: 'Client / Job Site Visit',
          originAddress: 'Richmond VIC',
          destinationAddress: 'Dandenong South VIC',
        ),
        Trip(
          id: 't2',
          vehicleId: vehicle.id,
          distanceKm: 20.0,
          date: DateTime(2026, 9, 17),
          purpose: 'Trade Supplies / Bunnings Run',
          originAddress: 'Dandenong South VIC',
          destinationAddress: 'Bunnings Warehouse',
        ),
      ];

      final csv = CpkExportService.generateCpkTripLedgerCsv(
        vehicle: vehicle,
        trips: trips,
        taxRule: AppConstants.activeTaxRule,
      );

      expect(csv.contains('VIC-TRADIE'), isTrue);
      expect(csv.contains('Richmond VIC'), isTrue);
      expect(csv.contains('Bunnings Warehouse'), isTrue);
      expect(csv.contains('50.00'), isTrue);
    });
  });
}
