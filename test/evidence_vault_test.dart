import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/audit_evidence.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/evidence/evidence_vault_service.dart';
import 'package:kilotax/services/storage/receipt_image_optimization_service.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  group('Unified Evidence Vault & Anti-Fraud Suite', () {
    late Directory tempDir;
    late EvidenceVaultService vaultService;
    late AppState appState;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vault_test_');

      // Deterministic mock compressor delegate returning mock WebP
      final mockOptimizer = ReceiptImageOptimizationService(
        compressorDelegate: (source, target, width, height, quality) async {
          final targetFile = File(target);
          await targetFile.writeAsBytes([1, 2, 3, 4, 5]);
          return targetFile;
        },
      );

      vaultService = EvidenceVaultService(optimizer: mockOptimizer);
      appState = AppState(evidenceVaultService: vaultService);

      final vehicle = Vehicle(
        id: 'veh_tradie_1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TRADIE-88',
        initialOdometer: 120000.0,
      );
      appState.addVehicle(vehicle);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Registers odometerStart and saves into unified evidence list', () async {
      final sampleFile = File('${tempDir.path}/odo_start.jpg');
      await sampleFile.writeAsBytes([10, 20, 30, 40]);

      final (evidence, error) = await vaultService.registerEvidence(
        rawFile: sampleFile,
        evidenceType: EvidenceType.odometerStart,
        vehicleId: 'veh_tradie_1',
        existingEvidence: [],
      );

      expect(error, isNull);
      expect(evidence, isNotNull);
      expect(evidence!.evidenceType, EvidenceType.odometerStart);
      expect(evidence.vehicleId, 'veh_tradie_1');
      expect(evidence.imageSha256.isNotEmpty, true);

      appState.recordAuditEvidence(evidence);
      expect(appState.evidenceList.length, 1);
      expect(appState.evidenceList.first.id, evidence.id);
    });

    test('Rejects duplicate image hash across different evidence types (Anti-Fraud)', () async {
      final sampleFile = File('${tempDir.path}/sample.jpg');
      await sampleFile.writeAsBytes([50, 60, 70, 80]);

      // Register first as odometerStart
      final (firstEv, _) = await vaultService.registerEvidence(
        rawFile: sampleFile,
        evidenceType: EvidenceType.odometerStart,
        vehicleId: 'veh_tradie_1',
        existingEvidence: [],
      );
      expect(firstEv, isNotNull);

      // Attempt to register identical content as heavyToolsSetup
      final (secondEv, error) = await vaultService.registerEvidence(
        rawFile: sampleFile,
        evidenceType: EvidenceType.heavyToolsSetup,
        vehicleId: 'veh_tradie_1',
        existingEvidence: [firstEv!],
      );

      expect(secondEv, isNull);
      expect(error, contains('already been registered in your evidence vault'));
    });

    test('Rejects odometerEnd if hash matches odometerStart for the same vehicle', () async {
      final sampleFile = File('${tempDir.path}/odo_cluster.jpg');
      await sampleFile.writeAsBytes([11, 22, 33, 44]);

      final (startEv, _) = await vaultService.registerEvidence(
        rawFile: sampleFile,
        evidenceType: EvidenceType.odometerStart,
        vehicleId: 'veh_tradie_1',
        existingEvidence: [],
      );

      final (endEv, error) = await vaultService.registerEvidence(
        rawFile: sampleFile,
        evidenceType: EvidenceType.odometerEnd,
        vehicleId: 'veh_tradie_1',
        existingEvidence: [startEv!],
      );

      expect(endEv, isNull);
      expect(error, isNotNull);
    });
  });
}
