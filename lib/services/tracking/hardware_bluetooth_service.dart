import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audio_session/audio_session.dart';

enum BluetoothDeviceCategory {
  carAudio,
  wearable,
  headphone,
  other,
}

/// Real Hardware Bluetooth Discovered Device Representation
class HardwareBluetoothDevice {
  final String id;
  final String name;
  final bool isAudioRoute;
  final int? rssi;
  final BluetoothDeviceCategory category;

  const HardwareBluetoothDevice({
    required this.id,
    required this.name,
    this.isAudioRoute = false,
    this.rssi,
    this.category = BluetoothDeviceCategory.other,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HardwareBluetoothDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Hardware Bluetooth Discovery & Audio Route Detection Service
/// Combines:
/// 1. AVAudioSession / Android Audio Route inspection (detects connected Car Audio / CarPlay / Handsfree)
/// 2. Hardware Bluetooth Low Energy (BLE) scanning with flutter_blue_plus
class HardwareBluetoothService {
  static final HardwareBluetoothService _instance =
      HardwareBluetoothService._internal();
  factory HardwareBluetoothService() => _instance;
  HardwareBluetoothService._internal();

  /// Inspect current system audio output devices for connected Car Bluetooth/CarPlay/Handsfree
  Future<List<HardwareBluetoothDevice>> getActiveAudioBluetoothDevices() async {
    final List<HardwareBluetoothDevice> audioDevices = [];
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();

      for (final dev in devices) {
        // Look for Bluetooth A2DP, Headset, or Car Audio outputs
        final typeName = dev.type.name.toLowerCase();
        if (typeName.contains('bluetooth') ||
            typeName.contains('car') ||
            typeName.contains('headset') ||
            typeName.contains('a2dp')) {
          final cleanName = dev.name.trim();
          if (cleanName.isNotEmpty) {
            final category = _classifyDevice(name: cleanName, isAudioRoute: true);
            audioDevices.add(
              HardwareBluetoothDevice(
                id: 'audio_${dev.id}',
                name: cleanName,
                isAudioRoute: true,
                category: category,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[KiloTax Bluetooth] Error querying system audio devices: $e');
    }
    return audioDevices;
  }

  /// Start hardware BLE scan and emit discovered devices
  Stream<List<HardwareBluetoothDevice>> scanNearbyDevices(
      {Duration timeout = const Duration(seconds: 4)}) async* {
    final Map<String, HardwareBluetoothDevice> discovered = {};

    final activeAudio = await getActiveAudioBluetoothDevices();
    for (final dev in activeAudio) {
      discovered[dev.name] = dev;
    }
    yield discovered.values.toList();

    try {
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      for (final dev in systemDevices) {
        final name =
            dev.platformName.isNotEmpty ? dev.platformName : dev.advName;
        if (name.trim().isNotEmpty) {
          discovered[name] = HardwareBluetoothDevice(
            id: dev.remoteId.str,
            name: name.trim(),
            isAudioRoute: false,
          );
        }
      }
      yield discovered.values.toList();
    } catch (e) {
      debugPrint('[KiloTax Bluetooth] Note querying system devices: $e');
    }

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        yield discovered.values.toList();
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        yield discovered.values.toList();
        return;
      }

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      await for (final results in FlutterBluePlus.scanResults) {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          if (name.trim().isNotEmpty) {
            discovered[name] = HardwareBluetoothDevice(
              id: r.device.remoteId.str,
              name: name.trim(),
              isAudioRoute: false,
              rssi: r.rssi,
            );
          }
        }
        yield discovered.values.toList();
      }
    } catch (e) {
      debugPrint(
          '[KiloTax Bluetooth] Live scan error or simulator fallback: $e');
    } finally {
      try {
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }
      } catch (e, stack) {
        debugPrint(
            '[HardwareBluetoothService] Warning stopping scan in finally block: $e\n$stack');
      }
    }
  }

  /// High-Precision Continuous Radar Stream:
  /// Combines Audio Route, System Bonded Devices, and Continuous BLE Broadcasts.
  /// When [filterAutomotiveOnly] is true, aggressively discards noise devices (watches, fitness bands, generic sensors).
  Stream<List<HardwareBluetoothDevice>> continuousRadarStream({
    String? preferredVehicleMake,
    bool filterAutomotiveOnly = true,
  }) async* {
    final Map<String, HardwareBluetoothDevice> discovered = {};

    void addDevice(HardwareBluetoothDevice dev) {
      if (filterAutomotiveOnly && isNoiseDevice(dev.name)) {
        return; // Noise rejection: watches, bands, heartrate monitors
      }
      discovered[dev.name] = dev;
    }

    // 1. Instant Audio Route Yield (CarPlay / Connected Head Unit)
    final activeAudio = await getActiveAudioBluetoothDevices();
    for (final dev in activeAudio) {
      addDevice(dev);
    }
    yield _rankDevices(discovered.values.toList(), preferredVehicleMake);

    // 2. Query iOS/Android System Bonded & Paired Devices
    // On iOS, querying systemDevices with standard automotive service UUIDs returns paired head units:
    // 0x180A: Device Information, 0x1800: Generic Access, 0x110A: A2DP Audio, 0x111E: Handsfree
    try {
      final List<Guid> automotiveServices = [
        Guid("180A"),
        Guid("1800"),
        Guid("110A"),
        Guid("111E"),
      ];
      final systemDevices = await FlutterBluePlus.systemDevices(automotiveServices);
      for (final dev in systemDevices) {
        final name = dev.platformName.isNotEmpty ? dev.platformName : dev.advName;
        final clean = name.trim();
        if (clean.isNotEmpty && !discovered.containsKey(clean)) {
          final cat = _classifyDevice(name: clean, isAudioRoute: false);
          addDevice(HardwareBluetoothDevice(
            id: dev.remoteId.str,
            name: clean,
            isAudioRoute: false,
            category: cat,
          ));
        }
      }
      yield _rankDevices(discovered.values.toList(), preferredVehicleMake);
    } catch (e) {
      debugPrint('[KiloTax Bluetooth] System devices query note: $e');
    }

    // Also query generic system devices without filter for Android & compatible iOS devices
    try {
      final genericSys = await FlutterBluePlus.systemDevices([]);
      for (final dev in genericSys) {
        final name = dev.platformName.isNotEmpty ? dev.platformName : dev.advName;
        final clean = name.trim();
        if (clean.isNotEmpty && !discovered.containsKey(clean)) {
          final cat = _classifyDevice(name: clean, isAudioRoute: false);
          addDevice(HardwareBluetoothDevice(
            id: dev.remoteId.str,
            name: clean,
            isAudioRoute: false,
            category: cat,
          ));
        }
      }
      yield _rankDevices(discovered.values.toList(), preferredVehicleMake);
    } catch (_) {}

    // 3. Continuous Active BLE Scan
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        debugPrint('[KiloTax Bluetooth] Bluetooth is not supported on this device');
        return;
      }

      // In iOS / iPadOS, querying adapterState.first can hang or take time if not actively powered.
      // We check adapter state with timeout to avoid blocking.
      try {
        final adapterState = await FlutterBluePlus.adapterState
            .firstWhere((s) => s != BluetoothAdapterState.unknown)
            .timeout(const Duration(milliseconds: 1200), onTimeout: () => BluetoothAdapterState.on);
        if (adapterState == BluetoothAdapterState.off ||
            adapterState == BluetoothAdapterState.unauthorized) {
          debugPrint('[KiloTax Bluetooth] Bluetooth adapter is not enabled ($adapterState)');
          return;
        }
      } catch (e) {
        debugPrint('[KiloTax Bluetooth] Note reading adapter state: $e');
      }

      if (!FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.startScan(
          androidUsesFineLocation: true,
          // Continuous scan without auto-timeout while screen is active
        );
      }

      await for (final results in FlutterBluePlus.scanResults) {
        bool changed = false;
        for (final r in results) {
          final rawName = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          final name = rawName.trim();

          // Filter out anonymous/empty devices or random hex identifiers
          if (name.isNotEmpty && !name.startsWith('0x') && name.length > 1) {
            if (filterAutomotiveOnly && isNoiseDevice(name)) {
              continue;
            }

            if (!discovered.containsKey(name) || discovered[name]?.rssi != r.rssi) {
              final cat = _classifyDevice(
                name: name,
                isAudioRoute: discovered[name]?.isAudioRoute ?? false,
                appearance: r.advertisementData.appearance,
              );
              discovered[name] = HardwareBluetoothDevice(
                id: r.device.remoteId.str,
                name: name,
                isAudioRoute: discovered[name]?.isAudioRoute ?? false,
                rssi: r.rssi,
                category: cat,
              );
              changed = true;
            }
          }
        }
        if (changed) {
          yield _rankDevices(discovered.values.toList(), preferredVehicleMake);
        }
      }
    } catch (e) {
      debugPrint('[KiloTax Bluetooth] Continuous radar scan error: $e');
    } finally {
      await stopScan();
    }
  }

  /// Classifies device category based on name, audio routing, or BLE appearance
  BluetoothDeviceCategory _classifyDevice({
    required String name,
    required bool isAudioRoute,
    int? appearance,
  }) {
    if (isNoiseDevice(name)) {
      return BluetoothDeviceCategory.wearable;
    }
    // BLE Appearance characteristic
    // 0x0841 = Car Audio / Vehicle Handsfree
    // 0x0842 = Headphone / Earbuds
    // 0x03C1 = Watch / Smartwatch
    if (appearance != null) {
      if (appearance == 0x0841) return BluetoothDeviceCategory.carAudio;
      if (appearance == 0x03C0 || appearance == 0x03C1 || appearance == 0x03C2) {
        return BluetoothDeviceCategory.wearable;
      }
      if (appearance == 0x0842) return BluetoothDeviceCategory.headphone;
    }

    final lower = name.toLowerCase();
    if (isAudioRoute) {
      if (lower.contains('car') ||
          lower.contains('sync') ||
          lower.contains('multimedia') ||
          lower.contains('toyota') ||
          lower.contains('ford') ||
          lower.contains('isuzu') ||
          lower.contains('mazda') ||
          lower.contains('pioneer') ||
          lower.contains('kenwood') ||
          lower.contains('alpine')) {
        return BluetoothDeviceCategory.carAudio;
      }
      if (lower.contains('airpods') ||
          lower.contains('wh-1000') ||
          lower.contains('wf-1000') ||
          lower.contains('earbuds') ||
          lower.contains('headphone') ||
          lower.contains('bose')) {
        return BluetoothDeviceCategory.headphone;
      }
      return BluetoothDeviceCategory.carAudio; // Default audio route to automotive potential
    }

    if (lower.contains('car') ||
        lower.contains('sync') ||
        lower.contains('auto') ||
        lower.contains('bt_car')) {
      return BluetoothDeviceCategory.carAudio;
    }

    return BluetoothDeviceCategory.other;
  }

  /// Noise Discard Filter: returns true for smartwatches, fitness trackers, smart home tags, TV, etc.
  bool isNoiseDevice(String name) {
    final lower = name.toLowerCase();
    const noiseKeywords = [
      'watch',
      'apple watch',
      'galaxy watch',
      'garmin',
      'fitbit',
      'band',
      'mi band',
      'huawei band',
      'oura',
      'whoop',
      'tag',
      'airtag',
      'smart tag',
      'tile',
      'keyboard',
      'mouse',
      'tv',
      'apple tv',
      'printer',
      'bulb',
      'light',
      'switch',
    ];

    for (final kw in noiseKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  /// Sort and prioritize automotive, audio, and brand-matching devices to the top
  List<HardwareBluetoothDevice> _rankDevices(
    List<HardwareBluetoothDevice> devices,
    String? vehicleMake,
  ) {
    final list = List<HardwareBluetoothDevice>.from(devices);
    list.sort((a, b) {
      final aScore = _deviceRelevanceScore(a, vehicleMake);
      final bScore = _deviceRelevanceScore(b, vehicleMake);
      return bScore.compareTo(aScore);
    });
    return list;
  }

  /// Calculates relevance weight for vehicle matching
  int _deviceRelevanceScore(HardwareBluetoothDevice dev, String? vehicleMake) {
    int score = 0;
    final nameLower = dev.name.toLowerCase();

    // Active audio route (CarPlay / Head Unit) is king
    if (dev.isAudioRoute) score += 100;

    // Matched vehicle make
    if (vehicleMake != null && vehicleMake.trim().isNotEmpty) {
      final makeLower = vehicleMake.trim().toLowerCase();
      if (nameLower.contains(makeLower)) {
        score += 80;
      }
    }

    // Common automotive infotainment keywords
    const carKeywords = [
      'car',
      'carplay',
      'sync',
      'multimedia',
      'toyota',
      'ford',
      'isuzu',
      'mitsubishi',
      'mazda',
      'nissan',
      'hyundai',
      'holden',
      'volkswagen',
      'vw',
      'bt_car',
      'pioneer',
      'kenwood',
      'sony',
      'alpine',
      'subaru'
    ];
    for (final kw in carKeywords) {
      if (nameLower.contains(kw)) {
        score += 40;
        break;
      }
    }

    // RSSI signal strength bonus (closer devices higher)
    if (dev.rssi != null && dev.rssi! > -75) {
      score += 10;
    }

    return score;
  }

  /// Checks if a device is specifically recommended for a vehicle
  bool isRecommendedForVehicle(HardwareBluetoothDevice dev, String? vehicleMake) {
    if (dev.isAudioRoute) return true;
    final nameLower = dev.name.toLowerCase();
    if (vehicleMake != null && vehicleMake.isNotEmpty) {
      if (nameLower.contains(vehicleMake.toLowerCase())) return true;
    }
    return nameLower.contains('car') ||
        nameLower.contains('sync') ||
        nameLower.contains('multimedia');
  }

  /// Evaluates whether a discovered [device] matches the configured target [targetIdentifierOrName].
  /// Supports exact hardware identifier / UUID / MAC matching as well as name matching.
  bool isDeviceMatching(HardwareBluetoothDevice device, String targetIdentifierOrName) {
    final cleanTarget = targetIdentifierOrName.trim().toLowerCase();
    if (cleanTarget.isEmpty) return false;

    final deviceId = device.id.trim().toLowerCase();
    final deviceName = device.name.trim().toLowerCase();

    // 1. Exact match on hardware UUID / MAC address
    if (deviceId == cleanTarget) {
      return true;
    }

    // 2. Hardware ID contains target UUID
    if (deviceId.contains(cleanTarget)) {
      return true;
    }

    // 3. Name exact match or contains substring
    if (deviceName == cleanTarget || deviceName.contains(cleanTarget)) {
      return true;
    }

    return false;
  }

  /// Stop active scan safely
  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (e, stack) {
      debugPrint(
          '[HardwareBluetoothService] Warning stopping scan: $e\n$stack');
    }
  }
}
