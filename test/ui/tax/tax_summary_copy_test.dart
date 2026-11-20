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

void main() {
  testWidgets('TaxSummaryScreen displays ACCOUNTANT READY badge instead of AUDIT-PROOF',
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

    // Verification: 'ACCOUNTANT READY' must be present, 'AUDIT-PROOF' must be absent
    expect(find.text('ACCOUNTANT READY'), findsOneWidget);
    expect(find.textContaining('AUDIT-PROOF'), findsNothing);
  });
}
