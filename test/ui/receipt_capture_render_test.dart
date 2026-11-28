import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kiloclaim/ui/screens/expenses/widgets/receipt_processing_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/main_menu_fixtures.dart' show AuditState;

void main() {
  setUpAll(() async {
    for (final entry in {
      'Inter': [
        'assets/fonts/Inter-Regular.ttf',
        'assets/fonts/Inter-SemiBold.ttf',
        'assets/fonts/Inter-Bold.ttf'
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
      'packages/lucide_icons_flutter/Lucide': [
        'packages/lucide_icons_flutter/assets/lucide.ttf'
      ],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final output = Platform.environment['DRIVELOG_RECEIPT_CAPTURE'];
    if (output == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'Real receipt preview, processing and editable review render at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final directory = await tester
        .runAsync(() => Directory.systemTemp.createTemp('receipt-render-'));
    addTearDown(() => directory!.delete(recursive: true));
    final path = '${directory!.path}/sample.png';
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, 400, 620), Paint()..color = Colors.white);
      final paragraph = (ui.ParagraphBuilder(
              ui.ParagraphStyle(fontFamily: 'Inter', fontSize: 22, height: 1.6))
            ..pushStyle(ui.TextStyle(color: Colors.black))
            ..addText(
                'SAMPLE RECEIPT\n\nWORKSHOP SUPPLIES\n15/11/2026\n\nMotor oil       38.00\nWorkshop items   4.00\n\nTOTAL       AUD 42.00\n\nSample data for UI testing'))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 350));
      canvas.drawParagraph(paragraph, const Offset(25, 30));
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 620);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      paragraph.dispose();
    });
    final key = GlobalKey();
    Widget wrap(Widget screen) => RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: screen));
    await tester.pumpWidget(wrap(const Scaffold()));
    await tester.runAsync(() => precacheImage(
        FileImage(File(path)), tester.element(find.byType(Scaffold))));
    await tester.pumpWidget(wrap(Scaffold(
        appBar: AppBar(title: const Text('Receipt Scanner')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ReceiptProcessingView(
                imagePath: path, status: 'Reading receipt details…')))));
    await tester.pump(const Duration(milliseconds: 500));
    await capture(tester, key, 'receipt-processing');
    if (Platform.environment['DRIVELOG_RECEIPT_CAPTURE'] != null) {
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 150));
        await capture(
            tester, key, 'motion/frame-${frame.toString().padLeft(3, '0')}');
      }
    }
    expect(tester.takeException(), isNull);
    final state = AuditState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'receipt-render',
        make: 'Toyota',
        model: 'HiLux',
        taxMethod: TaxMethod.logbook));
    final ocr = ReceiptOcrResult(
        merchant: 'Workshop Supplies',
        amount: 42,
        date: DateTime(2026, 11, 15),
        category: ExpenseCategory.fuel,
        confidence: .92,
        evidence: const ['total'],
        rawText: 'Workshop Supplies\nTOTAL 42.00',
        currency: 'AUD');
    await tester.pumpWidget(wrap(ExpenseDetailScreen(
        appState: state,
        merchant: ocr.merchant,
        amount: ocr.amount,
        receiptDate: ocr.date,
        receiptOcrResult: ocr,
        receiptImagePath: path)));
    await tester.pumpAndSettle();
    expect(find.text('Review your receipt'), findsOneWidget);
    expect(state.expenses, isEmpty);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'receipt-review');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('expense-merchant')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byKey(const ValueKey('expense-merchant')), 'Edited shop');
    expect(find.text('Edited shop'), findsOneWidget);
    expect(state.expenses, isEmpty);
  });
}
