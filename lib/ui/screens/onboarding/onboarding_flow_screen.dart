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

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    try {
      context.read<AppState>().removeListener(_onAppStateChanged);
    } catch (e, stack) {
      debugPrint(
          '[OnboardingFlow] Warning removing AppState listener: $e\n$stack');
    }
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    try {
      final appState = context.read<AppState>();
      if (appState.isAuthenticated && _step < 2) {
        if (mounted) {
          setState(() => _step = 2);
        }
      }
    } catch (e, stack) {
      debugPrint(
          '[OnboardingFlow] Warning during AppState change handling: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    // STEP 0: 3 Value Proposition Slides
    if (_step == 0) {
      return OnboardingSlidesScreen(
        onComplete: () {
          final appState = context.read<AppState>();
          appState.completeOnboarding();
          setState(() => _step = 1);
        },
      );
    }

    // STEP 1: Value-First: Choose Vehicle & Claim Mode (Hilux, Ranger, etc.)
    if (_step == 1) {
      return VehicleSetupFlow(
        onVehicleCreated: (vehicle) {
          final appState = context.read<AppState>();
          appState.addVehicle(vehicle);
          // If already authenticated, proceed directly to GPS screen; otherwise present Value-First Soft Gate
          if (appState.isAuthenticated) {
            setState(() => _step = 3);
          } else {
            setState(() => _step = 2);
          }
        },
        onCancel: () => setState(() => _step = 0),
      );
    }

    // STEP 2: Value-First Soft Gate (Presents $4,550 value & Apple/Google/Guest choice)
    if (_step == 2) {
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
          setState(() => _step = 3);
        },
      );
    }

    // STEP 3: Explain Context & Enable Automatic Trip Tracking
    return _buildGpsPermissionAndReadyScreen();
  }

  bool _isRequestingPermission = false;

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
            if (mounted) _goToMainScreen();
          },
          onGranted: () {
            if (mounted) _goToMainScreen();
          },
        );
      } else {
        _goToMainScreen();
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
        _goToMainScreen();
      }
    } else {
      _goToMainScreen();
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
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      ),
                    ),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x102563EB),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.navigation,
                          color: Color(0xFF2563EB),
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
                          color: Color(0xFF10B981),
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
              const Text(
                'Automatically detect\nyour work trips',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.6,
                    height: 1.22),
              ),
              const SizedBox(height: 10),
              const Text(
                'We use smart background location to log drives automatically for ATO tax substantiation whenever you travel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.muted, height: 1.45),
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
                      color: Color(0x04000000),
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
                            color: const Color(0xFFF1F5F9),
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
                            color: const Color(0xFFECFDF5),
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

              // Trust & Reassurance Badges (Battery + Privacy Kodawari Guarantee)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.batteryCharging,
                            size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 5),
                        Text(
                          'Battery-Friendly Sleep',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                    Row(
                      children: [
                        Icon(LucideIcons.lock,
                            size: 13, color: Color(0xFF2563EB)),
                        SizedBox(width: 5),
                        Text(
                          'Encrypted ATO Trail',
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

              // Primary Action: Enable automatic tracking (High-End Tactile Double-Bezel)
              TactilePrimaryButton(
                label: 'Enable Automatic Tracking',
                leadingIcon: LucideIcons.radio,
                isLoading: _isRequestingPermission,
                onPressed: _handleEnableTracking,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _isRequestingPermission
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _goToMainScreen();
                      },
                child: const Text('Skip for now (Manual tracking)',
                    style: TextStyle(
                        color: AppColors.muted, fontWeight: FontWeight.w700)),
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
