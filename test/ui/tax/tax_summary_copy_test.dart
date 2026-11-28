import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';

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

void main() {
  testWidgets(
      'TaxSummaryScreen displays Checks complete badge without promising ATO approval',
      (WidgetTester tester) async {
    final state = _MockAppState();
    await state.addVehicle(Vehicle(
      id: 'ute-1',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'TRADIE-1',
      initialOdometer: 10000,
      taxMethod: TaxMethod.centsPerKm,
    ));
    state.recordTrip(Trip(
      id: 'trip-1',
      vehicleId: 'ute-1',
      date: DateTime.now(),
      distanceKm: 45.0,
      classification: TripClassification.business,
      purpose: 'Job site visit',
      startOdometer: 10000,
      endOdometer: 10045,
    ));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: ThemeData(colorScheme: AppColor.scheme),
          home: TaxSummaryScreen(
            evidenceService: const _FastInspection(),
            onSend: (_, __) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verification: 'Checks complete' must be present, 'AUDIT-PROOF' must be absent
    expect(find.text('Checks complete'), findsOneWidget);
    expect(find.textContaining('AUDIT-PROOF'), findsNothing);
  });
}
