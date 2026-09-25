import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../state/app_state.dart';

class LogbookOdometerCard extends StatelessWidget {
  final AppState appState;
  final double startOdometer;
  final double endOdometer;
  final ValueChanged<double> onStartOdometerChanged;

  const LogbookOdometerCard({
    super.key,
    required this.appState,
    required this.startOdometer,
    required this.endOdometer,
    required this.onStartOdometerChanged,
  });

  void _showEditStartOdoDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    final controller = TextEditingController(
      text: startOdometer > 0 ? startOdometer.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(LucideIcons.gauge, color: AppColors.workBlue, size: 20),
            SizedBox(width: 8),
            Text('Adjust Start Odometer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter dashboard odometer at the beginning of this journey:',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.ink),
              decoration: InputDecoration(
                suffixText: 'km',
                hintText: 'e.g. 45,200',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '').trim());
              if (val != null && val >= 0) {
                onStartOdometerChanged(val);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.workBlue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.gauge, size: 16, color: AppColors.workBlue),
                  SizedBox(width: 8),
                  Text(
                    'ATO Logbook Evidence (Odometer Chain)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showEditStartOdoDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Edit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.workBlue),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Odometer', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(
                      '${startOdometer.toStringAsFixed(0)} km',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.muted),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('End Odometer', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(
                      '${endOdometer.toStringAsFixed(0)} km',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.deepNavy),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '✓ Auto-calculated continuous audit trail (ATO TR 97/11)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.emerald),
          ),
        ],
      ),
    );
  }
}
