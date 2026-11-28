import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/tracking/hardware_bluetooth_service.dart';

void main() {
  group('PR-16: Hardware Bluetooth Pairing by UUID and Hardware Identifier', () {
    final service = HardwareBluetoothService();

    test('Matches peripheral by exact hardware UUID', () {
      const device = HardwareBluetoothDevice(
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Generic OBD-II',
      );

      // Target configured as hardware UUID
      expect(
        service.isDeviceMatching(device, '123e4567-e89b-12d3-a456-426614174000'),
        isTrue,
      );
      // Case insensitivity
      expect(
        service.isDeviceMatching(device, '123E4567-E89B-12D3-A456-426614174000'),
        isTrue,
      );
    });

    test('Matches peripheral by MAC address or hardware identifier substring', () {
      const device = HardwareBluetoothDevice(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'Car Kit',
      );

      expect(service.isDeviceMatching(device, 'AA:BB:CC:DD:EE:FF'), isTrue);
      expect(service.isDeviceMatching(device, 'aa:bb:cc:dd:ee:ff'), isTrue);
    });

    test('Rejects rogue peripheral broadcasting matching name substring when UUID does not match', () {
      const rogueDevice = HardwareBluetoothDevice(
        id: '99999999-9999-9999-9999-999999999999',
        name: 'Ford SYNC',
      );

      // Paired vehicle hardware target UUID
      const targetUuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(service.isDeviceMatching(rogueDevice, targetUuid), isFalse);
    });

    test('Preserves name substring matching for legacy name configurations', () {
      const device = HardwareBluetoothDevice(
        id: 'audio_123',
        name: 'Ford SYNC Handsfree',
      );

      expect(service.isDeviceMatching(device, 'Ford SYNC'), isTrue);
    });

    test('Noise Discard Filter rejects smartwatches, fitness bands, and trackers', () {
      expect(service.isNoiseDevice('Apple Watch Series 9'), isTrue);
      expect(service.isNoiseDevice('Galaxy Watch 6'), isTrue);
      expect(service.isNoiseDevice('Garmin Forerunner 965'), isTrue);
      expect(service.isNoiseDevice('Fitbit Charge 6'), isTrue);
      expect(service.isNoiseDevice('Mi Band 7'), isTrue);
      expect(service.isNoiseDevice('AirTag Living Room'), isTrue);
      expect(service.isNoiseDevice('Logitech Bluetooth Keyboard'), isTrue);

      // Car devices must NOT be classified as noise
      expect(service.isNoiseDevice('Ford SYNC'), isFalse);
      expect(service.isNoiseDevice('Toyota Touch 2'), isFalse);
      expect(service.isNoiseDevice('BT_CAR_KIT'), isFalse);
      expect(service.isNoiseDevice('Isuzu D-Max Audio'), isFalse);
    });
  });
}
