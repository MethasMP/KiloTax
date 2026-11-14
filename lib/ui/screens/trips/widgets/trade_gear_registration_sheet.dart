import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/audit_evidence.dart';
import '../../../../state/app_state.dart';

/// Trade Gear Registration Sheet (ATO s 8-1 Travel Substantiation)
/// Captures in-vehicle trade tool photo & tool description into the unified audit vault.
class TradeGearRegistrationSheet extends StatefulWidget {
  final AppState appState;
  final ImagePicker? imagePicker;

  const TradeGearRegistrationSheet({
    super.key,
    required this.appState,
    this.imagePicker,
  });

  static Future<bool?> show(
    BuildContext context, {
    required AppState appState,
    ImagePicker? imagePicker,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TradeGearRegistrationSheet(
        appState: appState,
        imagePicker: imagePicker,
      ),
    );
  }

  @override
  State<TradeGearRegistrationSheet> createState() =>
      _TradeGearRegistrationSheetState();
}

class _TradeGearRegistrationSheetState
    extends State<TradeGearRegistrationSheet> {
  late final ImagePicker _picker;
  late final TextEditingController _toolsController;
  File? _capturedFile;
  String? _imageHash;
  bool _isSaving = false;
  bool _isCameraLaunching = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    final primary = widget.appState.primaryVehicle;
    _toolsController = TextEditingController(
      text: primary?.tradeToolsDescription ?? '',
    );
    if (primary?.tradeToolsPhotoPath != null) {
      final f = File(primary!.tradeToolsPhotoPath!);
      if (f.existsSync()) {
        _capturedFile = f;
        _imageHash = primary.tradeToolsImageHash;
      }
    }
  }

  @override
  void dispose() {
    _toolsController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_isCameraLaunching) return;
    _isCameraLaunching = true;
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
        final (evidence, error) =
            await widget.appState.evidenceVaultService.registerEvidence(
          rawFile: rawFile,
          evidenceType: EvidenceType.heavyToolsSetup,
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
              ),
            );
          }
          return;
        }

        if (evidence != null && mounted) {
          setState(() {
            _capturedFile = File(evidence.storagePath);
            _imageHash = evidence.imageSha256;
          });
        }
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
      }
    } finally {
      _isCameraLaunching = false;
    }
  }

  Future<void> _saveGearProfile() async {
    final text = _toolsController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.amberDark,
          content: Text('Please describe your work tools.'),
        ),
      );
      return;
    }

    if (_capturedFile == null || _imageHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.amberDark,
          content: Text('Please take a photo of your work tools in your vehicle.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    await widget.appState.saveTradeGearProfile(
      description: text,
      photoPath: _capturedFile!.path,
      imageHash: _imageHash!,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Work Tools',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Take one photo of your work gear in your vehicle. Your accountant uses this to prove why you need your vehicle for work travel.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.muted, size: 20),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Photo Capture Area
            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                height: 190,
                decoration: BoxDecoration(
                  color: AppColor.surfaceSunken,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _capturedFile != null
                        ? AppColors.emerald
                        : AppColors.border,
                    width: _capturedFile != null ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _capturedFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _capturedFile!,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.camera,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Retake Photo',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.emerald,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.shieldCheck,
                                      color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Gear Photo Registered',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.workBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.camera,
                              color: AppColors.workBlue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Take Photo of Work Tools',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Show tools loaded in ute tub, boot, or van',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Text input for tool description
            const Text(
              'Tool description',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _toolsController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Toolboxes, drop saw, ladder, nail guns',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                filled: true,
                fillColor: AppColor.surfaceSunken,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.workBlue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveGearProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Tools & Evidence',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
