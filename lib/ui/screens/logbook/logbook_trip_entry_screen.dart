import '../../../services/tracking/odometer_gap_reconciler.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_space.dart';
import 'widgets/logbook_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/trip.dart';
import '../../../state/app_state.dart';
import '../trips/widgets/logbook_odometer_card.dart';
import '../trips/widgets/trip_purpose_selector.dart';

/// Dedicated Trip Entry Screen for Logbook Method (TR 97/11)
/// 100% Focused on Gapless Continuous Odometer & Statutory Business/Personal Ratio.
class LogbookTripEntryScreen extends StatefulWidget {
  final AppState appState;
  final Trip? detectedTrip;
  final OdometerGap? odometerGap;

  const LogbookTripEntryScreen({
    super.key,
    required this.appState,
    this.detectedTrip,
    this.odometerGap,
  });

  @override
  State<LogbookTripEntryScreen> createState() => _LogbookTripEntryScreenState();
}

class _LogbookTripEntryScreenState extends State<LogbookTripEntryScreen> {
  String _selectedPurpose = '';
  late DateTime _tripDate;
  bool _dateConfirmed = true;
  late TextEditingController _distanceController;
  late TextEditingController _originController;
  late TextEditingController _destinationController;
  double _currentDistance = 0.0;
  double _customStartOdo = 0.0;

  @override
  void initState() {
    super.initState();
    final detected = widget.detectedTrip;
    final gap = widget.odometerGap;
    _dateConfirmed = gap == null;
    _tripDate = detected?.date ?? DateTime.now();
    _selectedPurpose = detected?.classification == TripClassification.personal
        ? 'Personal'
        : detected?.purpose ?? '';
    if (gap != null) _selectedPurpose = '';
    _currentDistance = gap?.distance ?? widget.detectedTrip?.distanceKm ?? 0.0;
    _distanceController = TextEditingController(
      text: _currentDistance > 0 ? _currentDistance.toStringAsFixed(1) : '',
    );
    _originController = TextEditingController(
      text: widget.detectedTrip?.originAddress ?? '',
    );
    _destinationController = TextEditingController(
      text: widget.detectedTrip?.destinationAddress ?? '',
    );
    _customStartOdo = gap?.startOdo ??
        widget.detectedTrip?.startOdometer ??
        widget.appState.currentOdometer;
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _saveTrip() async {
    if (widget.appState.primaryVehicle == null && widget.detectedTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose a vehicle before adding a trip.')));
      return;
    }
    if (_selectedPurpose.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose a trip purpose before saving.')));
      return;
    }
    if (!_dateConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Choose the actual trip date. The odometer does not tell us when you travelled.')));
      return;
    }
    HapticFeedback.heavyImpact();
    final parsedDist =
        double.tryParse(_distanceController.text.trim()) ?? _currentDistance;
    if (!parsedDist.isFinite || parsedDist <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.crimson,
          content: Text('Please enter a valid trip distance (km).'),
        ),
      );
      return;
    }

    final startOdo = _customStartOdo;
    final endOdo = startOdo + parsedDist;
    final gap = widget.odometerGap;
    if (gap != null &&
        (widget.appState.primaryVehicle?.id != gap.vehicleId ||
            !widget.appState.isUnrecordedOdometerSpan(
                vehicleId: gap.vehicleId,
                startOdo: startOdo,
                endOdo: endOdo,
                legacyTripId: gap.legacyTripId) ||
            (gap.legacyTripId != null &&
                ((startOdo - gap.startOdo).abs() > 0.01 ||
                    (endOdo - gap.endOdo).abs() > 0.01)))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'The trip must fit the current unrecorded span. Return to the odometer record if it has changed.')));
      return;
    }
    bool isPersonal = _selectedPurpose == 'Personal';
    final origin = _originController.text.trim().isNotEmpty
        ? _originController.text.trim()
        : (isPersonal ? '[Private Journey]' : 'Work Site / Depot');
    final dest = _destinationController.text.trim().isNotEmpty
        ? _destinationController.text.trim()
        : (isPersonal ? '[Private Journey]' : 'Client Job Location');

    if (!isPersonal &&
        (_originController.text.trim().isEmpty ||
            _destinationController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Enter the starting place and destination for this business trip.')));
      return;
    }
    // Home-to-Work Compliance Guard (TR 2021/1 & TR 95/34)
    final isBulkyTools = _selectedPurpose == 'Heavy Tools & Equipment' ||
        _selectedPurpose == 'Carrying Heavy Tools' ||
        _selectedPurpose == 'Work Site (Bulky Tools Carried)';
    if (!isPersonal) {
      final (isCompliant, warning) =
          widget.appState.validateHomeToWorkCompliance(
        origin: origin,
        destination: dest,
        purpose: _selectedPurpose,
        isBulkyToolsCarried: isBulkyTools,
      );
      if (!isCompliant && warning != null) {
        final confirmPersonal = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Review travel type'),
                  content: const Text(
                      'This route is flagged by the app’s commute check. Review the route and purpose, or choose to record it as personal travel.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Review details')),
                    FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Save as personal')),
                  ],
                ));
        if (!mounted || confirmPersonal != true) return;
        isPersonal = true;
        _selectedPurpose = 'Personal';
      }
    }

    if (gap != null &&
        !widget.appState.isUnrecordedOdometerSpan(
            vehicleId: gap.vehicleId,
            startOdo: startOdo,
            endOdo: endOdo,
            legacyTripId: gap.legacyTripId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'This gap has changed. Return to the latest odometer record.')));
      return;
    }
    final baseTrip = widget.detectedTrip ??
        Trip(
          id: 'logbook_trip_${DateTime.now().microsecondsSinceEpoch}',
          vehicleId: widget.appState.primaryVehicle!.id,
          date: _tripDate,
          purpose: _selectedPurpose,
          taxMethod: TaxMethod.logbook,
          evidenceSource:
              gap == null ? 'manual_retroactive' : 'manual_gap_resolution',
        );
    final trip = baseTrip.copyWith(
      evidenceSource: gap?.legacyTripId != null
          ? 'user_confirmed_auto_gap'
          : baseTrip.evidenceSource,
      distanceKm: parsedDist,
      date: _tripDate,
      purpose: _selectedPurpose,
      startOdometer: startOdo,
      endOdometer: endOdo,
      classification: isPersonal
          ? TripClassification.personal
          : TripClassification.business,
      originAddress: origin,
      destinationAddress: dest,
    );

    widget.appState.recordTrip(trip);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();

    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
          '${isPersonal ? 'Personal' : 'Business'} trip saved · ${Formatters.date(_tripDate)} · ${parsedDist.toStringAsFixed(1)} km'),
    ));
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
        context: context,
        initialDate: _tripDate,
        firstDate: DateTime(2000),
        lastDate: _tripDate.isAfter(now) ? _tripDate : now);
    if (!mounted || chosen == null) return;
    setState(() {
      _tripDate = DateTime(chosen.year, chosen.month, chosen.day,
          _tripDate.hour, _tripDate.minute);
      _dateConfirmed = true;
    });
  }

  Future<void> _chooseTime() async {
    final chosen = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_tripDate));
    if (!mounted || chosen == null) return;
    setState(() => _tripDate = DateTime(_tripDate.year, _tripDate.month,
        _tripDate.day, chosen.hour, chosen.minute));
  }

  @override
  Widget build(BuildContext context) {
    final endOdo = _customStartOdo + _currentDistance;
    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: logbookAppBar(
          context, widget.detectedTrip == null ? 'Add trip' : 'Review trip'),
      bottomNavigationBar:
          LogbookFooter(label: 'Save trip', onPressed: _saveTrip),
      body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(S.xl),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      widget.odometerGap == null
                          ? 'Trip details'
                          : 'Add confirmed travel',
                      style: AppType.title),
                  const SizedBox(height: S.sm),
                  const Text(
                      'Check the route, distance and purpose for your logbook.',
                      style: AppType.body),
                  const SizedBox(height: S.xxl),
                  if (widget.odometerGap != null) ...[
                    Text(
                        'Unrecorded span: ${Formatters.odometer(widget.odometerGap!.startOdo)}–${Formatters.odometer(widget.odometerGap!.endOdo)} km. Only save travel you can confirm.',
                        style: AppType.secondary),
                    const SizedBox(height: S.lg),
                  ],
                  LogbookPanel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        const Text('WHEN', style: AppType.eyebrow),
                        const SizedBox(height: S.sm),
                        Wrap(spacing: S.sm, runSpacing: S.sm, children: [
                          TextButton.icon(
                              key: const ValueKey('trip-date'),
                              onPressed: _chooseDate,
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColor.ink,
                                  minimumSize: const Size(48, 48)),
                              icon: const Icon(AppIcons.calendar,
                                  size: AppIconSize.control),
                              label: Text(_dateConfirmed
                                  ? Formatters.date(_tripDate)
                                  : 'Choose actual trip date')),
                          TextButton(
                              key: const ValueKey('trip-time'),
                              onPressed: _chooseTime,
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColor.ink,
                                  minimumSize: const Size(48, 48)),
                              child: Text(TimeOfDay.fromDateTime(_tripDate)
                                  .format(context))),
                        ]),
                        const Divider(height: S.xxl, color: AppColor.hairline),
                        const Text('DISTANCE', style: AppType.eyebrow),
                        const SizedBox(height: S.md),
                        TextField(
                            controller: _distanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: AppType.metric
                                .copyWith(fontSize: AppType.title.fontSize),
                            decoration: logbookInput('Trip distance',
                                hint: '0.0', suffix: 'km'),
                            onChanged: (val) => setState(() =>
                                _currentDistance =
                                    double.tryParse(val.trim()) ?? 0.0)),
                        const SizedBox(height: S.xl),
                        TextField(
                            controller: _originController,
                            style: AppType.body,
                            textCapitalization: TextCapitalization.words,
                            decoration: logbookInput('From',
                                hint: 'Starting suburb or depot')),
                        const SizedBox(height: S.md),
                        TextField(
                            controller: _destinationController,
                            style: AppType.body,
                            textCapitalization: TextCapitalization.words,
                            decoration: logbookInput('To',
                                hint: 'Destination suburb or address')),
                      ])),
                  const SizedBox(height: S.xxl),
                  TripPurposeSelector(
                      selectedPurpose: _selectedPurpose,
                      isLogbook: true,
                      onPurposeSelected: (p) =>
                          setState(() => _selectedPurpose = p)),
                  const SizedBox(height: S.xxl),
                  LogbookOdometerCard(
                      appState: widget.appState,
                      startOdometer: _customStartOdo,
                      endOdometer: endOdo,
                      onStartOdometerChanged: (val) =>
                          setState(() => _customStartOdo = val)),
                  const SizedBox(height: S.xxl),
                ]),
          )),
    );
  }
}
