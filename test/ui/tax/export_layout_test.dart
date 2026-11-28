import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';

class _State extends AppState {
  @override
  void prewarmAuthConnection() {}
}

class _Files extends EvidenceReviewService {
  final bool fail;
  const _Files({this.fail = false});
  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
      List<VehicleExpense> expenses) async {
    if (fail) throw StateError('Test file inspection failure');
    return {};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await inter.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(rootBundle
              .load('packages/lucide_icons_flutter/assets/lucide.ttf')))
        .load();
  });

  for (final scenario in [
    (
      name: 'empty',
      size: const Size(390, 844),
      scale: 1.0,
      records: false,
      cpk: false,
      missingVehicle: false,
      fail: false
    ),
    (
      name: 'ready',
      size: const Size(390, 844),
      scale: 1.0,
      records: true,
      cpk: true,
      missingVehicle: false,
      fail: false
    ),
    (
      name: 'needs_review',
      size: const Size(390, 844),
      scale: 1.0,
      records: true,
      cpk: false,
      missingVehicle: false,
      fail: false
    ),
    (
      name: 'compact_text2',
      size: const Size(320, 568),
      scale: 2.0,
      records: true,
      cpk: true,
      missingVehicle: false,
      fail: false
    ),
    (
      name: 'landscape_text2',
      size: const Size(844, 390),
      scale: 2.0,
      records: false,
      cpk: true,
      missingVehicle: false,
      fail: false
    ),
    (
      name: 'no_vehicle',
      size: const Size(390, 844),
      scale: 1.0,
      records: false,
      cpk: true,
      missingVehicle: true,
      fail: false
    ),
    (
      name: 'check_failed',
      size: const Size(390, 844),
      scale: 1.0,
      records: true,
      cpk: true,
      missingVehicle: false,
      fail: true
    ),
  ]) {
    testWidgets('Export layout ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = _State();
      addTearDown(state.dispose);
      final method = scenario.cpk ? TaxMethod.centsPerKm : TaxMethod.logbook;
      if (!scenario.missingVehicle) {
        await state.addVehicle(Vehicle(
            id: 'report-car',
            make: 'Toyota',
            model: 'HiAce',
            taxMethod: method,
            initialOdometer: 1000));
      }
      if (scenario.records) {
        state.recordTrip(Trip(
            id: 'work-trip',
            vehicleId: 'report-car',
            date: DateTime.now(),
            distanceKm: 24.6,
            startOdometer: 1000,
            endOdometer: 1024.6,
            classification: TripClassification.business,
            purpose: 'Deliver materials to customer site'));
        if (!scenario.cpk) {
          state.recordExpense(VehicleExpense(
              id: 'fuel',
              vehicleId: 'report-car',
              date: DateTime.now(),
              amount: 86.4,
              category: ExpenseCategory.fuel));
        }
      }
      final pending = Completer<void>();
      var exports = 0;
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scenario.scale),
              padding: const EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('export-capture'),
            child: Scaffold(
              bottomNavigationBar: ScaffoldBottomNavBar(
                  currentIndex: scenario.cpk ? 2 : 3,
                  taxMethod: method,
                  onTabSelected: (_) {},
                  onCenterActionTap: () {}),
              body: TaxSummaryScreen(
                  evidenceService: _Files(fail: scenario.fail),
                  onSend: (_, __) {
                    exports++;
                    return pending.future;
                  }),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('verified ATO'), findsNothing);
      expect(find.text('ACCOUNTANT READY'), findsNothing);
      final primary = find.byKey(const ValueKey('tax-primary-action'));
      final bounds = tester.getRect(primary);
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(scenario.size.height));
      await expectLater(find.byKey(const ValueKey('export-capture')),
          matchesGoldenFile('../../goldens/export/${scenario.name}.png'));
      if (!scenario.records) {
        expect(find.text('Estimated deduction'), findsNothing);
        expect(find.text('Prepare pack'), findsOneWidget);
        expect(tester.widget<FilledButton>(primary).onPressed, isNull);
        expect(find.text('Add your first trip'), findsNothing);
      } else {
        expect(find.text('Prepare pack'), findsOneWidget);
        await tester.tap(primary);
        await tester.pump();
        expect(exports, 1);
        expect(tester.widget<FilledButton>(primary).onPressed, isNull);
        await tester.tap(primary);
        expect(exports, 1);
        pending.complete();
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(primary).onPressed, isNotNull);
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.getRect(primary), bounds,
          reason: 'Primary action remains fixed while content scrolls');
      expect(tester.takeException(), isNull);
    });
  }
}
