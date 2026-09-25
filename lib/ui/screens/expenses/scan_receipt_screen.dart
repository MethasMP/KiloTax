import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/ocr/receipt_intelligence_service.dart';
import '../../../services/scanner/document_scanner_service.dart';
import '../../../state/app_state.dart';
import 'expense_detail_screen.dart';

/// Screen 9: Add Expense (Scan Receipt)
/// Mission-critical hardware-accelerated document scanning interface with
/// 4-point perspective de-skewing, contrast enhancement, and resilient fallbacks.
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
  late final DocumentScannerService _scanner;
  final ReceiptIntelligenceService _receiptIntelligence =
      const ReceiptIntelligenceService();

  @override
  void initState() {
    super.initState();
    _scanner = widget.documentScanner ?? DocumentScannerService();
  }

  Future<void> _processScannedImage(String imagePath) async {
    setState(() => _isProcessing = true);
    ReceiptOcrResult? ocrResult;
    try {
      final recognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      await recognizer.close();
      ocrResult = _receiptIntelligence.analyseText(recognized.text);
    } catch (_) {
      // Preserve the receipt image and require manual review if OCR extraction encounters errors.
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
        ),
      ),
    );
  }

  Future<void> _scanReceipt() async {
    HapticFeedback.mediumImpact();
    try {
      final imagePath = await _scanner.scanDocument(allowFallbackToCamera: true);

      if (!mounted) return;

      if (imagePath != null && imagePath.isNotEmpty) {
        HapticFeedback.heavyImpact();
        await _processScannedImage(imagePath);
      }
    } catch (_) {
      if (!mounted) return;
      _navigateToManual();
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.selectionClick();
    try {
      final imagePath = await _scanner.pickFromGallery();
      if (!mounted) return;

      if (imagePath != null && imagePath.isNotEmpty) {
        HapticFeedback.heavyImpact();
        await _processScannedImage(imagePath);
      }
    } catch (_) {
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
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? LucideIcons.zap : LucideIcons.zapOff,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
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
                        Icon(LucideIcons.sparkles,
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
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
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
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text('Enhancing & reading receipt evidence...',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),

            // Bottom Shutter & Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.image,
                        color: Colors.white, size: 26),
                    tooltip: 'Choose from gallery',
                    onPressed: _isProcessing ? null : _pickFromGallery,
                  ),
                  // Shutter Button
                  GestureDetector(
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
                  TextButton(
                    onPressed: _isProcessing ? null : _navigateToManual,
                    child: const Text(
                      'Manual',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
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
