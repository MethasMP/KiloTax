import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';

class OnboardingOcrHudCard extends StatelessWidget {
  final bool isScanningOcr;
  final bool scanSuccess;
  final double detectedOdo;
  final TextEditingController odoController;
  final VoidCallback onScanPressed;
  final ValueChanged<String> onOdoChanged;
  final void Function(double delta) onAdjustOdometer;

  const OnboardingOcrHudCard({
    super.key,
    required this.isScanningOcr,
    required this.scanSuccess,
    required this.detectedOdo,
    required this.odoController,
    required this.onScanPressed,
    required this.onOdoChanged,
    required this.onAdjustOdometer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scanSuccess ? AppColors.emerald : AppColors.border, width: scanSuccess ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.workBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(PhosphorIconsBold.camera, color: AppColors.workBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Dashboard Odometer Scanner',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      'Scan dashboard photo or type manually',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.workBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isScanningOcr ? null : onScanPressed,
                child: isScanningOcr
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Auto-Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: odoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onOdoChanged,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink),
            decoration: InputDecoration(
              suffixText: 'KM',
              suffixStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted),
              labelText: 'Opening Odometer Reading',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.muted),
                onPressed: () => onAdjustOdometer(-10.0),
              ),
              const Text('Adjust: ±10 km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.muted),
                onPressed: () => onAdjustOdometer(10.0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
