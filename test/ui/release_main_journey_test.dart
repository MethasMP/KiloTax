import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/main.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/services/engine/tax_pack_builder.dart';
import 'package:archive/archive.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';
import 'package:kiloclaim/ui/screens/trips/trip_detail_screen.dart';

void main({bool nativeStorage = false}) {
  testWidgets(
      'fresh guest completes vehicle, trip, correction, expense and restart',
      (tester) async {
    if (nativeStorage) {
      SharedPreferences.setPrefix('kiloclaim_release_smoke.');
    } else {
      SharedPreferences.setMockInitialValues({});
    }
    final storage = await LocalStorageService.init();
    if (nativeStorage) await storage.clearAll();
    final state = AppState(storageService: storage);
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state, child: const KiloClaimApp()));

    Future<void> tap(String text) async {
      expect(find.text(text), findsWidgets, reason: 'Missing action: $text');
      final target = find.text(text).hitTestable();
      await Scrollable.ensureVisible(tester.element(find.text(text).first),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(target.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: "After $text");
    }

    await tap('Get started');
    await tap('Continue without an account');
    await tap('Continue on this device');
    await tap('I’ll log trips manually instead');
    await tap('Ford Ranger');
    await tap('Save & Continue');
    await tap('Logbook Method');
    await tap('Save vehicle');
    expect(find.byType(MainScaffoldScreen), findsOneWidget);
    expect(state.isGuestMode, isTrue);
    expect(state.isAuthenticated, isFalse);
    expect(state.primaryVehicle!.taxMethod, TaxMethod.logbook);

    await tap('Records');
    await tester.tap(find.byTooltip('Add trip').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '12.5');
    await tester.enterText(find.byType(TextField).at(1), 'Parramatta');
    await tester.enterText(find.byType(TextField).at(2), 'Blacktown');
    await tap('Client Site');
    await tap('Save trip');
    final tripId = state.trips.single.id;
    expect(state.trips.single.distanceKm, 12.5);
    expect(state.trips.single.classification, TripClassification.business);

    await tap('Records');
    final capturedRoute = find.textContaining('Blacktown');
    expect(capturedRoute, findsWidgets);
    await tester.ensureVisible(capturedRoute.first);
    await tester.tap(capturedRoute.first);
    await tester.pumpAndSettle();
    expect(find.byType(TripDetailScreen), findsOneWidget);
    await tap('Personal');
    expect(state.trips.single.classification, TripClassification.personal);
    await tap('Edit');
    await tester.enterText(find.byType(TextField).first, 'Visit family');
    await tap('Save');
    expect(state.trips.single.id, tripId);
    expect(state.trips.single.purpose, 'Visit family');
    expect(state.trips.single.classification, TripClassification.personal);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tap('Expenses');
    await tap('Add Expense');
    await tap('Manual Entry');
    await tester.enterText(
        find.byKey(const ValueKey('expense-merchant')), 'Local hardware');
    await tester.enterText(
        find.byKey(const ValueKey('expense-amount')), '55.00');
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save Expense to Vault'), 350,
        scrollable: find.byType(Scrollable).first);
    await tap('Save Expense to Vault');
    expect(state.expenses.single.amount, 55);
    expect(state.expenses.single.receiptPath, isNull,
        reason: 'Manual entry must not manufacture receipt evidence.');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    if (nativeStorage) {
      await (await SharedPreferences.getInstance()).reload();
    }
    final restored = AppState(storageService: storage);
    addTearDown(restored.dispose);
    await restored.init();
    await tester.pumpAndSettle();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: restored, child: const KiloClaimApp()));
    await tester.pumpAndSettle();
    expect(find.byType(MainScaffoldScreen), findsOneWidget);
    expect(restored.isGuestMode, isTrue);
    expect(restored.primaryVehicle!.id, state.primaryVehicle!.id);
    expect(restored.trips.single.id, tripId);
    expect(restored.trips.single.purpose, 'Visit family');
    expect(restored.trips.single.destinationAddress, 'Blacktown');
    expect(restored.expenses.single.amount, 55);
    expect(restored.evidenceReview.items, isNotEmpty);

    await tester.runAsync(() async {
      final directory =
          await Directory.systemTemp.createTemp('release-journey-');
      try {
        final pack = await const TaxPackBuilder().build(
            vehicle: restored.primaryVehicle!,
            taxRule: restored.activeTaxRule,
            trips: restored.trips,
            expenses: restored.expenses,
            outputDirectory: directory);
        final bytes = await pack.file.readAsBytes();
        expect(bytes.take(2), [80, 75]);
        final zip = ZipDecoder().decodeBytes(bytes);
        expect(zip.findFile('Supporting/record-history.json'), isNotNull);
        expect(zip.findFile('Details.xlsx'), isNotNull);
        expect(
            zip.findFile('Report.pdf')!.content.take(5), [37, 80, 68, 70, 45]);
        expect(pack.receiptCount, 0,
            reason:
                'A manual expense without an image remains missing evidence in the actual accountant handoff.');
      } finally {
        await directory.delete(recursive: true);
      }
    });
    expect(tester.takeException(), isNull);
  });
}
