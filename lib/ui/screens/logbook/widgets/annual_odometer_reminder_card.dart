import '../../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/annual_odometer.dart';
import '../../../../services/tax/ato_tax_period_engine.dart';
import '../../../../state/app_state.dart';
import 'odometer_camera_capture_sheet.dart';

/// ATO Statutory 30 June Closing Odometer Alert Widget (ITAA 1997 s 28-125).
///
/// Reminds tradies & sole traders in Years 1–5 of their 5-year logbook exemption
/// to record their closing 30 June odometer reading to protect their tax deduction.
class AnnualOdometerReminderCard extends StatelessWidget {
  final AppState appState;

  const AnnualOdometerReminderCard({super.key, required this.appState});

  void _showRecordOdometerDialog(BuildContext context) {
    final vehicle = appState.primaryVehicle;
    if (vehicle == null) return;

    final now = DateTime.now();
    final periodEngine = const AtoTaxPeriodEngine();
    final targetFy = now.month == 7
        ? AtoFinancialYear(now.year - 1)
        : periodEngine.forDate(now);
    final fyLabel = targetFy.shortLabel;

    final textController = TextEditingController(
      text: appState.currentOdometer.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColor.attentionTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                AppIcons.odometer,
                color: AppColor.attention,
                size: AppIconSize.control,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Record EOFY Odometer',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColor.ink,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the closing odometer for $fyLabel (as at 30 June) for ${vehicle.regoPlate.isNotEmpty ? vehicle.regoPlate : vehicle.model}:',
              style: const TextStyle(
                fontSize: 13,
                color: AppColor.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Closing Odometer (km)',
                suffixText: 'km',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                OdometerCameraCaptureSheet.show(
                  context,
                  appState: appState,
                  isStart: false,
                );
              },
              icon: const Icon(AppIcons.camera, size: AppIconSize.inline),
              label: const Text('Capture Cluster Photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColor.brand,
                side: const BorderSide(color: AppColor.line),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColor.inkSubtle)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(textController.text.trim());
              if (val != null && val >= 0) {
                HapticFeedback.heavyImpact();
                final existing =
                    appState.getAnnualOdometer(vehicle.id, fyLabel);
                final record = (existing ??
                        AnnualVehicleOdometer(
                          id: 'annual_${vehicle.id}_$fyLabel',
                          vehicleId: vehicle.id,
                          financialYear: fyLabel,
                          openingDate: DateTime(targetFy.startYear, 7, 1),
                          openingOdometer: vehicle.initialOdometer,
                        ))
                    .copyWith(
                  closingDate: DateTime(targetFy.endYear, 6, 30),
                  closingOdometer: val,
                );
                appState.recordAnnualOdometer(record);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.emerald,
                    content: Row(
                      children: [
                        const Icon(LucideIcons.shieldCheck,
                            color: Colors.white, size: AppIconSize.inline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✓ EOFY 30 June odometer (${val.toStringAsFixed(0)} km) secured for $fyLabel.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save Record',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.isAnnualOdometerRequired()) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final periodEngine = const AtoTaxPeriodEngine();
    final targetFy = now.month == 7
        ? AtoFinancialYear(now.year - 1)
        : periodEngine.forDate(now);
    final fyLabel = targetFy.shortLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.attentionTintSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColor.attentionTintStrong,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColor.scrimSoft,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColor.attentionTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColor.attention.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  LucideIcons.shieldAlert,
                  color: AppColor.attention,
                  size: AppIconSize.control,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'EOFY Odometer Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColor.attentionInk,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColor.attentionTintStrong,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            's 28-125',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColor.attentionInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Record your June 30 closing odometer to protect your 5-year logbook exemption for $fyLabel.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColor.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRecordOdometerDialog(context),
                  icon: const Icon(AppIcons.odometer, size: AppIconSize.inline),
                  label: const Text(
                    'Record 30 June Odometer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Capture Photo',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  OdometerCameraCaptureSheet.show(
                    context,
                    appState: appState,
                    isStart: false,
                  );
                },
                icon: const Icon(AppIcons.camera, size: AppIconSize.control),
                style: IconButton.styleFrom(
                  backgroundColor: AppColor.surface,
                  foregroundColor: AppColor.brand,
                  side: const BorderSide(color: AppColor.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
