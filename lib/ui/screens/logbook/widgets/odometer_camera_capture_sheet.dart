import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/audit_evidence.dart';
import '../../../../state/app_state.dart';

/// Apple HIG-inspired in-app camera capture sheet for statutory odometer photos.
/// Ensures real-time capture from camera hardware only (no gallery upload fraud),
/// attaches tamper-evident timestamps, and computes SHA-256 hashes to prevent reuse.
class OdometerCameraCaptureSheet extends StatefulWidget {
  final AppState appState;
  final bool isStart;
  final ImagePicker? imagePicker;

  const OdometerCameraCaptureSheet({
    super.key,
    required this.appState,
    required this.isStart,
    this.imagePicker,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required bool isStart,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OdometerCameraCaptureSheet(
        appState: appState,
        isStart: isStart,
      ),
    );
  }

  @override
  State<OdometerCameraCaptureSheet> createState() =>
      _OdometerCameraCaptureSheetState();
}

class _OdometerCameraCaptureSheetState
    extends State<OdometerCameraCaptureSheet> {
  late final ImagePicker _picker;
  File? _capturedFile;
  String? _imageHash;
  DateTime? _capturedAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    // Prompt camera immediately on open for zero-friction capture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openCamera();
    });
  }

  Future<void> _openCamera() async {
    HapticFeedback.mediumImpact();
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        final rawFile = File(photo.path);
        // Optimize first to prevent bloat and hash drift (Red Flag 2)
        final (evidence, error) =
            await widget.appState.evidenceVaultService.registerEvidence(
          rawFile: rawFile,
          evidenceType: widget.isStart
              ? EvidenceType.odometerStart
              : EvidenceType.odometerEnd,
          vehicleId: widget.appState.primaryVehicle?.id,
          existingEvidence: widget.appState.evidenceList,
          watermarkMetadata: {
            'regoPlate': widget.appState.primaryVehicle?.regoPlate ?? '',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        if (error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.crimson,
                content: Text(error),
                duration: const Duration(seconds: 4),
              ),
            );
            if (_capturedFile == null) {
              Navigator.of(context).pop();
            }
          }
          return;
        }

        if (evidence != null) {
          setState(() {
            _capturedFile = File(evidence.storagePath);
            _imageHash = evidence.imageSha256;
            _capturedAt = evidence.capturedAt;
          });
        }
      } else if (_capturedFile == null && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.crimson,
            content: Text('Camera unavailable: $e'),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _savePhoto() async {
    if (_capturedFile == null || _imageHash == null || _capturedAt == null) return;
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    final (success, error) = await widget.appState.saveOdometerPhotoWithIntegrity(
      isStart: widget.isStart,
      photoPath: _capturedFile!.path,
      imageHash: _imageHash!,
      captureDate: _capturedAt!,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.emerald,
          content: Text(
            '✓ ${widget.isStart ? "Day 1 Start" : "Day 84 Finish"} odometer photo saved.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.crimson,
          content: Text(error ?? 'Failed to save photo.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.primaryVehicle;
    final captureTitle =
        widget.isStart ? 'Day 1 Starting Odometer' : 'Day 84 Final Odometer';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    captureTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vehicle?.displayName ?? "Primary Vehicle"} • Odometer Proof',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white70, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Viewfinder / Captured Preview Frame
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_capturedFile != null)
                  Image.file(
                    _capturedFile!,
                    fit: BoxFit.cover,
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.emerald),
                  ),

                // Top Watermark Badge Overlay (Real-time Tamper Evidence)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.shieldCheck,
                                color: AppColors.emerald, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              vehicle?.regoPlate ?? 'AUDIT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          Formatters.date(_capturedAt ?? DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Overlay Status
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Live Camera Capture',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_imageHash != null)
                          Text(
                            'SHA-256: ${_imageHash!.substring(0, 8)}...',
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions (Apple HIG Style)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _openCamera,
                  child: const Text('Retake',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (_capturedFile == null || _isSaving)
                      ? null
                      : _savePhoto,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
