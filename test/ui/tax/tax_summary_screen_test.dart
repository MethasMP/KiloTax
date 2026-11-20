import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/core/theme/app_color.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/evidence_review_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/tax/tax_summary_screen.dart';

class _MockAppState extends AppState {
  @override
  void prewarmAuthConnection() {}
}

class _FastInspection extends EvidenceReviewService {
  const _FastInspection();

  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
      List<VehicleExpense> expenses) async {
    return {};
  }
}

Future<AppState> _createStateWithTrip() async {
  final state = _MockAppState();
  await state.addVehicle(Vehicle(
    id: 'test-car',
    make: 'Toyota',
    model: 'HiLux',
    regoPlate: 'UTE-001',
    initialOdometer: 10000,
    taxMethod: TaxMethod.centsPerKm,
  ));
  state.recordTrip(Trip(
    id: 'trip-1',
    vehicleId: 'test-car',
    date: DateTime.now(),
    distanceKm: 25.0,
    classification: TripClassification.business,
    purpose: 'Plumbing materials run',
    startOdometer: 10000,
    endOdometer: 10025,
  ));
  return state;
}

Widget _wrapScreen({
  required AppState state,
  required Future<void> Function(BuildContext, AppState) onSend,
}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: ThemeData(colorScheme: AppColor.scheme),
      home: TaxSummaryScreen(
        evidenceService: const _FastInspection(),
        onSend: onSend,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaxSummaryScreen Export UX (Task B5)', () {
    testWidgets(
        'tap Export; pump 500ms; expect CircularProgressIndicator is in tree before export completes',
        (tester) async {
      final completer = Completer<void>();
      final state = await _createStateWithTrip();

      await tester.pumpWidget(_wrapScreen(
        state: state,
        onSend: (context, appState) async {
          await completer.future;
        },
      ));
      await tester.pumpAndSettle();

      // Before tapping Export: no progress indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tap Export button
      await tester.tap(find.byKey(const ValueKey('tax-primary-action')));
      await tester.pump(const Duration(milliseconds: 500));

      // 500ms after tapping: CircularProgressIndicator must be visible in tree
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the export
      completer.complete();
      await tester.pumpAndSettle();

      // After export completes: progress indicator is gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
