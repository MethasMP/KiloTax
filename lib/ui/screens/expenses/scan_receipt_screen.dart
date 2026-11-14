import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/scanner/document_scanner_service.dart';
import '../../../state/app_state.dart';
import 'expense_detail_screen.dart';
import 'receipt_inbox_screen.dart';

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
  bool _isProcessing = false;
  final String _processingStatus = 'Enhancing & reading receipt evidence...';
  late final DocumentScannerService _scanner;

  @override
  void initState() {
    super.initState();
    _scanner = widget.documentScanner ?? DocumentScannerService();
  }

  Future<void> _processBatchImages(List<String> imagePaths) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ReceiptInboxScreen(appState: widget.appState, imagePaths: imagePaths),
    ));
    if (mounted) setState(() => _isProcessing = false);
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
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        backgroundColor: AppColor.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed:
                    _isProcessing ? null : () => _processBatchImages(const []),
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('Open saved receipt drafts'),
              ),
              // Hero Viewfinder / Scanner Illustration Surface
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
                    // Concentric inner target area (Outer radius 20 = inner 12 + padding 8)
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
                    // Live OCR / Auto-link badge
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

              // Title and Description with refined typography hierarchy
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

              // Actions or Processing Feedback
              if (_isProcessing) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColor.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColor.line, width: 1),
                  ),
                  child: Column(
                    children: [
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          backgroundColor: AppColor.hairline,
                          color: AppColor.brand,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _processingStatus,
                        style: AppType.bodyStrong.copyWith(
                          fontFeatures: AppType.tabular,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Primary Action: Camera Scanner (Single primary filled button per view)
                FilledButton.icon(
                  onPressed: _scanReceipt,
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

                // Secondary Action: Choose from gallery (Subtle neutral surface)
                OutlinedButton.icon(
                  onPressed: _pickFromGallery,
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

                // Tertiary Action: Manual Entry
                TextButton(
                  onPressed: _navigateToManual,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColor.inkMuted,
                    minimumSize: const Size(double.infinity, 48),
                    textStyle: AppType.bodyStrong,
                  ),
                  child: const Text('Enter details manually'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
