import '../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_space.dart';
import 'widgets/logbook_design.dart';
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
    final initialOdo = widget.appState.primaryVehicle?.initialOdometer ?? 0.0;
    _odometerController = TextEditingController(
        text: initialOdo > 0 ? initialOdo.toStringAsFixed(0) : '');
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _odometerController.dispose();
    super.dispose();
  }

  DateTime get _endDate =>
      _startDate.add(Duration(days: AppConstants.statutoryLogbookDays));

  void _confirmStartLogbook() {
    final odo =
        double.tryParse(_odometerController.text.replaceAll(',', '').trim());
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
        content: Text('Logbook started. Review each trip as you go.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.primaryVehicle;
    final vehicleName = vehicle != null
        ? '${vehicle.make} ${vehicle.model}'
        : 'Choose a vehicle';
    final rego = vehicle?.regoPlate ?? 'No vehicle selected';

    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: logbookAppBar(context, 'Set up logbook'),
      bottomNavigationBar: LogbookFooter(
          label: 'Start 12-week logbook',
          onPressed: vehicle == null ? null : _confirmStartLogbook),
      body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(S.xl),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Start your logbook', style: AppType.title),
                  const SizedBox(height: S.md),
                  const Text(
                      'Start with your dashboard reading. Then keep a record of both business and personal trips.',
                      style: AppType.body),
                  const SizedBox(height: S.xxl),
                  LogbookPanel(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Container(
                            padding: const EdgeInsets.all(S.md),
                            decoration: BoxDecoration(
                                color: AppColor.brandTint,
                                borderRadius: R.controlR),
                            child: const Icon(AppIcons.vehicle,
                                color: AppColor.ink,
                                size: AppIconSize.navigation)),
                        const SizedBox(width: S.md),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('YOUR VEHICLE',
                                  style: AppType.eyebrow),
                              const SizedBox(height: S.xs),
                              Text(vehicleName, style: AppType.cardTitle),
                              const SizedBox(height: S.xs),
                              Text(rego, style: AppType.secondary),
                            ])),
                      ])),
                  const SizedBox(height: S.xxl),
                  const LogbookSection('Starting odometer',
                      subtitle: 'Use the reading currently on your dashboard.'),
                  TextField(
                      controller: _odometerController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: AppType.titleSmall
                          .copyWith(fontFeatures: AppType.tabular),
                      decoration: logbookInput('Odometer reading',
                          hint: 'e.g. 42,150', suffix: 'km')),
                  const SizedBox(height: S.xxl),
                  const LogbookSection('Your 12-week period'),
                  LogbookPanel(
                      child: Column(children: [
                    _PeriodRow(
                        label: 'Starts',
                        value: Formatters.date(_startDate),
                        icon: LucideIcons.calendar),
                    const Divider(height: S.xxxl, color: AppColor.hairline),
                    _PeriodRow(
                        label: 'Ends',
                        value: Formatters.date(_endDate),
                        icon: LucideIcons.flag),
                  ])),
                  const SizedBox(height: S.lg),
                  const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(AppIcons.info,
                            size: AppIconSize.control,
                            color: AppColor.inkMuted),
                        SizedBox(width: S.sm),
                        Expanded(
                            child: Text(
                                'Choose a period that reflects your usual driving pattern. You can review your progress at any time.',
                                style: AppType.secondary)),
                      ]),
                  const SizedBox(height: S.xxl),
                ]),
          )),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _PeriodRow(
      {required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: AppIconSize.control, color: AppColor.inkMuted),
        const SizedBox(width: S.md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppType.secondary),
          const SizedBox(height: S.xs),
          Text(value, style: AppType.bodyStrong),
        ])),
      ]);
}
