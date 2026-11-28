import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/ocr/receipt_intelligence_service.dart';
import '../../../services/ocr/receipt_ocr_engine.dart';
import '../../../services/ocr/thermal_receipt_image_preprocessor.dart';
import '../../../services/receipts/receipt_inbox_service.dart';
import '../../../services/receipts/receipt_workflow_policy.dart';
import '../../../services/scanner/document_scanner_service.dart';
import '../../../state/app_state.dart';
import 'expense_detail_screen.dart';
import 'receipt_inbox_screen.dart';
import 'widgets/receipt_processing_view.dart';

/// Screen 9: Add Expense (Scan Receipt)
/// Mission-critical hardware-accelerated document scanning interface with
/// 4-point perspective de-skewing, contrast enhancement, resilient fallbacks,
/// and high-volume batch scanning support.
class ScanReceiptScreen extends StatefulWidget {
  final AppState appState;
  final bool autoStartScanner;
  final DocumentScannerService? documentScanner;
  final ReceiptOcrEngine? ocrEngine;
  final ReceiptIntelligenceService? intelligenceService;
  final ReceiptInboxService? receiptInboxService;
  final ThermalReceiptImagePreprocessor? preprocessor;

  const ScanReceiptScreen({
    super.key,
    required this.appState,
    this.autoStartScanner = false,
    this.documentScanner,
    this.ocrEngine,
    this.intelligenceService,
    this.receiptInboxService,
    this.preprocessor,
  });

  static Future<void> show(BuildContext context, AppState appState,
      {bool openCamera = true}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ScanReceiptScreen(appState: appState, autoStartScanner: openCamera),
      ),
    );
  }

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  bool _isProcessing = false;
  bool _isAcquiring = false;
  String? _processingImagePath;
  String? _acquisitionError;
  double? _lastOcrConfidence;
  bool _lastOcrIsLowConfidence = false;
  bool get _isBusy => _isProcessing || _isAcquiring;
  String _processingStatus = 'Reading receipt details…';
  late final DocumentScannerService _scanner;
  late final ReceiptIntelligenceService _intelligence;
  late final ThermalReceiptImagePreprocessor? _preprocessor;

  @override
  void initState() {
    super.initState();
    _scanner = widget.documentScanner ??
        DocumentScannerService(reportCaptureErrors: true);
    _intelligence =
        widget.intelligenceService ?? const ReceiptIntelligenceService();
    _preprocessor = widget.preprocessor ??
        (widget.ocrEngine == null
            ? const ThermalReceiptImagePreprocessor()
            : null);
    if (widget.autoStartScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanReceipt(autoLaunch: true);
      });
    }
  }

  Future<void> _processBatchImages(List<String> imagePaths) async {
    if (!mounted || _isProcessing) return;

    if (imagePaths.length == 1) {
      setState(() {
        _isProcessing = true;
        _processingStatus = 'Reading receipt details…';
        _processingImagePath = imagePaths.first;
      });

      final imagePath = imagePaths.first;
      final enhancedPath = '${imagePath}_enhanced.jpg';
      String? enhancedTempPath;
      try {
        var targetPath = imagePath;
        var isImageBlurry = false;
        late final ReceiptOcrResult ocr;
        try {
          // Step 1: Preprocess thermal image (assess blur and enhance faded contrast)
          if (_preprocessor != null) {
            final preprocessed = await _preprocessor.preprocessReceipt(
              inputPath: imagePath,
              outputPath: enhancedPath,
            );
            targetPath = preprocessed.enhancedPath;
            if (targetPath != imagePath) {
              enhancedTempPath = targetPath;
            }
            isImageBlurry = preprocessed.clarity.isBlurry;
          }

          // Step 2: Feed enhanced image to OCR engine
          final engine = widget.ocrEngine ?? ReceiptOcrEngineFactory.create();
          final extraction = await engine.recognizeFile(targetPath);
          ocr = const ReceiptWorkflowPolicy().analyseWithContext(
            extraction.text,
            blocks: extraction.blocks,
            trips: widget.appState.trips,
            existingExpenses: widget.appState.expenses,
            intelligence: _intelligence,
          );
        } finally {
          if (_preprocessor != null) {
            for (final candidate in {enhancedPath, enhancedTempPath}) {
              if (candidate == null || candidate == imagePath) continue;
              try {
                final tempFile = File(candidate);
                if (tempFile.existsSync()) {
                  tempFile.deleteSync();
                }
              } catch (_) {}
            }
          }
        }

        if (!mounted) return;

        final isHighConfidence =
            !isImageBlurry && (ocr.confidence >= 0.90 || ocr.isHighConfidence);
        final isLowConfidence = isImageBlurry || ocr.confidence < 0.70;
        debugPrint(
            '[ScanReceiptScreen] Single-shot OCR complete. Confidence: ${ocr.confidence}, isHighConfidence: $isHighConfidence, isLowConfidence: $isLowConfidence, isBlurry: $isImageBlurry');

        if (isHighConfidence) {
          HapticFeedback.heavyImpact();
        } else if (isLowConfidence) {
          HapticFeedback.lightImpact();
          setState(() {
            _lastOcrConfidence = ocr.confidence;
            _lastOcrIsLowConfidence = true;
            _processingStatus = isImageBlurry
                ? 'Image looks blurry. Please check details carefully…'
                : 'Low confidence (${(ocr.confidence * 100).round()}%). Check details…';
          });
        }

        await _openReview(ExpenseDetailScreen(
          appState: widget.appState,
          merchant: ocr.merchant,
          amount: ocr.amount,
          categoryName: ocr.category.displayName,
          receiptDate: ocr.parsedDate ?? ocr.date,
          receiptImagePath: imagePath,
          receiptOcrResult: ocr,
          purchaseDateUnknown: ocr.dateNeedsReview,
        ));
      } catch (e, stack) {
        debugPrint(
            '[ScanReceiptScreen] Single-shot OCR failed, falling back: $e\n$stack');
        if (!mounted) return;
        await _openReview(ExpenseDetailScreen(
          appState: widget.appState,
          merchant: '',
          amount: 0.0,
          categoryName: 'Materials',
          receiptDate: DateTime.now(),
          receiptImagePath: imagePath,
          purchaseDateUnknown: true,
        ));
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Opening your receipt inbox…';
    });

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReceiptInboxScreen(
        appState: widget.appState,
        imagePaths: imagePaths,
        inbox: widget.receiptInboxService,
        engine: widget.ocrEngine,
      ),
    ));
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _openReview(ExpenseDetailScreen screen) async {
    final route = MaterialPageRoute<void>(builder: (_) => screen);
    if (widget.autoStartScanner) {
      await Navigator.of(context).pushReplacement(route);
    } else {
      await Navigator.of(context).push(route);
    }
  }

  Future<void> _scanReceipt({bool autoLaunch = false}) async {
    if (_isBusy) return;
    setState(() {
      _isAcquiring = true;
      _acquisitionError = null;
    });
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
      } else if (autoLaunch && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      debugPrint('[ScanReceiptScreen] Camera scan failed: $e\n$stack');
      if (mounted) {
        setState(() => _acquisitionError =
            'Couldn’t open the camera. Try again, choose a photo, or enter details manually.');
      }
    } finally {
      if (mounted) setState(() => _isAcquiring = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isBusy) return;
    setState(() {
      _isAcquiring = true;
      _acquisitionError = null;
    });
    HapticFeedback.selectionClick();
    try {
      final imagePaths = await _scanner.pickMultipleFromGallery();
      if (!mounted) return;
      if (imagePaths.isNotEmpty) {
        HapticFeedback.heavyImpact();
        await _processBatchImages(imagePaths);
      }
    } catch (e, stack) {
      debugPrint('[ScanReceiptScreen] Gallery selection failed: $e\n$stack');
      if (mounted) {
        setState(() => _acquisitionError =
            'Couldn’t open your photos. Try again or enter details manually.');
      }
    } finally {
      if (mounted) setState(() => _isAcquiring = false);
    }
  }

  void _navigateToManual() {
    if (_isBusy) return;
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
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        backgroundColor: AppColor.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: _isProcessing
            ? ReceiptProcessingView(
                imagePath: _processingImagePath,
                status: _processingStatus,
                confidence: _lastOcrConfidence,
                isLowConfidence: _lastOcrIsLowConfidence,
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_acquisitionError != null) ...[
                      Semantics(
                          liveRegion: true,
                          child: Text(_acquisitionError!,
                              style: AppType.body
                                  .copyWith(color: AppColor.attentionInk))),
                      const SizedBox(height: 16),
                    ],
                    if (_isAcquiring) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text('Opening receipt capture…',
                          style: AppType.secondary),
                    ],
                    TextButton.icon(
                      onPressed:
                          _isBusy ? null : () => _processBatchImages(const []),
                      icon: const Icon(Icons.inbox_outlined),
                      label: const Text('Open saved receipt drafts'),
                    ),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColor.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColor.line, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: AppColor.ink.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: AppColor.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColor.hairline,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                LucideIcons.scanLine,
                                size: 54,
                                color: AppColor.brand,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColor.brandTint,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColor.brandTintStrong,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.sparkles,
                                    size: 13,
                                    color: AppColor.brand,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'ATO Smart Match & Multi-scan',
                                    style: AppType.eyebrow.copyWith(
                                      color: AppColor.brand,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'Scan receipt evidence',
                      style: AppType.title,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: const Text(
                        'Photograph physical fuel and material dockets or upload photos. Text recognition extracts merchant, amount, GST, and auto-links eligible trips.',
                        style: AppType.secondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    FilledButton.icon(
                      onPressed: _isBusy ? null : () => _scanReceipt(),
                      icon: const Icon(LucideIcons.camera, size: 20),
                      label: const Text('Open camera scanner'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColor.brand,
                        foregroundColor: AppColor.onNavy,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _pickFromGallery,
                      icon: const Icon(LucideIcons.image, size: 20),
                      label: const Text('Choose from gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColor.ink,
                        side: const BorderSide(color: AppColor.line, width: 1),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _isBusy ? null : _navigateToManual,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColor.inkMuted,
                        minimumSize: const Size(double.infinity, 48),
                        textStyle: AppType.bodyStrong,
                      ),
                      child: const Text('Enter details manually'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
