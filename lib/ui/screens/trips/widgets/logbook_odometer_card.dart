import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_space.dart';
import '../../logbook/widgets/logbook_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            Icon(AppIcons.odometer,
                color: AppColors.workBlue, size: AppIconSize.control),
            SizedBox(width: 8),
            Expanded(
                child: Text('Adjust Start Odometer',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
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
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.ink),
              decoration: InputDecoration(
                suffixText: 'km',
                hintText: 'e.g. 45,200',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val =
                  double.tryParse(controller.text.replaceAll(',', '').trim());
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
    return LogbookPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Odometer', style: AppType.section),
        TextButton.icon(
            onPressed: () => _showEditStartOdoDialog(context),
            style: TextButton.styleFrom(
                foregroundColor: AppColor.ink, minimumSize: const Size(48, 48)),
            icon: const Icon(AppIcons.edit, size: AppIconSize.inline),
            label: const Text('Edit start')),
      ]),
      const SizedBox(height: S.md),
      _reading('Start', startOdometer),
      const Divider(height: S.xxl, color: AppColor.hairline),
      _reading('Calculated end', endOdometer),
      const SizedBox(height: S.lg),
      const Text('End reading = starting odometer + trip distance.',
          style: AppType.secondary),
    ]));
  }

  Widget _reading(String label, double value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppType.secondary),
        const SizedBox(height: S.xs),
        Text('${value.toStringAsFixed(0)} km', style: AppType.cardNumeric),
      ]);
}
