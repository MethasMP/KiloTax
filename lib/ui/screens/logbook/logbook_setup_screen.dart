import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/app_state.dart';

/// Spec #4 & #5: Logbook Setup Flow
/// "Choose your car claim method -> Logbook -> Setup your logbook:
///  Vehicle: Toyota HiAce 2019
///  Starting odometer: 82,421 km
///  Logbook period: 12 weeks
///  Starts: 6 Sep 2026
///  Ends: 29 Nov 2026
///  [ Start Logbook ]"
class LogbookSetupScreen extends StatefulWidget {
  final AppState appState;

  const LogbookSetupScreen({super.key, required this.appState});

  @override
  State<LogbookSetupScreen> createState() => _LogbookSetupScreenState();
}

class _LogbookSetupScreenState extends State<LogbookSetupScreen> {
  late final TextEditingController _odometerController;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final initialOdo = widget.appState.primaryVehicle?.initialOdometer ?? 82421.0;
    _odometerController = TextEditingController(text: initialOdo.toStringAsFixed(0));
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _odometerController.dispose();
    super.dispose();
  }

  DateTime get _endDate => _startDate.add(Duration(days: AppConstants.statutoryLogbookDays));

  void _confirmStartLogbook() {
    final odo = double.tryParse(_odometerController.text.replaceAll(',', '').trim());
    if (odo == null || odo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid starting odometer reading.'),
          backgroundColor: AppColors.crimson,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    widget.appState.startLogbookPeriod(
      startDate: _startDate,
      startingOdometer: odo,
    );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.emerald,
        content: Text('✓ 12-Week Logbook activated! Valid until ${DateTime.now().year + 5}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.primaryVehicle;
    final vehicleName = vehicle != null ? '${vehicle.make} ${vehicle.model}' : 'Toyota HiAce';
    final rego = vehicle?.regoPlate ?? 'TRADIE-1';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Set Up Your Logbook', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.workBlueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.truck, color: AppColors.workBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VEHICLE ASSIGNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
                        Text(vehicleName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink)),
                        Text(rego, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ATO Compliant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emerald)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Starting Odometer Input
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
                  const Text('Starting Odometer Reading', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  const Text('Record the odometer currently showing on your dashboard.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _odometerController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                    decoration: InputDecoration(
                      suffixText: 'km',
                      suffixStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Statutory Period Specification
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const _PeriodRow(
                    label: 'Logbook Period',
                    value: '12 Continuous Weeks',
                    caption: 'ATO minimum statutory requirement',
                    icon: LucideIcons.calendar,
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  _PeriodRow(
                    label: 'Starts',
                    value: Formatters.date(_startDate),
                    caption: 'Beginning of representative driving',
                    icon: LucideIcons.playCircle,
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  _PeriodRow(
                    label: 'Ends',
                    value: Formatters.date(_endDate),
                    caption: 'Continuous 84 days period completion',
                    icon: LucideIcons.flag,
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  _PeriodRow(
                    label: 'Statutory Validity',
                    value: '5 Years (until ${DateTime.now().year + 5})',
                    caption: 'Can be re-used if pattern stays similar',
                    icon: LucideIcons.shieldCheck,
                    valueColor: AppColors.emerald,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Start Logbook CTA
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.workBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _confirmStartLogbook,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.compass, size: 20),
                  SizedBox(width: 8),
                  Text('Start 12-Week Logbook', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color? valueColor;

  const _PeriodRow({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink)),
              Text(caption, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: valueColor ?? AppColors.ink),
        ),
      ],
    );
  }
}
