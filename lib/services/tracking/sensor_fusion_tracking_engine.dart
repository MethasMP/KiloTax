import 'package:geolocator/geolocator.dart';
import 'wgs84_geodesic_engine.dart';

export 'odometer_gap_reconciler.dart';

/// Sensor Fusion & Dead Reckoning Core Engine
///
/// Principles:
/// 1. WGS-84 Ellipsoidal Vincenty Geodesics (< 0.5mm geometric error).
/// 2. 1D Kalman Spatial Filter for satellite multipath noise suppression.
/// 3. Physical Sanity Checks: A vehicle cannot accelerate faster than gravity/engine traction allows.
/// 4. Anti-Drift Stationary Filter (ZUPT): While standing still, GPS jitter is discarded to 0.00 km.
class FilteredPositionUpdate {
  final double distanceDeltaKm;
  final double instantaneousSpeedKmh;
  final bool isStationary;
  final bool isAnomalousJumpDiscarded;
  final Position currentPosition;

  const FilteredPositionUpdate({
    required this.distanceDeltaKm,
    required this.instantaneousSpeedKmh,
    required this.isStationary,
    required this.isAnomalousJumpDiscarded,
    required this.currentPosition,
  });
}

class SensorFusionTrackingEngine {
  // Physical constraints for passenger & commercial utes in Australia
  static const double maxPlausibleSpeedKmh =
      160.0; // Above 160 km/h is flagged/clamped for tradie vehicles
  static const double maxPlausibleAccelerationMs2 =
      7.0; // ~0-100 in 4s. Tradie utes do not exceed this.
  static const double minMovementThresholdMeters =
      3.5; // Discards satellite multipath jitter
  static const double maxAcceptableAccuracyMeters =
      30.0; // Discards degraded fixes

  final Wgs84GeodesicEngine _geodesic = Wgs84GeodesicEngine();
  Position? _lastValidPosition;
  DateTime? _lastTimestamp;
  DateTime? _lastKalmanTimestamp;
  DateTime? _stationarySince;
  double _lastValidSpeedKmh = 0.0;

  void reset() {
    _geodesic.reset();
    _lastValidPosition = null;
    _lastTimestamp = null;
    _lastKalmanTimestamp = null;
    _stationarySince = null;
    _lastValidSpeedKmh = 0.0;
  }

  /// Ingests a raw GPS fix, applies Sensor Fusion, Kalman & WGS-84 Geodesic filters,
  /// and outputs high-fidelity audited distance delta.
  FilteredPositionUpdate processFix(Position newFix, {bool allowMockLocations = false}) {
    // Filter out spoofed/mocked GPS fixes to prevent audit fraud
    if (newFix.isMocked && !allowMockLocations) {
      return FilteredPositionUpdate(
        distanceDeltaKm: 0.0,
        instantaneousSpeedKmh: 0.0,
        isStationary: true,
        isAnomalousJumpDiscarded: true,
        currentPosition: _lastValidPosition ?? newFix,
      );
    }

    final now = newFix.timestamp;

    if (_lastValidPosition == null || _lastTimestamp == null) {
      _geodesic.filterPosition(
        lat: newFix.latitude,
        lon: newFix.longitude,
        accuracyMeters: newFix.accuracy,
        timeDeltaMilliseconds: 0,
      );
      _lastValidPosition = newFix;
      _lastTimestamp = now;
      _lastKalmanTimestamp = now;
      _lastValidSpeedKmh = newFix.speed > 0.8 ? (newFix.speed * 3.6) : 0.0;

      return FilteredPositionUpdate(
        distanceDeltaKm: 0.0,
        instantaneousSpeedKmh: _lastValidSpeedKmh,
        isStationary: _lastValidSpeedKmh < 3.0,
        isAnomalousJumpDiscarded: false,
        currentPosition: newFix,
      );
    }

    final rawDtMs = now.difference(_lastTimestamp!).inMilliseconds;
    final dtSeconds = (rawDtMs / 1000.0).clamp(0.05, 60.0);
    // Elapsed time since the last Kalman state update (spans stationary periods
    // so departure fixes are not pulled back to the stop location).
    final kalmanDtMs = (_lastKalmanTimestamp != null
            ? now.difference(_lastKalmanTimestamp!).inMilliseconds
            : rawDtMs)
        .clamp(50, 3600000);

    final rawMeters = Wgs84GeodesicEngine.calculateDistanceMeters(
      lat1: _lastValidPosition!.latitude,
      lon1: _lastValidPosition!.longitude,
      lat2: newFix.latitude,
      lon2: newFix.longitude,
    );

    final calculatedSpeedMs = rawMeters / dtSeconds;
    final calculatedSpeedKmh = calculatedSpeedMs * 3.6;

    // Filter A: Degraded GPS Accuracy
    if (newFix.accuracy > maxAcceptableAccuracyMeters) {
      // Degraded fix -> Use Dead Reckoning: Keep previous heading & damp speed
      _lastValidSpeedKmh *= 0.95;
      return FilteredPositionUpdate(
        distanceDeltaKm: 0.0,
        instantaneousSpeedKmh: _lastValidSpeedKmh,
        isStationary: _lastValidSpeedKmh < 3.0,
        isAnomalousJumpDiscarded: true,
        currentPosition: _lastValidPosition!,
      );
    }

    // Filter B: Unphysical Jump / Teleportation (GPS Glitch Filter)
    if (calculatedSpeedKmh > maxPlausibleSpeedKmh) {
      // Impossible velocity: satellite reflection bounced across town
      return FilteredPositionUpdate(
        distanceDeltaKm: 0.0,
        instantaneousSpeedKmh: _lastValidSpeedKmh,
        isStationary: false,
        isAnomalousJumpDiscarded: true,
        currentPosition: _lastValidPosition!,
      );
    }

    // Filter B2: Physical Acceleration Sanity Gate (maxPlausibleAccelerationMs2)
    final prevSpeedMs = _lastValidSpeedKmh / 3.6;
    final accelerationMs2 = (calculatedSpeedMs - prevSpeedMs).abs() / dtSeconds;
    if (dtSeconds >= 0.5 &&
        accelerationMs2 > maxPlausibleAccelerationMs2 &&
        calculatedSpeedKmh > 25.0) {
      return FilteredPositionUpdate(
        distanceDeltaKm: 0.0,
        instantaneousSpeedKmh: _lastValidSpeedKmh,
        isStationary: false,
        isAnomalousJumpDiscarded: true,
        currentPosition: _lastValidPosition!,
      );
    }

    // Filter C: Stationary Jitter / Dead Zone Filter (ZUPT: Zero Velocity Update)
    // When speed is 0 (or below human crawl threshold 1.0 km/h) and movement is within jitter radius,
    // clamp to stationary and discard any accumulated drift.
    final sensorSpeedKmh = newFix.speed > 0.3 ? (newFix.speed * 3.6) : 0.0;
    final isStationary = sensorSpeedKmh == 0.0 ||
        (sensorSpeedKmh < 2.0 && rawMeters < minMovementThresholdMeters);

    if (isStationary) {
      _stationarySince ??= now;
      _lastTimestamp = now;
      _lastValidSpeedKmh = 0.0;
      return FilteredPositionUpdate(
        distanceDeltaKm: 0.0,
        instantaneousSpeedKmh: 0.0,
        isStationary: true,
        isAnomalousJumpDiscarded: false,
        currentPosition: _lastValidPosition!,
      );
    }

    // Apply 1D Spatial Kalman Filter to suppress multipath noise on accepted fixes
    final (filteredLat, filteredLon) = _geodesic.filterPosition(
      lat: newFix.latitude,
      lon: newFix.longitude,
      accuracyMeters: newFix.accuracy,
      timeDeltaMilliseconds: kalmanDtMs,
    );

    final filteredMeters = Wgs84GeodesicEngine.calculateDistanceMeters(
      lat1: _lastValidPosition!.latitude,
      lon1: _lastValidPosition!.longitude,
      lat2: filteredLat,
      lon2: filteredLon,
    );

    final smoothedFix = Position(
      longitude: filteredLon,
      latitude: filteredLat,
      timestamp: newFix.timestamp,
      accuracy: newFix.accuracy,
      altitude: newFix.altitude,
      altitudeAccuracy: newFix.altitudeAccuracy,
      heading: newFix.heading,
      headingAccuracy: newFix.headingAccuracy,
      speed: newFix.speed,
      speedAccuracy: newFix.speedAccuracy,
      floor: newFix.floor,
      isMocked: newFix.isMocked,
    );

    // Vehicle has transitioned from stationary to moving.
    _stationarySince = null;
    _lastValidPosition = smoothedFix;
    _lastTimestamp = now;
    _lastKalmanTimestamp = now;
    _lastValidSpeedKmh =
        sensorSpeedKmh > 0 ? sensorSpeedKmh : calculatedSpeedKmh;

    final acceptedDistanceKm = filteredMeters / 1000.0;

    return FilteredPositionUpdate(
      distanceDeltaKm: acceptedDistanceKm,
      instantaneousSpeedKmh: _lastValidSpeedKmh,
      isStationary: false,
      isAnomalousJumpDiscarded: false,
      currentPosition: smoothedFix,
    );
  }
}
