import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/tracking/geocoding_service.dart';

void main() {
  group('GeocodingService Precision & Formatting Tests', () {
    test('Richmond VIC returns Road and Suburb formatted for ATO', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'address': {
              'road': 'St Crispin Street',
              'suburb': 'Richmond',
              'city': 'Melbourne',
              'state': 'Victoria',
              'postcode': '3121',
            }
          }),
          200,
        );
      });

      final result = await GeocodingService.reverseGeocode(
        -37.8248,
        144.9984,
        client: mockClient,
      );

      print('MOCK TEST RESULT [Richmond]: $result');
      expect(result, equals('St Crispin Street, Richmond VIC'));
    });

    test('Chadstone VIC returns Road and Suburb formatted for ATO', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'address': {
              'road': 'Collins Street',
              'suburb': 'Chadstone',
              'city': 'Melbourne',
              'state': 'Victoria',
              'postcode': '3148',
            }
          }),
          200,
        );
      });

      final result = await GeocodingService.reverseGeocode(
        -37.8767,
        145.0934,
        client: mockClient,
      );

      print('MOCK TEST RESULT [Chadstone]: $result');
      expect(result, equals('Collins Street, Chadstone VIC'));
    });

    test('Surry Hills NSW returns Road and Suburb formatted for ATO', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'address': {
              'road': 'Holt Street',
              'suburb': 'Surry Hills',
              'city': 'Sydney',
              'state': 'New South Wales',
              'postcode': '2010',
            }
          }),
          200,
        );
      });

      final result = await GeocodingService.reverseGeocode(
        -33.8860,
        151.2094,
        client: mockClient,
      );

      print('MOCK TEST RESULT [Surry Hills]: $result');
      expect(result, equals('Holt Street, Surry Hills NSW'));
    });

    test('Graceful fallback to coordinates when network/API drops', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final result = await GeocodingService.reverseGeocode(
        -37.825,
        144.998,
        client: mockClient,
      );

      print('MOCK TEST RESULT [Fallback]: $result');
      expect(result, equals('Location (-37.825, 144.998)'));
    });
    test('stateFromCoordinates resolves all Australian states via GPS geofencing and null for foreign coordinates', () {
      expect(GeocodingService.stateFromCoordinates(-37.8136, 144.9631), equals('VIC')); // Melbourne
      expect(GeocodingService.stateFromCoordinates(-33.8688, 151.2093), equals('NSW')); // Sydney
      expect(GeocodingService.stateFromCoordinates(-27.4698, 153.0251), equals('QLD')); // Brisbane
      expect(GeocodingService.stateFromCoordinates(-31.9505, 115.8605), equals('WA'));  // Perth
      expect(GeocodingService.stateFromCoordinates(-34.9285, 138.6007), equals('SA'));  // Adelaide
      expect(GeocodingService.stateFromCoordinates(-42.8821, 147.3272), equals('TAS')); // Hobart
      expect(GeocodingService.stateFromCoordinates(-12.4634, 130.8456), equals('NT'));  // Darwin
      expect(GeocodingService.stateFromCoordinates(-35.2809, 149.1300), equals('ACT')); // Canberra

      // Coordinates outside Australia (e.g. Bangkok Thailand, London UK, Tokyo Japan)
      expect(GeocodingService.stateFromCoordinates(13.7563, 100.5018), isNull); // Bangkok
      expect(GeocodingService.stateFromCoordinates(51.5074, -0.1278), isNull);  // London
      expect(GeocodingService.stateFromCoordinates(35.6762, 139.6503), isNull); // Tokyo
    });
  });
}
