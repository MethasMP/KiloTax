import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../auth/sign_in_screen.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';

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
    } catch (_) {}
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
    } catch (_) {}
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
      return SignInScreen(
        onAuthSuccess: () {
          final appState = context.read<AppState>();
          if (appState.hasVehicle) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScaffoldScreen()),
            );
          } else {
            setState(() => _step = 2);
          }
        },
      );
    }

    // STEP 2: Vehicle Setup is fully decoupled into VehicleSetupFlow
    if (_step == 2) {
      return VehicleSetupFlow(
        onVehicleCreated: (vehicle) {
          final appState = context.read<AppState>();
          appState.addVehicle(vehicle);
          setState(() => _step = 3);
        },
        onCancel: () => setState(() => _step = 1),
      );
    }

    // STEP 3: Explain Context & Enable Automatic Trip Tracking (Spec Items 10 & 11)
    return _buildGpsPermissionAndReadyScreen();
  }

  Widget _buildGpsPermissionAndReadyScreen() {
    final appState = context.watch<AppState>();
    final vehicle = appState.primaryVehicle;
    final isLogbook = vehicle?.taxMethod == TaxMethod.logbook;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.workBlueLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.workBlue.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(LucideIcons.navigation, color: AppColors.workBlue, size: 44),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Automatically detect\nyour work trips',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink, height: 1.25),
              ),
              const SizedBox(height: 12),
              const Text(
                'We use background location to automatically detect when you drive and log your trips for ATO tax substantiation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 24),

              // Summary card of the setup done
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
                      children: [
                        const Icon(LucideIcons.car, size: 18, color: AppColors.deepNavy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            vehicle?.displayName ?? 'Your Vehicle',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 18),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.border),
                    Row(
                      children: [
                        Icon(isLogbook ? LucideIcons.bookOpen : LucideIcons.gauge, size: 18, color: AppColors.emerald),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isLogbook ? 'Logbook Method (12-Week Active)' : 'Cents per kilometre (Up to 5,000 km)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Primary Action: Enable automatic tracking
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.radio, size: 20),
                label: const Text('Enable Automatic Tracking', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainScaffoldScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainScaffoldScreen()),
                  );
                },
                child: const Text('Skip for now (Manual tracking)', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
