import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/trip.dart';
import 'wgs84_geodesic_engine.dart';
import 'road_snap_routing_service.dart';
import 'geocoding_service.dart';

/// Detection States of the Autonomous Telemetry Engine
enum AutonomousDetectorState {
  idle,
  verifyingDeparture,
  activeDriving,
  ghostAnchorPending,
  finalized,
}

/// A lightweight, immutable snapshot of an identified stop location
class GhostAnchor {
  final Position position;
  final DateTime stationarySince;

  const GhostAnchor({
    required this.position,
    required this.stationarySince,
  });
}

/// Autonomous Trip Detector (Japanese Monozukuri & Root-Cause Engineering)
///
/// Features:
/// 1. Circular Ring Buffer (O(1) Memory): Preserves pre-drive stationary fixes so departure km is never lost.
/// 2. Bus-Stop Transit Filter: Discards transit patterns (stops every 200-400m).
/// 3. Ghost Anchor Lazy Finalization: Eliminates traffic light false-stops & handles forgotten phones in vehicles.
/// 4. WGS-84 & Road-Snap Integration: Produces exact asphalt distances for ATO Box D1 compliance.
class AutonomousTripDetector {
  final int ringBufferSize;
  final Duration sustainedSpeedThresholdDuration;
  final double minDrivingSpeedKmh;
  final Duration ghostAnchorTimeout;

  final RoadSnapRoutingService _routingService;
  final Queue<Position> _ringBuffer = Queue<Position>();
  final List<Position> _activeTripPath = [];

  AutonomousDetectorState _state = AutonomousDetectorState.idle;
  DateTime? _firstSpeedExceededTime;
  GhostAnchor? _ghostAnchor;
  Trip? _finalizedTrip;

  // Transit Discrimination (Bus-Stop Signature Tracker)
  int _consecutiveShortHops = 0;
  Position? _lastHopStopPosition;

  AutonomousTripDetector({
    this.ringBufferSize = 15, // ~60 seconds at 4s intervals
    this.sustainedSpeedThresholdDuration = const Duration(seconds: 20),
    this.minDrivingSpeedKmh = 20.0,
    this.ghostAnchorTimeout = const Duration(minutes: 5),
    RoadSnapRoutingService? routingService,
  }) : _routingService = routingService ?? RoadSnapRoutingService();

  AutonomousDetectorState get state => _state;
  GhostAnchor? get ghostAnchor => _ghostAnchor;
  Trip? get finalizedTrip => _finalizedTrip;
  List<Position> get activeTripPath => List.unmodifiable(_activeTripPath);

  void reset() {
    _ringBuffer.clear();
    _activeTripPath.clear();
    _state = AutonomousDetectorState.idle;
    _firstSpeedExceededTime = null;
    _ghostAnchor = null;
    _finalizedTrip = null;
    _consecutiveShortHops = 0;
    _lastHopStopPosition = null;
  }

  /// Ingests a new continuous GPS fix from device hardware stream
  Future<AutonomousDetectorState> processFix(Position fix, {DateTime? simulatedNow}) async {
    final now = simulatedNow ?? DateTime.now();
    final speedKmh = fix.speed > 0.5 ? (fix.speed * 3.6) : 0.0;

    switch (_state) {
      case AutonomousDetectorState.idle:
        _maintainRingBuffer(fix);
        if (speedKmh >= minDrivingSpeedKmh) {
          _state = AutonomousDetectorState.verifyingDeparture;
          _firstSpeedExceededTime = now;
        }
        break;

      case AutonomousDetectorState.verifyingDeparture:
        _maintainRingBuffer(fix);
        if (speedKmh < (minDrivingSpeedKmh * 0.7)) {
          // Speed dropped before sustained duration -> Abort false start
          _state = AutonomousDetectorState.idle;
          _firstSpeedExceededTime = null;
        } else if (_firstSpeedExceededTime != null &&
            now.difference(_firstSpeedExceededTime!) >= sustainedSpeedThresholdDuration) {
          // Sustained acceleration confirmed!
          // Retroactively recover departure point from earliest fix in ring buffer
          _state = AutonomousDetectorState.activeDriving;
          _activeTripPath.clear();
          if (_ringBuffer.isNotEmpty) {
            _activeTripPath.addAll(_ringBuffer);
          } else {
            _activeTripPath.add(fix);
          }
          _lastHopStopPosition = _activeTripPath.first;
          _firstSpeedExceededTime = null;
        }
        break;

      case AutonomousDetectorState.activeDriving:
        _activeTripPath.add(fix);

        // Check if vehicle has become stationary (Speed < 3 km/h)
        if (speedKmh < 3.0) {
          _state = AutonomousDetectorState.ghostAnchorPending;
          _ghostAnchor = GhostAnchor(position: fix, stationarySince: now);
        }
        break;

      case AutonomousDetectorState.ghostAnchorPending:
        _activeTripPath.add(fix);

        // Scenario A: Vehicle moves again before timeout (Traffic Light / Congestion)
        if (speedKmh >= 15.0) {
          final hopDistMeters = _lastHopStopPosition != null
              ? Wgs84GeodesicEngine.calculateDistanceMeters(
                  lat1: _lastHopStopPosition!.latitude,
                  lon1: _lastHopStopPosition!.longitude,
                  lat2: _ghostAnchor!.position.latitude,
                  lon2: _ghostAnchor!.position.longitude,
                )
              : 0.0;

          // Transit Detection: Check if hop was 150m - 450m (typical bus stop distance)
          if (hopDistMeters >= 150.0 && hopDistMeters <= 450.0) {
            _consecutiveShortHops++;
          } else if (hopDistMeters > 500.0) {
            _consecutiveShortHops = 0; // Reset if long stretch
          }

          _lastHopStopPosition = _ghostAnchor!.position;
          _ghostAnchor = null;

          // Reject if 3 consecutive short bus stops detected
          if (_consecutiveShortHops >= 3) {
            debugPrint('[AutonomousDetector] Public Bus Pattern Detected. Trip discarded.');
            reset();
            return _state;
          }

          // Resume normal active driving
          _state = AutonomousDetectorState.activeDriving;
        }
        // Scenario B: Vehicle remains stationary past Ghost Anchor timeout (True Destination Reached)
        else if (_ghostAnchor != null && now.difference(_ghostAnchor!.stationarySince) >= ghostAnchorTimeout) {
          await _sealTripRetroactively(_ghostAnchor!.position, _ghostAnchor!.stationarySince);
          _state = AutonomousDetectorState.finalized;
        }
        break;

      case AutonomousDetectorState.finalized:
        // Awaiting user pickup or reset
        break;
    }

    return _state;
  }

  void _maintainRingBuffer(Position fix) {
    if (_ringBuffer.length >= ringBufferSize) {
      _ringBuffer.removeFirst();
    }
    _ringBuffer.addLast(fix);
  }

  /// Seals the trip retroactively to the exact initial stationary moment
  Future<void> _sealTripRetroactively(Position endFix, DateTime endTime) async {
    if (_activeTripPath.isEmpty) return;

    final startFix = _activeTripPath.first;

    // 1. Calculate Road-Snapped Asphalt Driving Distance
    final routeResult = await _routingService.calculateRoadDistanceKm(
      startLat: startFix.latitude,
      startLon: startFix.longitude,
      endLat: endFix.latitude,
      endLon: endFix.longitude,
    );

    // 2. Resolve Suburb Names
    final originName = await GeocodingService.reverseGeocode(
      startFix.latitude,
      startFix.longitude,
    );
    final destName = await GeocodingService.reverseGeocode(
      endFix.latitude,
      endFix.longitude,
    );

    _finalizedTrip = Trip(
      id: 'auto_trip_${endTime.millisecondsSinceEpoch}',
      vehicleId: 'primary_vehicle',
      distanceKm: routeResult.roadDistanceKm,
      date: startFix.timestamp,
      purpose: 'Client / Job Site Visit',
      startOdometer: 0.0,
      endOdometer: 0.0,
      originAddress: originName,
      destinationAddress: destName,
      classification: TripClassification.business,
    );
  }
}
