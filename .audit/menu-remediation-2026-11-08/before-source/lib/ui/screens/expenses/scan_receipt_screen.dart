import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/evidence/evidence_auto_match_engine.dart';
import '../../../services/ocr/receipt_intelligence_service.dart';
import '../../../services/scanner/document_scanner_service.dart';
import '../../../state/app_state.dart';
import 'expense_detail_screen.dart';

/// Screen 9: Add Expense (Scan Receipt)
/// Mission-critical hardware-accelerated document scanning interface with
/// 4-point perspective de-skewing, contrast enhancement, resilient fallbacks,
/// and high-volume batch scanning support.
class ScanReceiptScreen extends StatefulWidget {
  final AppState appState;
  final DocumentScannerService? documentScanner;

  const ScanReceiptScreen({
    super.key,
    required this.appState,
    this.documentScanner,
  });

  static Future<void> show(BuildContext context, AppState appState) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanReceiptScreen(appState: appState),
      ),
    );
  }

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  bool _isFlashOn = false;
  bool _isProcessing = false;
  String _processingStatus = 'Enhancing & reading receipt evidence...';
  late final DocumentScannerService _scanner;
  final ReceiptIntelligenceService _receiptIntelligence =
      const ReceiptIntelligenceService();

  @override
  void initState() {
    super.initState();
    _scanner = widget.documentScanner ?? DocumentScannerService();
  }

  Future<ReceiptOcrResult?> _performOcr(String imagePath) async {
    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      await recognizer.close();
      return _receiptIntelligence.analyseText(recognized.text);
    } catch (e, stack) {
      debugPrint(
          '[ScanReceiptScreen] Warning analyzing receipt OCR: $e\n$stack');
      return null;
    }
  }

  Future<void> _processScannedImage(String imagePath) async {
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Enhancing & reading receipt evidence...';
    });
    final ocrResult = await _performOcr(imagePath);

    String? autoLinkedTripId;
    String? autoMatchReason;

    if (ocrResult != null && ocrResult.amount > 0) {
      final vehicleId =
          widget.appState.primaryVehicle?.id ?? 'default_vehicle';
      final receiptDate = ocrResult.date ?? DateTime.now();
      final tempExpense = VehicleExpense(
        id: 'temp_ocr_match',
        vehicleId: vehicleId,
        amount: ocrResult.amount,
        category: ocrResult.category,
        date: receiptDate,
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: tempExpense,
        candidateTrips: widget.appState.trips,
      );

      if (match != null) {
        autoLinkedTripId = match.trip.id;
        autoMatchReason = match.matchReason;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(
          appState: widget.appState,
          merchant: ocrResult?.merchant ?? '',
          amount: ocrResult?.amount ?? 0.0,
          categoryName: ocrResult?.category.displayName ?? 'Materials',
          receiptDate: ocrResult?.date ?? DateTime.now(),
          receiptImagePath: imagePath,
          receiptOcrResult: ocrResult,
          initialLinkedTripId: autoLinkedTripId,
          autoMatchReason: autoMatchReason,
        ),
      ),
    );
  }

  /// Processes multiple scanned receipts sequentially in a batch queue.
  Future<void> _processBatchImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;

    if (imagePaths.length == 1) {
      await _processScannedImage(imagePaths.first);
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Processing 1 of ${imagePaths.length} receipts...';
    });

    final vehicleId =
        widget.appState.primaryVehicle?.id ?? 'default_vehicle';
    final List<ReceiptOcrResult?> results = [];

    for (int i = 0; i < imagePaths.length; i++) {
      if (!mounted) return;
      setState(() {
        _processingStatus =
            'Reading receipt evidence ${i + 1} of ${imagePaths.length}...';
      });

      final path = imagePaths[i];
      final ocrResult = await _performOcr(path);
      results.add(ocrResult);

      // Auto-save batch receipts starting from index 1 directly into the evidence ledger
      if (i > 0) {
        final amount = ocrResult?.amount ?? 0.0;
        final merchant = (ocrResult != null && ocrResult.merchant.trim().isNotEmpty)
            ? ocrResult.merchant.trim()
            : 'Expense ${DateTime.now().toIso8601String().substring(0, 10)}';
        final category = ocrResult?.category ?? ExpenseCategory.toolsMaterials;
        final date = ocrResult?.date ?? DateTime.now();

        final auditTrail = ReceiptAuditTrail(
          rawOcrText: ocrResult?.rawText,
          ocrMerchant: ocrResult?.merchant,
          ocrAmount: ocrResult?.amount,
          ocrGstAmount: ocrResult?.gstAmount,
          ocrAbn: ocrResult?.abn,
          ocrCategory: category.name,
          ocrConfidence: ocrResult?.confidence,
          ocrEvidence: [
            'Batch scanned page ${i + 1} of ${imagePaths.length}',
            ...?ocrResult?.evidence,
          ],
          reviewStatus: (ocrResult != null && ocrResult.isHighConfidence)
              ? ReceiptReviewStatus.verified
              : ReceiptReviewStatus.needsReview,
          capturedAt: DateTime.now(),
        );

        String? batchLinkedTripId;
        if (amount > 0) {
          final tempExpense = VehicleExpense(
            id: 'temp_batch_$i',
            vehicleId: vehicleId,
            amount: amount,
            category: category,
            date: date,
          );
          final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
            expense: tempExpense,
            candidateTrips: widget.appState.trips,
          );
          batchLinkedTripId = match?.trip.id;
        }

        final expense = VehicleExpense(
          id: 'exp_${DateTime.now().millisecondsSinceEpoch}_$i',
          vehicleId: vehicleId,
          amount: amount,
          gstAmount: ocrResult?.gstAmount,
          category: category,
          date: date,
          receiptPath: path,
          notes: merchant,
          linkedTripId: batchLinkedTripId,
          receiptAudit: auditTrail,
          isVaultOnly: false,
        );

        widget.appState.recordExpense(expense);
      }
    }

    if (!mounted) return;

    // Navigate to ExpenseDetailScreen with the first receipt so user can review/edit
    final firstResult = results.isNotEmpty ? results.first : null;
    final firstPath = imagePaths.first;

    String? firstLinkedTripId;
    String? firstMatchReason;
    if (firstResult != null && firstResult.amount > 0) {
      final tempFirstExpense = VehicleExpense(
        id: 'temp_batch_0',
        vehicleId: vehicleId,
        amount: firstResult.amount,
        category: firstResult.category,
        date: firstResult.date ?? DateTime.now(),
      );
      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: tempFirstExpense,
        candidateTrips: widget.appState.trips,
      );
      if (match != null) {
        firstLinkedTripId = match.trip.id;
        firstMatchReason = match.matchReason;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.emerald,
        content: Text(
          'Batch scanned ${imagePaths.length} receipts! ${imagePaths.length - 1} added to evidence ledger.',
        ),
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(
          appState: widget.appState,
          merchant: firstResult?.merchant ?? '',
          amount: firstResult?.amount ?? 0.0,
          categoryName: firstResult?.category.displayName ?? 'Materials',
          receiptDate: firstResult?.date ?? DateTime.now(),
          receiptImagePath: firstPath,
          receiptOcrResult: firstResult,
          initialLinkedTripId: firstLinkedTripId,
          autoMatchReason: firstMatchReason,
        ),
      ),
    );
  }

  Future<void> _scanReceipt() async {
    HapticFeedback.mediumImpact();
    try {
      final imagePaths = await _scanner.scanBatchDocuments(
        maxPages: 20,
        allowFallbackToCamera: true,
      );

      if (!mounted) return;

      if (imagePaths.isNotEmpty) {
        HapticFeedback.heavyImpact();
        await _processBatchImages(imagePaths);
      }
    } catch (e, stack) {
      debugPrint(
          '[ScanReceiptScreen] Warning scanning receipt document: $e\n$stack');
      if (!mounted) return;
      _navigateToManual();
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.selectionClick();
    try {
      final imagePaths = await _scanner.pickMultipleFromGallery();
      if (!mounted) return;

      if (imagePaths.isNotEmpty) {
        HapticFeedback.heavyImpact();
        await _processBatchImages(imagePaths);
      } else {
        // Fallback to single pick if multi returned empty or unsupported
        final singleImage = await _scanner.pickFromGallery();
        if (!mounted) return;
        if (singleImage != null && singleImage.isNotEmpty) {
          HapticFeedback.heavyImpact();
          await _processScannedImage(singleImage);
        }
      }
    } catch (e, stack) {
      debugPrint(
          '[ScanReceiptScreen] Warning picking receipt from gallery: $e\n$stack');
      if (!mounted) return;
      _navigateToManual();
    }
  }

  void _navigateToManual() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(
          appState: widget.appState,
          merchant: '',
          amount: 0.0,
          categoryName: 'Materials',
          receiptDate: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Camera Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: _isFlashOn ? 'Turn flash off' : 'Turn flash on',
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        _isFlashOn ? LucideIcons.zap : LucideIcons.zapOff,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.scanLine,
                            color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Receipt Scanner',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close receipt scanner',
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            // Viewfinder Interface
            Expanded(
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.55,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      // Viewfinder Corners
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ViewfinderCornerPainter(),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.scanLine,
                                  color: Colors.white70, size: 36),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Position receipt within frame',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Auto-crops edges & removes shadows.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      _processingStatus,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // Bottom Shutter & Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Choose from gallery',
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(LucideIcons.image,
                          color: Colors.white, size: 26),
                      tooltip: 'Choose from gallery',
                      onPressed: _isProcessing ? null : _pickFromGallery,
                    ),
                  ),
                  // Shutter Button
                  Semantics(
                    button: true,
                    label: 'Capture receipt photo',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _isProcessing ? null : _scanReceipt,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Enter expense manually',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: TextButton(
                        onPressed: _isProcessing ? null : _navigateToManual,
                        child: const Text(
                          'Manual',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emerald
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const len = 24.0;
    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - len), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
