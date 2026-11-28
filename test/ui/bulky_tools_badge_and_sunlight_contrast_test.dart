import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kiloclaim/ui/screens/expenses/widgets/receipt_processing_view.dart';
import 'package:kiloclaim/ui/screens/trips/trip_detail_screen.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/bulky_tools_badge.dart';

void main() {
  group('Sunlight Readability & Button Touch Target Standards', () {
    test('AppColor.inkSubtle meets WCAG AA sunlight readability contrast', () {
      final c = AppColor.inkSubtle;
      final r = (c.toARGB32() >> 16) & 0xFF;
      final g = (c.toARGB32() >> 8) & 0xFF;
      final b = c.toARGB32() & 0xFF;
      double lum(int val) {
        final s = val / 255.0;
        return s <= 0.03928
            ? s / 12.92
            : ((s + 0.055) / 1.055) * ((s + 0.055) / 1.055);
      }

      final lText = 0.2126 * lum(r) + 0.7152 * lum(g) + 0.0722 * lum(b);
      final lWhite = 1.0;
      final ratio = (lWhite + 0.05) / (lText + 0.05);

      // Must exceed 4.5:1 WCAG AA minimum for sunlight readability
      expect(ratio, greaterThan(4.5));
    });

    test('AppTheme enforces 48x48dp minimum touch targets across button themes',
        () {
      final theme = AppTheme.light;
      expect(theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
          greaterThanOrEqualTo(48.0));
      expect(theme.filledButtonTheme.style?.minimumSize?.resolve({})?.width,
          greaterThanOrEqualTo(48.0));

      expect(theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.height,
          greaterThanOrEqualTo(48.0));
      expect(theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.width,
          greaterThanOrEqualTo(48.0));

      expect(theme.textButtonTheme.style?.minimumSize?.resolve({})?.height,
          greaterThanOrEqualTo(48.0));
      expect(theme.textButtonTheme.style?.minimumSize?.resolve({})?.width,
          greaterThanOrEqualTo(48.0));

      expect(theme.elevatedButtonTheme.style?.minimumSize?.resolve({})?.height,
          greaterThanOrEqualTo(48.0));
      expect(theme.elevatedButtonTheme.style?.minimumSize?.resolve({})?.width,
          greaterThanOrEqualTo(48.0));

      expect(theme.iconButtonTheme.style?.minimumSize?.resolve({})?.height,
          greaterThanOrEqualTo(48.0));
      expect(theme.iconButtonTheme.style?.minimumSize?.resolve({})?.width,
          greaterThanOrEqualTo(48.0));
    });
  });

  group('Bulky Tools ATO s 8-1 Badge & Explanation', () {
    testWidgets(
        'BulkyToolsBadge renders compact label and meets 48x48dp touch target',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsBadge(compact: true),
            ),
          ),
        ),
      );

      expect(find.text('ATO s 8-1 · Bulky Tools'), findsOneWidget);
      final size = tester.getSize(find.byType(BulkyToolsBadge));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Tapping BulkyToolsBadge opens ATO s 8-1 explanation modal',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsBadge(compact: false),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BulkyToolsBadge));
      await tester.pumpAndSettle();

      expect(find.text('ATO Section 8-1 Exemption'), findsOneWidget);
      expect(find.textContaining('ITAA 1997 s 8-1'), findsWidgets);
      expect(find.textContaining('Why This Commute Is 100% Tax Deductible'),
          findsOneWidget);
      expect(find.textContaining('Heavy / Bulky Gear (>20kg)'), findsOneWidget);
      expect(find.textContaining('No Secure On-Site Storage'), findsOneWidget);
    });

    testWidgets(
        'TripDetailScreen renders enhanced Bulky Tools s 8-1 badge and confirmation',
        (tester) async {
      final trip = Trip(
        id: 'trip-bulky-1',
        vehicleId: 'veh-1',
        date: DateTime(2026, 3, 15, 7, 30),
        startOdometer: 50000,
        endOdometer: 50025,
        originAddress: '14 Home St, Richmond',
        destinationAddress: '88 Construction Rd, Clayton',
        purpose: 'Work Site (Bulky Tools Carried)',
        classification: TripClassification.business,
      );

      final state = AppState();
      await state.addVehicle(
        Vehicle(
          id: 'veh-1',
          make: 'Toyota',
          model: 'Hilux',
          regoPlate: 'TRD-123',
          initialOdometer: 45000,
        ),
      );
      state.recordTrip(trip);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TripDetailScreen(trip: trip, appState: state),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Heavy Tools & Gear (>20kg)'), findsOneWidget);
      expect(find.text('ATO s 8-1 · Bulky Tools'), findsOneWidget);
      expect(find.text('ATO Audit Trail Confirmed (s 8-1 & TR 2021/1)'),
          findsOneWidget);
      expect(
          find.textContaining('Tools >20kg carried essential for trade duties'),
          findsOneWidget);
      expect(find.textContaining('Vogt\'s Case'), findsOneWidget);
    });
  });

  group('Low-confidence (<70%) Receipt OCR Highlight', () {
    testWidgets(
        'ReceiptProcessingView displays low-confidence alert when confidence < 70%',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceiptProcessingView(
              status: 'Scanning receipt…',
              confidence: 0.58,
            ),
          ),
        ),
      );

      expect(
          find.byKey(
              const ValueKey('receipt-processing-low-confidence-banner')),
          findsOneWidget);
      expect(find.textContaining('Low OCR Confidence (<70%) (58%)'),
          findsOneWidget);
      expect(find.textContaining('Faded thermal ink or glare detected'),
          findsOneWidget);
    });

    testWidgets(
        'ExpenseDetailScreen displays amber warning card for low-confidence OCR',
        (tester) async {
      final lowConfOcr = ReceiptOcrResult(
        merchant: 'Bunnings Warehouse',
        amount: 89.50,
        dateNeedsReview: false,
        confidence: 0.62,
        evidence: const ['Bunnings', 'Total: 89.50'],
        rawText: 'Bunnings Warehouse Total 89.50',
        currency: 'AUD',
        category: ExpenseCategory.toolsMaterials,
        date: DateTime(2026, 3, 10),
      );

      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ExpenseDetailScreen(
            appState: state,
            receiptOcrResult: lowConfOcr,
            merchant: 'Bunnings Warehouse',
            amount: 89.50,
            categoryName: 'Tools & Equipment',
            receiptDate: DateTime(2026, 3, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('receipt-review-guidance-low-confidence')),
          findsOneWidget);
      expect(find.text('Low OCR Confidence (62%)'), findsOneWidget);
      expect(
          find.textContaining(
              'Faded ink, crumpled thermal paper, or glare was detected'),
          findsOneWidget);
    });
  });
}
