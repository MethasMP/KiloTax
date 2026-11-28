import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/evidence/evidence_vault_service.dart';
import 'package:kiloclaim/services/storage/receipt_image_optimization_service.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  group('PR-10: Evidence Vault Wipe on Local Wipe Sign Out', () {
    late Directory tempDir;
    late Directory vaultDir;
    late ReceiptImageOptimizationService optimizer;
    late EvidenceVaultService evidenceVaultService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('kiloclaim_vault_test_');
      vaultDir = Directory('${tempDir.path}/evidence_vault');
      await vaultDir.create(recursive: true);

      optimizer = ReceiptImageOptimizationService(
        compressorDelegate: (source, target, width, height, quality) async {
          final targetFile = File(target);
          await targetFile.writeAsString('webp content');
          return targetFile;
        },
      );
      evidenceVaultService = EvidenceVaultService(
        optimizer: optimizer,
        vaultDirectory: vaultDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Optimized receipts are saved inside designated vault directory', () async {
      final rawFile = File('${tempDir.path}/receipt_sample.jpg');
      await rawFile.writeAsString('sample raw receipt');

      final optResult = await optimizer.optimizeReceipt(
        rawFile,
        targetDirectory: vaultDir,
      );

      expect(optResult.file.path.startsWith(vaultDir.path), isTrue);
      expect(await optResult.file.exists(), isTrue);
    });

    test('clearLocalVault deletes all cached files inside vault directory', () async {
      final file1 = File('${vaultDir.path}/rec_1.webp');
      final file2 = File('${vaultDir.path}/rec_2.webp');
      await file1.writeAsString('img1');
      await file2.writeAsString('img2');

      expect(vaultDir.listSync().length, equals(2));

      await evidenceVaultService.clearLocalVault();
      // Should delete files within vault directory
      expect(file1.existsSync(), isFalse);
      expect(file2.existsSync(), isFalse);
    });

    test('AppState.signOut with wipeLocalData: true cleans vault and local memory', () async {
      final appState = AppState();
      appState.addVehicle(Vehicle(
        id: 'v_wipe',
        regoPlate: 'WIPE-01',
        make: 'Toyota',
        model: 'Hilux',
        initialOdometer: 10000.0,
      ));

      expect(appState.primaryVehicle, isNotNull);

      await appState.signOut(wipeLocalData: true);

      expect(appState.primaryVehicle, isNull);
      expect(appState.vehicles, isEmpty);
      expect(appState.trips, isEmpty);
      expect(appState.expenses, isEmpty);
    });
  });
}
