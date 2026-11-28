import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/job_site.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/tracking/road_snap_routing_service.dart';

/// Standalone bottom sheet for 1-Tap OSRM-backed Back-Capture (Axis C).
/// Used when the user's phone died, was left behind, or OS battery saving
/// prevented automatic capture. Explicitly stamps `manual_route_reconstructed`
/// so it never pretends to be live GPS telemetry.
class BackCaptureTripSheet extends StatefulWidget {
  final String vehicleId;
  final TaxMethod taxMethod;
  final UserProfile? userProfile;
  final List<JobSite> jobSites;
  final RoadSnapRoutingService? routingService;
  final ValueChanged<Trip> onSave;
  final double? initialStartOdometer;
  final String? initialPurpose;
  final DateTime? initialDepartureTime;

  const BackCaptureTripSheet({
    super.key,
    required this.vehicleId,
    this.taxMethod = TaxMethod.logbook,
    this.userProfile,
    this.jobSites = const [],
    this.routingService,
    required this.onSave,
    this.initialStartOdometer,
    this.initialPurpose,
    this.initialDepartureTime,
  });

  @override
  State<BackCaptureTripSheet> createState() => _BackCaptureTripSheetState();
}

class _BackCaptureTripSheetState extends State<BackCaptureTripSheet> {
  static const String backCaptureEvidenceSource = 'manual_route_reconstructed';

  late final TextEditingController _originController;
  late final TextEditingController _destController;
  late final TextEditingController _purposeController;
  late final TextEditingController _startOdoController;

  double? _startLat;
  double? _startLng;
  double? _endLat;
  double? _endLng;
  late DateTime _departureTime;

  bool _isCalculating = false;
  RoadRouteResult? _routeResult;
  String? _errorText;

  RoadSnapRoutingService get _routing =>
      widget.routingService ?? RoadSnapRoutingService();

  @override
  void initState() {
    super.initState();
    _departureTime = widget.initialDepartureTime ?? DateTime.now();
    _originController = TextEditingController(
      text: widget.userProfile?.homeAddress ?? '',
    );
    _destController = TextEditingController();
    _purposeController = TextEditingController(
      text: widget.initialPurpose ?? 'Client Site',
    );
    _startOdoController = TextEditingController(
      text: widget.initialStartOdometer != null &&
              widget.initialStartOdometer! > 0
          ? widget.initialStartOdometer!.toStringAsFixed(1)
          : '',
    );

    if (widget.userProfile?.hasHomeCoordinates == true) {
      _startLat = widget.userProfile!.homeLatitude;
      _startLng = widget.userProfile!.homeLongitude;
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _purposeController.dispose();
    _startOdoController.dispose();
    super.dispose();
  }

  Future<void> _calculateRoute() async {
    if (_startLat == null ||
        _startLng == null ||
        _endLat == null ||
        _endLng == null) {
      setState(() {
        _errorText =
            'Select both a start and destination location (Home or Job Site) to calculate route distance.';
      });
      return;
    }

    setState(() {
      _isCalculating = true;
      _errorText = null;
    });

    final result = await _routing.calculateRoadDistanceKm(
      startLat: _startLat!,
      startLon: _startLng!,
      endLat: _endLat!,
      endLon: _endLng!,
    );

    if (!mounted) return;
    setState(() {
      _isCalculating = false;
      _routeResult = result;
    });
  }

  void _saveTrip() {
    final route = _routeResult;
    if (route == null) return;

    final startOdo = double.tryParse(_startOdoController.text.trim()) ?? 0.0;
    final endOdo = startOdo > 0
        ? double.parse((startOdo + route.roadDistanceKm).toStringAsFixed(2))
        : 0.0;

    final trip = Trip(
      id: 'backcap_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicleId,
      distanceKm: route.roadDistanceKm,
      date: _departureTime,
      purpose: _purposeController.text.trim().isEmpty
          ? 'Reconstructed Business Drive'
          : _purposeController.text.trim(),
      startOdometer: startOdo,
      endOdometer: endOdo,
      classification: TripClassification.business,
      originAddress: _originController.text.trim().isEmpty
          ? null
          : _originController.text.trim(),
      destinationAddress: _destController.text.trim().isEmpty
          ? null
          : _destController.text.trim(),
      taxMethod: widget.taxMethod,
      evidenceSource: backCaptureEvidenceSource,
      routePolyline: route.geometryPolyline,
      startLat: _startLat,
      startLng: _startLng,
      endLat: _endLat,
      endLng: _endLng,
      stoppedAt: _departureTime.add(
        Duration(seconds: route.durationSeconds.round()),
      ),
      review: {
        'isRoadSnapped': route.isRoadSnapped,
        'straightLineKm': route.straightLineDistanceKm,
        'reconstructedAt': DateTime.now().toIso8601String(),
        'capturedAt': _departureTime.toIso8601String(),
        'purposeConfirmedAt': DateTime.now().toIso8601String(),
      },
    );

    HapticFeedback.mediumImpact();
    widget.onSave(trip);
  }

  @override
  Widget build(BuildContext context) {
    final activeSites = widget.jobSites.where((s) => s.isActive).toList();

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: R.sheetTopR,
        ),
        padding: const EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColor.line,
                    borderRadius: R.chipR,
                  ),
                ),
              ),
              const SizedBox(height: S.lg),
              Row(
                children: [
                  const Icon(
                    AppIcons.trips,
                    color: AppColor.brand,
                    size: AppIconSize.navigation,
                  ),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text('Back-Capture Missed Trip',
                        style: AppType.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close, size: AppIconSize.control),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: S.xs),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
                decoration: BoxDecoration(
                  color: AppColor.attentionTintSoft,
                  borderRadius: R.chipR,
                  border: Border.all(color: AppColor.attentionTintStrong),
                ),
                child: Text(
                  'Stamped as Reconstructed Route (OSRM / Geodesic) — not live GPS.',
                  style: AppType.secondary.copyWith(color: AppColor.attentionInk),
                ),
              ),
              const SizedBox(height: S.lg),
              Text('START LOCATION', style: AppType.eyebrow),
              const SizedBox(height: S.xs),
              TextField(
                controller: _originController,
                decoration: InputDecoration(
                  hintText: 'Start address or depot',
                  border: OutlineInputBorder(borderRadius: R.controlR),
                  isDense: true,
                ),
              ),
              if (widget.userProfile?.hasHomeCoordinates == true ||
                  activeSites.isNotEmpty) ...[
                const SizedBox(height: S.sm),
                Wrap(
                  spacing: S.sm,
                  runSpacing: S.xs,
                  children: [
                    if (widget.userProfile?.hasHomeCoordinates == true)
                      ActionChip(
                        label: const Text('Home Base'),
                        onPressed: () {
                          setState(() {
                            _originController.text =
                                widget.userProfile!.homeAddress ?? 'Home Base';
                            _startLat = widget.userProfile!.homeLatitude;
                            _startLng = widget.userProfile!.homeLongitude;
                          });
                        },
                      ),
                    for (final site in activeSites.take(3))
                      ActionChip(
                        label: Text(site.name),
                        onPressed: () {
                          setState(() {
                            _originController.text = site.name;
                            _startLat = site.latitude;
                            _startLng = site.longitude;
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: S.md),
              Text('DESTINATION', style: AppType.eyebrow),
              const SizedBox(height: S.xs),
              TextField(
                controller: _destController,
                decoration: InputDecoration(
                  hintText: 'Destination address or job site',
                  border: OutlineInputBorder(borderRadius: R.controlR),
                  isDense: true,
                ),
              ),
              if (activeSites.isNotEmpty) ...[
                const SizedBox(height: S.sm),
                Wrap(
                  spacing: S.sm,
                  runSpacing: S.xs,
                  children: [
                    for (final site in activeSites.take(4))
                      ActionChip(
                        label: Text(site.name),
                        onPressed: () {
                          setState(() {
                            _destController.text = site.name;
                            _endLat = site.latitude;
                            _endLng = site.longitude;
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: S.md),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _purposeController,
                      decoration: InputDecoration(
                        labelText: 'ATO Purpose',
                        border: OutlineInputBorder(borderRadius: R.controlR),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: TextField(
                      controller: _startOdoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Start Odo (opt)',
                        border: OutlineInputBorder(borderRadius: R.controlR),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: S.sm),
                Text(
                  _errorText!,
                  style: AppType.secondary.copyWith(color: AppColor.critical),
                ),
              ],
              const SizedBox(height: S.md),
              if (_routeResult != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(S.md),
                  decoration: BoxDecoration(
                    color: AppColor.positiveTint,
                    borderRadius: R.controlR,
                    border: Border.all(color: AppColor.positiveTintStrong),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _routeResult!.isRoadSnapped
                                  ? 'Road-Snapped Route (OSRM)'
                                  : 'Offline Geodesic Estimate',
                              style: AppType.bodyStrong
                                  .copyWith(color: AppColor.positiveInk),
                            ),
                            Text(
                              'Straight-line: ${_routeResult!.straightLineDistanceKm.toStringAsFixed(1)} km',
                              style: AppType.secondary,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_routeResult!.roadDistanceKm.toStringAsFixed(1)} km',
                        style: AppType.metricSmall
                            .copyWith(color: AppColor.positiveStrong),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: S.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCalculating ? null : _calculateRoute,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: S.md),
                        shape: RoundedRectangleBorder(borderRadius: R.controlR),
                      ),
                      child: _isCalculating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Calculate Route'),
                    ),
                  ),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _routeResult == null ? null : _saveTrip,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColor.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: S.md),
                        shape: RoundedRectangleBorder(borderRadius: R.controlR),
                      ),
                      child: const Text('Save Trip'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
