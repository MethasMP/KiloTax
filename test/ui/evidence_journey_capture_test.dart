import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/dashboard/task_home_body.dart';
import 'package:kiloclaim/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CaptureState { empty, mixed, checking, failed, resolved }

class CaptureFiles extends EvidenceReviewService {
  final CaptureState scenario;
  CaptureFiles(this.scenario);

  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
      List<VehicleExpense> expenses) {
    if (scenario == CaptureState.checking) {
      return Completer<Map<String, ReceiptFileInspection>>().future;
    }
    if (scenario == CaptureState.failed) {
      return Future.error(StateError('Fixture inspection failure'));
    }
    return Future.value({
      for (final expense in expenses)
        expense.id:
            const ReceiptFileInspection(status: ReceiptFileStatus.available),
    });
  }
}

class CaptureAppState extends AppState {
  @override
  void prewarmAuthConnection() {}
}

Future<AppState> fixture(CaptureState scenario) async {
  final state = CaptureAppState();
  await state.addVehicle(Vehicle(
      id: 'evidence-car',
      make: 'Toyota',
      model: 'HiLux',
      initialOdometer: 42000,
      logbookStartDate: DateTime.now().subtract(const Duration(days: 12)),
      taxMethod: TaxMethod.logbook));
  if (scenario == CaptureState.empty) return state;
  final resolved = scenario == CaptureState.resolved;
  final today = DateTime.now();
  state.recordTrip(Trip(
      id: 'smith-trip',
      vehicleId: 'evidence-car',
      date: today,
      classification: TripClassification.business,
      distanceKm: 18.4,
      startOdometer: 42000,
      endOdometer: 42018.4,
      originAddress: 'Bunnings Alexandria',
      destinationAddress: '42 Smith St, Bondi',
      jobReference: 'Smith renovation',
      purpose: resolved ? 'Deliver timber to Smith renovation' : 'Business'));
  state.recordExpense(VehicleExpense(
      id: 'timber-receipt',
      vehicleId: 'evidence-car',
      date: today,
      amount: 184.60,
      category: ExpenseCategory.toolsMaterials,
      linkedTripId: 'smith-trip',
      notes: 'Bunnings Alexandria',
      receiptPath: '/fixture/timber.jpg',
      receiptAudit: ReceiptAuditTrail(
          capturedAt: today,
          reviewStatus: resolved
              ? ReceiptReviewStatus.confirmed
              : ReceiptReviewStatus.needsReview)));
  state.recordExpense(VehicleExpense(
      id: 'fuel-receipt',
      vehicleId: 'evidence-car',
      date: today,
      amount: 96.35,
      category: ExpenseCategory.fuel,
      notes: 'Ampol Alexandria',
      receiptPath: '/fixture/fuel.jpg',
      receiptAudit: ReceiptAuditTrail(
          capturedAt: today, reviewStatus: ReceiptReviewStatus.confirmed)));
  return state;
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

  for (final screen in ['home', 'review', 'pack']) {
    for (final scenario in CaptureState.values) {
      for (final compact in [false, true]) {
        final name = '${screen}_${scenario.name}${compact ? '_text2' : ''}';
        testWidgets('Evidence journey $name', (tester) async {
          tester.view.physicalSize =
              compact ? const Size(320, 568) : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final state = await fixture(scenario);
          addTearDown(state.dispose);
          final service = CaptureFiles(scenario);
          final body = switch (screen) {
            'home' => TaskHomeBody(appState: state, evidenceService: service),
            'review' => EvidenceReviewScreen(
                appState: state,
                vehicleId: 'evidence-car',
                financialYear: state.activeTaxRule.financialYear,
                evidenceService: service),
            _ => TaxSummaryScreen(evidenceService: service),
          };
          await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(compact ? 2 : 1),
                  padding: const EdgeInsets.only(top: 32, bottom: 24),
                  viewPadding: const EdgeInsets.only(top: 32, bottom: 24),
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const ValueKey('evidence-capture'),
                child: Scaffold(
                  bottomNavigationBar: ScaffoldBottomNavBar(
                    currentIndex: screen == 'home'
                        ? 0
                        : screen == 'review'
                            ? 1
                            : 3,
                    taxMethod: TaxMethod.logbook,
                    onTabSelected: (_) {},
                    onCenterActionTap: () {},
                  ),
                  body: screen == 'home' ? SafeArea(child: body) : body,
                ),
              ),
            ),
          ));
          if (scenario == CaptureState.checking) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          } else {
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: name);
          await expectLater(
              find.byKey(const ValueKey('evidence-capture')),
              matchesGoldenFile(
                  '../../tool/design_audit/evidence_journey_captures/after/$name.png'));
          for (var i = 0; i < 3; i++) {
            final lists = find.byType(Scrollable);
            if (lists.evaluate().isEmpty) break;
            await tester.drag(lists.first, const Offset(0, -450));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: '$name scroll $i');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    }
  }
}
