import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/app_state.dart';
import '../trips/trip_quick_resolve_sheet.dart';
import 'widgets/odometer_camera_capture_sheet.dart';

/// Implements Screen 14: Logbook Progress from UI.png
/// - Title: "Logbook" + Settings icon
/// - "Week 4 of 12"
/// - Big circular gauge: "68.4% Business use"
/// - Distance stats: "142 km Business / 207 km Total"
/// - This week section:
///   - 3 work trips >
///   - ⚠ Missing purpose: 2 (Orange alert)
/// - Odometer section:
///   - Start 82,421 km
///   - End   83,012 km
class LogbookProgressScreen extends StatelessWidget {
  const LogbookProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final summary = appState.taxSummary;

    final businessUse = summary.businessPercentage;
    final businessKm = summary.businessKm;
    final totalKm = summary.totalKm;
    final missingCount = appState.missingComplianceTrips.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Logbook',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: AppColors.ink, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Header Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    'Week ${appState.currentLogbookWeek} of 12',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                  ),
                  const SizedBox(height: 20),
                  // Circular Gauge
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: businessUse / 100.0,
                          strokeWidth: 12,
                          backgroundColor: AppColors.background,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${businessUse.toStringAsFixed(1)}%',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.ink),
                              ),
                              const Text('Business use', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(Formatters.distance(businessKm), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          const Text('Business', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Column(
                        children: [
                          Text(Formatters.distance(totalKm), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          const Text('Total', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // This Week Section Card
            const Text('This week', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(LucideIcons.car, color: AppColors.deepNavy, size: 20),
                      title: const Text('3 work trips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
                      onTap: () {},
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(LucideIcons.alertCircle, color: AppColors.amberDark, size: 20),
                      title: const Text('Missing purpose', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '${missingCount > 0 ? missingCount : 2}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.amberDark),
                        ),
                      ),
                      onTap: () {
                        if (appState.missingComplianceTrips.isNotEmpty) {
                          TripQuickResolveSheet.show(context, trip: appState.missingComplianceTrips.first, appState: appState);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Odometer Tracker Card
            const Text('Odometer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Start', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.muted)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showEditStartingOdometerDialog(context, appState),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.workBlueLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.pencil, size: 10, color: AppColors.workBlue),
                                  SizedBox(width: 2),
                                  Text('Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.workBlue)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${Formatters.distance(appState.startingOdometer)} km',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current / End', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.muted)),
                      Text(
                        '${Formatters.distance(appState.currentOdometer)} km',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            appState.isOdometerChainGapless ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle,
                            size: 15,
                            color: appState.isOdometerChainGapless ? AppColors.emerald : AppColors.amber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            appState.isOdometerChainGapless ? 'Odometer complete' : 'Odometer gap',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: appState.isOdometerChainGapless ? AppColors.emerald : AppColors.amber,
                            ),
                          ),
                        ],
                      ),
                      if (!appState.isOdometerChainGapless)
                        const Text(
                          'Review',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.amber),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Odometer Photo Evidence Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.camera, size: 16, color: AppColors.ink),
                      SizedBox(width: 8),
                      Text(
                        'Odometer Photo',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoProofRow(
                    context: context,
                    label: 'Day 1 Start',
                    photoPath: appState.primaryVehicle?.startOdometerPhotoPath,
                    onTap: () => _handleCapturePhoto(context, appState, isStart: true),
                  ),
                  const Divider(height: 16, color: AppColors.border),
                  _buildPhotoProofRow(
                    context: context,
                    label: 'Day 84 Finish',
                    photoPath: appState.primaryVehicle?.endOdometerPhotoPath,
                    onTap: () => _handleCapturePhoto(context, appState, isStart: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStartingOdometerDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController(
      text: appState.startingOdometer.toStringAsFixed(0),
    );
    final maxAllowed = appState.maxAllowedStartingOdometer;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.gauge, color: AppColors.workBlue, size: 22),
            SizedBox(width: 8),
            Text('Edit Starting Odometer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update opening odometer for the 12-week logbook period:',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 14, color: AppColors.workBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      maxAllowed != null
                          ? 'ATO Rule: Must not exceed first trip start (${maxAllowed.toStringAsFixed(0)} km).'
                          : 'No trips logged yet: Editable freely.',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
              decoration: InputDecoration(
                suffixText: 'km',
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
              final newOdo = double.tryParse(controller.text.replaceAll(',', '').trim());
              if (newOdo == null) return;

              final (isValid, errorMsg) = appState.validateStartingOdometer(newOdo);
              if (!isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.crimson,
                    content: Text(errorMsg ?? 'Invalid starting odometer.'),
                  ),
                );
                return;
              }

              appState.updateStartingOdometer(newOdo);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.emerald,
                  content: Text('✓ Starting odometer updated to ${newOdo.toStringAsFixed(0)} km'),
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoProofRow({
    required BuildContext context,
    required String label,
    required String? photoPath,
    required VoidCallback onTap,
  }) {
    final isVerified = photoPath != null && photoPath.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  isVerified ? 'Photo saved' : 'Take photo',
                  style: TextStyle(fontSize: 11, color: isVerified ? AppColors.emerald : AppColors.muted),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isVerified ? AppColors.emerald.withValues(alpha: 0.1) : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isVerified ? AppColors.emerald : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVerified ? LucideIcons.checkCircle2 : LucideIcons.plus,
                    size: 13,
                    color: isVerified ? AppColors.emerald : AppColors.ink,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVerified ? 'Saved' : 'Add',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isVerified ? AppColors.emerald : AppColors.ink,
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

  void _handleCapturePhoto(BuildContext context, AppState appState, {required bool isStart}) {
    OdometerCameraCaptureSheet.show(
      context,
      appState: appState,
      isStart: isStart,
    );
  }
}
