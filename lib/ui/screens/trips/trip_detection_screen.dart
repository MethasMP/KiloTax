import 'package:flutter/material.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../cpk/cpk_trip_entry_screen.dart';
import '../logbook/logbook_trip_entry_screen.dart';

/// Screen 7 Polymorphic Router:
/// Routes to dedicated [CpkTripEntryScreen] or [LogbookTripEntryScreen] based on vehicle tax strategy.
/// Guarantees zero cross-method pollution and clean architecture separation.
class TripDetectionScreen extends StatelessWidget {
  final AppState appState;
  final Trip? detectedTrip;

  const TripDetectionScreen({
    super.key,
    required this.appState,
    this.detectedTrip,
  });

  static Future<void> show(BuildContext context, AppState appState, {Trip? trip}) {
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isLogbook
            ? LogbookTripEntryScreen(appState: appState, detectedTrip: trip)
            : CpkTripEntryScreen(appState: appState, detectedTrip: trip),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;
    return isLogbook
        ? LogbookTripEntryScreen(appState: appState, detectedTrip: detectedTrip)
        : CpkTripEntryScreen(appState: appState, detectedTrip: detectedTrip);
  }
}
