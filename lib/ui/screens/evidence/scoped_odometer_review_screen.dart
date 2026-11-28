import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/tracking/odometer_gap_reconciler.dart';
import '../../../state/app_state.dart';
import '../logbook/logbook_trip_entry_screen.dart';
import '../logbook/widgets/gap_bridge_sheet.dart';

class ScopedOdometerReviewScreen extends StatefulWidget {
  final AppState appState;
  final String vehicleId;
  final String financialYear;

  const ScopedOdometerReviewScreen({
    super.key,
    required this.appState,
    required this.vehicleId,
    required this.financialYear,
  });

  @override
  State<ScopedOdometerReviewScreen> createState() =>
      _ScopedOdometerReviewScreenState();
}

class _ScopedOdometerReviewScreenState
    extends State<ScopedOdometerReviewScreen> {
  final _reading = TextEditingController();
  String? _error;

  Vehicle? get _vehicle => widget.appState.vehicles
      .where((vehicle) => vehicle.id == widget.vehicleId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    final reading = _vehicle?.initialOdometer ?? 0;
    _reading.text = reading > 0 ? reading.toString() : '';
  }

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_reading.text.replaceAll(',', '').trim());
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _error = 'Enter a positive odometer reading.');
      return;
    }
    final (valid, error) = widget.appState
        .validateStartingOdometer(value, vehicleId: widget.vehicleId);
    if (!valid ||
        !widget.appState
            .updateStartingOdometer(value, vehicleId: widget.vehicleId)) {
      setState(() => _error = error ?? 'Could not save this reading.');
      return;
    }
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting odometer saved.')));
  }

  Future<void> _reviewGap(OdometerGap gap) async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GapBridgeSheet(gap: gap),
    );
    if (!mounted || proceed != true) return;
    if (!widget.appState.isUnrecordedOdometerSpan(
      vehicleId: widget.vehicleId,
      startOdo: gap.startOdo,
      endOdo: gap.endOdo,
      legacyTripId: gap.legacyTripId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This gap has changed. Review the current readings.')));
      return;
    }
    final legacy = widget.appState.trips
        .where((trip) => trip.id == gap.legacyTripId && !trip.isDeleted)
        .firstOrNull;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LogbookTripEntryScreen(
        appState: widget.appState,
        vehicleId: widget.vehicleId,
        odometerGap: gap,
        detectedTrip: legacy,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final vehicle = _vehicle;
          final gaps = widget.appState.odometerGapsForVehicle(widget.vehicleId);
          return Scaffold(
            appBar: AppBar(title: const Text('Review odometer')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(vehicle?.displayName ?? 'Vehicle unavailable',
                    style: AppType.titleSmall),
                Text('Opened from FY ${widget.financialYear}',
                    style: AppType.secondary),
                const SizedBox(height: 12),
                const Text(
                    'Starting readings and odometer continuity apply to this vehicle across your records.'),
                if (vehicle != null) ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reading,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Starting odometer (km)',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save starting odometer'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                      gaps.isEmpty
                          ? 'No unexplained odometer gaps'
                          : 'Missing travel',
                      style: AppType.section),
                  for (final gap in gaps)
                    Card(
                      child: ListTile(
                        title: Text(
                            '${Formatters.odometer(gap.startOdo)} → ${Formatters.odometer(gap.endOdo)} km'),
                        subtitle: Text(
                            '${Formatters.distance(gap.distance)} needs review'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _reviewGap(gap),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      );
}
