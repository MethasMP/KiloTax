import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../../../services/tracking/location_permission_service.dart';
import '../../widgets/location_escalation_dialog.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';
import 'widgets/value_first_gate_screen.dart';
import '../../widgets/tactile_primary_button.dart';
import '../../../core/theme/app_color.dart';

/// Clean Lifecycle Onboarding Orchestrator:
/// - Phase 0: 3 Value Proposition Slides (with Skip option) -> Educates on benefits
/// - Phase 1: Canonical Sign In Hub (SignInScreen)
/// - Phase 2: Dedicated Vehicle Setup Flow (Decoupled into VehicleSetupFlow)
/// - Phase 3: Explain Context & Enable Automatic Trip Tracking
class OnboardingFlowScreen extends StatefulWidget {
  final int initialStep;

  const OnboardingFlowScreen({super.key, this.initialStep = 0});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  // 0 = Slides, 1 = Welcome/SignIn, 2 = Vehicle Setup, 3 = GPS & Ready
  late int _step;
  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newAppState = context.read<AppState>();
    if (_appState != newAppState) {
      _appState?.removeListener(_onAppStateChanged);
      _appState = newAppState;
      _appState?.addListener(_onAppStateChanged);
    }
  }

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    try {
      final appState = context.read<AppState>();
      if (appState.isAuthenticated && _step == 3) {
        if (mounted) {
          _goToMainScreen();
        }
      }
    } catch (e, stack) {
      debugPrint(
          '[OnboardingFlow] Warning during AppState change handling: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return OnboardingSlidesScreen(
        onComplete: () {
          final appState = context.read<AppState>();
          appState.completeOnboarding();
          setState(() => _step = 1);
        },
      );
    }

    if (_step == 1) {
      return VehicleSetupFlow(
        onVehicleCreated: (vehicle) {
          final appState = context.read<AppState>();
          appState.addVehicle(vehicle);
          // Proceed immediately to Step 2: The Tax Guard (GPS Permission)
          setState(() => _step = 2);
        },
        onCancel: () => setState(() => _step = 0),
      );
    }

    if (_step == 2) {
      return _buildGpsPermissionAndReadyScreen();
    }

    // Step 3: Value-First Gate (Sign-in / Guest)
    final appState = context.watch<AppState>();
    final vehicle = appState.primaryVehicle;
    if (vehicle == null) {
      return VehicleSetupFlow(
        onVehicleCreated: (v) {
          appState.addVehicle(v);
          setState(() => _step = 2);
        },
      );
    }
    return ValueFirstGateScreen(
      vehicle: vehicle,
      onContinue: () {
        _goToMainScreen();
      },
    );
  }

  bool _isRequestingPermission = false;

  void _onGpsStepFinished() {
    final appState = context.read<AppState>();
    if (appState.isAuthenticated) {
      _goToMainScreen();
    } else {
      setState(() => _step = 3);
    }
  }

  Future<void> _handleEnableTracking() async {
    HapticFeedback.heavyImpact();
    setState(() => _isRequestingPermission = true);

    final appState = context.read<AppState>();
    final vehicle = appState.primaryVehicle;
    final permissionService = LocationPermissionService();
    final status = await permissionService.requestForegroundPermission();

    if (!mounted) return;
    setState(() => _isRequestingPermission = false);

    if (status == AppLocationPermissionStatus.grantedForeground ||
        status == AppLocationPermissionStatus.grantedBackground) {
      if (status == AppLocationPermissionStatus.grantedForeground &&
          vehicle?.bluetoothDeviceName != null &&
          vehicle!.bluetoothDeviceName!.isNotEmpty &&
          mounted) {
        await LocationEscalationDialog.show(
          context,
          onDismissManualMode: () {
            if (mounted) _onGpsStepFinished();
          },
          onGranted: () {
            if (mounted) _onGpsStepFinished();
          },
        );
      } else {
        _onGpsStepFinished();
      }
    } else if (status == AppLocationPermissionStatus.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.deepNavy,
            content: const Text(
              'Location permission blocked. Enable in Settings for GPS tracking.',
              style: TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Settings',
              textColor: AppColors.emerald,
              onPressed: () => permissionService.openAppSettings(),
            ),
          ),
        );
        _onGpsStepFinished();
      }
    } else {
      _onGpsStepFinished();
    }
  }

  void _goToMainScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffoldScreen()),
    );
  }

  Widget _buildGpsPermissionAndReadyScreen() {
    final appState = context.watch<AppState>();
    final vehicle = appState.primaryVehicle;
    final isLogbook = vehicle?.taxMethod == TaxMethod.logbook;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
              // Japanese Monozukuri: Animated Dual-Ring Radar Sensor Aura
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColor.brandBright.withValues(alpha: 0.08),
                      ),
                    ),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: AppColor.brandBright.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColor.brandTint,
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.navigation,
                          color: AppColor.brandBright,
                          size: 38,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColor.positiveBright,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isLogbook ? 'ATO Logbook Protection' : 'Tax Deduction Tracking',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                    height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                isLogbook
                    ? 'Records compliant start and end locations automatically for your 12-week logbook.'
                    : 'Records work kilometres in the background so you can claim your tax deduction without paperwork.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                    height: 1.4,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),

              // Summary card of the setup done
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColor.scrimSoft,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColor.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.car,
                              size: 16, color: AppColors.deepNavy),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            vehicle?.displayName ?? 'Your Vehicle',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.ink),
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.emerald, size: 18),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.border),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColor.positiveTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                              isLogbook
                                  ? LucideIcons.bookOpen
                                  : LucideIcons.gauge,
                              size: 16,
                              color: AppColors.emerald),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isLogbook
                                ? 'Logbook Method (12-Week Active)'
                                : 'Cents per kilometre (Up to 5,000 km)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.ink),
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.emerald, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Trust & Reassurance Badges
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColor.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColor.hairline),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.batteryCharging,
                            size: 13, color: AppColor.positiveStrong),
                        SizedBox(width: 5),
                        Text(
                          'Low battery impact',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Text('•', style: TextStyle(color: AppColor.line)),
                    Row(
                      children: [
                        Icon(LucideIcons.lock,
                            size: 13, color: AppColor.brandBright),
                        SizedBox(width: 5),
                        Text(
                          'Private & device-stored',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Primary Action: Enable automatic tracking
              TactilePrimaryButton(
                label: 'Protect My Tax Deductions',
                leadingIcon: LucideIcons.shieldCheck,
                isLoading: _isRequestingPermission,
                onPressed: _handleEnableTracking,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _isRequestingPermission
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _onGpsStepFinished();
                      },
                child: const Text('Add trips manually instead',
                    style: TextStyle(
                        color: AppColors.muted, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
