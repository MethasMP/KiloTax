import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/constants/app_constants.dart';

class OnboardingBluetoothSelector extends StatelessWidget {
  final List<Map<String, String>> detectedDevices;
  final String selectedBluetooth;
  final ValueChanged<String> onDeviceSelected;

  const OnboardingBluetoothSelector({
    super.key,
    required this.detectedDevices,
    required this.selectedBluetooth,
    required this.onDeviceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.workBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(PhosphorIconsBold.bluetooth, color: AppColors.workBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hands-Free Bluetooth Auto-Start',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      'Auto-starts logbook when paired with car audio',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedBluetooth.isNotEmpty ? selectedBluetooth : null,
            hint: const Text('Select In-Car Bluetooth / CarPlay', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            items: detectedDevices.map((d) {
              final name = d['name'] ?? 'Car Audio';
              final vehicle = d['vehicle'] ?? '';
              return DropdownMenuItem(
                value: name,
                child: Text('$name ($vehicle)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) onDeviceSelected(val);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ],
      ),
    );
  }
}
