// Read-only product audit: synthetic records, real widgets, isolated render outputs.
// Layout failures are recorded in JSON, not treated as successful product checks.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/core/theme/app_typography.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/accountant_handoff_service.dart';
import 'package:kiloclaim/services/notifications/notification_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/auth/sign_in_screen.dart';
import 'package:kiloclaim/ui/screens/compliance/compliance_center_screen.dart';
import 'package:kiloclaim/ui/screens/cpk/cpk_trip_entry_screen.dart';
import 'package:kiloclaim/ui/screens/dashboard/widgets/account_settings_sheet.dart';
import 'package:kiloclaim/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kiloclaim/ui/screens/expenses/evidence_expenses_screen.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kiloclaim/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:kiloclaim/ui/screens/feedback/feedback_screen.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/quick_capture_bottom_sheet.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_progress_screen.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_setup_screen.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_trip_entry_screen.dart';
import 'package:kiloclaim/ui/screens/notifications/notifications_sheet.dart';
import 'package:kiloclaim/ui/screens/notifications/notifications_dropdown.dart';
import 'package:kiloclaim/ui/screens/onboarding/onboarding_flow_screen.dart';
import 'package:kiloclaim/ui/screens/tax/pre_flight_review_screen.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:kiloclaim/ui/screens/trips/trip_detail_screen.dart';
import 'package:kiloclaim/ui/screens/vehicle/vehicle_setup_flow.dart';

const output = '.audit/menu-remediation-2026-11-08/after-evidence';

class AuditState extends AppState {
  @override
  void prewarmAuthConnection() {}
}

Future<AppState> seed(TaxMethod method, {bool empty = false}) async {
  final state = AuditState();
  await state.addVehicle(Vehicle(
      id: 'audit',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'DEMO',
      initialOdometer: 42000,
      taxMethod: method));
  if (empty) return state;
  final now = DateTime.now();
  state.recordTrip(Trip(
      id: 'work',
      vehicleId: 'audit',
      date: now,
      distanceKm: 18.4,
      purpose: 'Deliver timber to Smith renovation',
      classification: TripClassification.business,
      startOdometer: 42000,
      endOdometer: 42018.4,
      originAddress: 'Bunnings Trade, Alexandria NSW',
      destinationAddress: 'Smith renovation, Bondi NSW'));
  state.recordTrip(Trip(
      id: 'pending',
      vehicleId: 'audit',
      date: now,
      distanceKm: 9.8,
      purpose: '',
      classification: TripClassification.unclassified,
      startOdometer: 42018.4,
      endOdometer: 42028.2));
  state.recordTrip(Trip(
      id: 'personal',
      vehicleId: 'audit',
      date: now,
      distanceKm: 4.2,
      purpose: 'Grocery shopping',
      classification: TripClassification.personal,
      startOdometer: 42028.2,
      endOdometer: 42032.4));
  state.recordExpense(VehicleExpense(
      id: 'parking',
      vehicleId: 'audit',
      date: now,
      amount: 24.5,
      category: ExpenseCategory.tollsParking,
      notes: 'Wilson Parking'));
  state.recordExpense(VehicleExpense(
      id: 'fuel',
      vehicleId: 'audit',
      date: now,
      amount: 96.35,
      category: ExpenseCategory.fuel,
      notes: 'Ampol Alexandria'));
  return state;
}

AccountantHandoffPackage package(AppState s, {String directory = output}) =>
    AccountantHandoffPackage(
        vehicle: s.primaryVehicle!,
        financialYear: s.activeTaxRule.financialYear,
        taxMethod: s.primaryVehicle!.taxMethod,
        pdfFile: File('$directory/fixture-Tax_Report.pdf'),
        dataFile: File('$directory/fixture-Trip_Ledger.csv'),
        claimAmount: s.taxSummary.centsPerKmClaim,
        businessPercentage: 56.8,
        totalTrips: 3,
        totalExpenses: 2,
        verifiedReceiptsCount: 0,
        unverifiedReceiptsCount: 2,
        unspecifiedTripsCount: 1,
        reviewIssues: [
          '1 trip needs a business purpose',
          '2 expenses need receipt review'
        ]);

Widget sheet(void Function(BuildContext) open) => Builder(
    builder: (context) => Scaffold(
        body: Center(
            child: TextButton(
                onPressed: () => open(context),
                child: const Text('Open audit surface')))));

Widget screen(String name, AppState s) => switch (name) {
      'navigation_cpk' ||
      'navigation_logbook' ||
      'navigation_trips_cpk' ||
      'navigation_trips_logbook' =>
        const MainScaffoldScreen(),
      'trips_cpk' ||
      'trips_logbook' ||
      'trips_empty' =>
        TripsLedgerTab(appState: s),
      'trip_detail' => TripDetailScreen(trip: s.trips.first, appState: s),
      'expenses' || 'expenses_empty' => const EvidenceExpensesScreen(),
      'expense_detail' => ExpenseDetailScreen(
          appState: s,
          receiptDate: s.expenses.first.date,
          existingExpense: s.expenses.first,
          merchant: 'Wilson Parking',
          amount: 24.5,
          categoryName: 'Tolls & Parking'),
      'scan_receipt' => ScanReceiptScreen(appState: s),
      'tax_cpk' || 'tax_logbook' || 'tax_empty' => const TaxSummaryScreen(),
      'preflight' =>
        PreFlightReviewScreen(appState: s, initialPackage: package(s)),
      'review' => EvidenceReviewScreen(
          appState: s,
          vehicleId: s.primaryVehicle!.id,
          financialYear: s.activeTaxRule.financialYear),
      'compliance' => ComplianceCenterScreen(appState: s),
      'logbook_setup' => LogbookSetupScreen(appState: s),
      'logbook_progress' => const LogbookProgressScreen(),
      'entry_cpk' => CpkTripEntryScreen(appState: s),
      'entry_logbook' => LogbookTripEntryScreen(appState: s),
      'settings' => sheet((context) => AccountSettingsSheet.show(context, s)),
      'quick_capture_cpk' ||
      'quick_capture_logbook' =>
        sheet((context) => QuickCaptureBottomSheet.show(context, s)),
      'notifications_dropdown' => sheet((context) => NotificationsDropdown.show(
          context,
          notificationService: NotificationService.withPrefs(null))),
      'notifications' => sheet((context) => NotificationsSheet.show(context,
          notificationService: NotificationService.withPrefs(null))),
      'feedback' => const FeedbackScreen(),
      'sign_in' => const SignInScreen(),
      'vehicle' => VehicleSetupFlow(onVehicleCreated: (_) {}),
      'onboarding' => const OnboardingFlowScreen(),
      'onboarding_gps' => const OnboardingFlowScreen(initialStep: 2),
      'onboarding_account' => const OnboardingFlowScreen(initialStep: 3),
      _ => throw StateError(name),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Inter': [
        'assets/fonts/Inter-Regular.ttf',
        'assets/fonts/Inter-Medium.ttf',
        'assets/fonts/Inter-SemiBold.ttf',
        'assets/fonts/Inter-Bold.ttf',
        'assets/fonts/Inter-ExtraBold.ttf',
        'assets/fonts/Inter-Black.ttf'
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
      'packages/lucide_icons_flutter/Lucide': [
        'packages/lucide_icons_flutter/assets/lucide.ttf'
      ],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
    Directory(output).createSync(recursive: true);
    File('$output/fixture-Tax_Report.pdf')
        .writeAsStringSync('%PDF-1.4\n% Synthetic visual fixture only');
    File('$output/fixture-Trip_Ledger.csv')
        .writeAsStringSync('Date,Distance\n2026-11-08,18.4');
  });
  for (final profile in [('normal', 390.0, 1.0), ('large', 320.0, 2.0)]) {
    for (final name in [
      'navigation_cpk',
      'navigation_logbook',
      'navigation_trips_cpk',
      'navigation_trips_logbook',
      'trips_cpk',
      'trips_logbook',
      'trips_empty',
      'trip_detail',
      'expenses',
      'expenses_empty',
      'expense_detail',
      'scan_receipt',
      'tax_cpk',
      'tax_logbook',
      'tax_empty',
      'preflight',
      'review',
      'compliance',
      'logbook_setup',
      'logbook_progress',
      'entry_cpk',
      'entry_logbook',
      'settings',
      'quick_capture_cpk',
      'quick_capture_logbook',
      'notifications',
      'notifications_dropdown',
      'feedback',
      'sign_in',
      'vehicle',
      'onboarding',
      'onboarding_gps',
      'onboarding_account'
    ]) {
      if (Platform.environment['AUDIT_SCREENS'] != null &&
          !Platform.environment['AUDIT_SCREENS']!.split(',').contains(name)) {
        continue;
      }
      testWidgets('capture $name ${profile.$1}', (tester) async {
        // Audit-only fixture under tool/, not a product preferences operation.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        final method = name.contains('logbook') ||
                [
                  'expenses',
                  'expenses_empty',
                  'expense_detail',
                  'scan_receipt',
                  'logbook_setup',
                  'logbook_progress'
                ].contains(name)
            ? TaxMethod.logbook
            : TaxMethod.centsPerKm;
        final s = await seed(method,
            empty: name.contains('empty') ||
                ['onboarding', 'vehicle', 'sign_in'].contains(name));
        tester.view.physicalSize = Size(profile.$2 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
        tester.view.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
        addTearDown(tester.view.reset);
        final errors = <String>[];
        final previousErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.toString());
        addTearDown(() => FlutterError.onError = previousErrorHandler);
        void drain() {
          Object? e;
          while ((e = tester.takeException()) != null) {
            errors.add(e.toString());
          }
        }

        final key = GlobalKey();
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
            value: s,
            child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: ThemeData(
                        fontFamily: 'Inter',
                        textTheme: AppType.textTheme,
                        colorScheme: AppColor.scheme,
                        scaffoldBackgroundColor: AppColor.canvas,
                        useMaterial3: true),
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(profile.$3)),
                        child: child!),
                    home: screen(name, s)))));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        drain();
        if (name.startsWith('navigation_trips_')) {
          await tester.tap(find.text('Trips').hitTestable());
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          drain();
        }
        if (find.text('Open audit surface').evaluate().isNotEmpty) {
          await tester.tap(find.text('Open audit surface'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          drain();
        }
        Future<void> save(String suffix) async {
          await tester.pump(const Duration(milliseconds: 50));
          drain();
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('$output/$name-${profile.$1}$suffix.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await save('');
        final texts = <String>[];
        for (final e in find.byType(Text).evaluate()) {
          final w = e.widget as Text;
          final value = w.data ?? w.textSpan?.toPlainText() ?? '';
          if (!texts.contains(value)) texts.add(value);
        }
        final targets = <Map<String, Object>>[];
        for (final e in find
            .byWidgetPredicate((w) =>
                w is InkWell ||
                w is GestureDetector ||
                w is ButtonStyleButton ||
                w is IconButton)
            .evaluate()) {
          final r = e.findRenderObject();
          if (r is RenderBox && r.hasSize) {
            final pos = r.localToGlobal(Offset.zero);
            if (pos.dy >= 0 && pos.dy < 844 && r.size.height > 0) {
              final labels = <String>[];
              void visit(Element child) {
                if (child.widget is Text) {
                  labels.add((child.widget as Text).data ?? '');
                }
                child.visitChildren(visit);
              }

              e.visitChildren(visit);
              targets.add({
                'type': e.widget.runtimeType.toString(),
                'width': r.size.width,
                'height': r.size.height,
                'x': pos.dx,
                'y': pos.dy,
                'labels': labels.join(' | ')
              });
            }
          }
        }
        if (profile.$1 == 'normal') {
          final scrolls = find
              .byType(Scrollable)
              .evaluate()
              .map((e) => (e as StatefulElement).state)
              .whereType<ScrollableState>()
              .where((x) =>
                  x.position.axis == Axis.vertical &&
                  x.position.hasContentDimensions &&
                  x.position.maxScrollExtent > 0)
              .toList();
          if (scrolls.isNotEmpty) {
            scrolls.first.position
                .jumpTo(scrolls.first.position.maxScrollExtent);
            await tester.pump(const Duration(milliseconds: 100));
            drain();
            await save('-bottom');
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
        drain();
        s.dispose();
        await tester.runAsync(() => File('$output/$name-${profile.$1}.json')
                .writeAsString(const JsonEncoder.withIndent('  ').convert({
              'screen': name,
              'width': profile.$2,
              'textScale': profile.$3,
              'errors': errors,
              'texts': texts,
              'targets': targets
            })));
      });
    }
  }
}
