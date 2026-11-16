import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';
import '../../../services/tracking/location_permission_service.dart';
import '../auth/sign_in_screen.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';
import 'widgets/permission_preprompt_screen.dart';

/// Production-Grade EDE v2.0 Golden Onboarding Journey
///
/// Flow Order:
/// 1. Welcome / Value Hook (`OnboardingSlidesScreen`)
/// 2. 1-Tap Biometric Authentication (`SignInScreen`)
/// 3. OS Permission Soft-Prompt (`PermissionPrepromptScreen`) -> Foreground & Background Location
/// 4. Vehicle Setup (`VehicleSetupFlow`) -> Persists immediately to Cloud
/// 5. Home Dashboard (`MainScaffoldScreen`)
class OnboardingFlowScreen extends StatefulWidget {
  final int initialStep;
  const OnboardingFlowScreen({super.key, this.initialStep = 0});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  // Step 0: Welcome slides
  // Step 1: Sign in
  // Step 2: Permission pre-prompt
  // Step 3: Vehicle setup
  late int _currentStep;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
  }

  Future<void> _handleRequestPermissions() async {
    final locationService = LocationPermissionService();
    // 1. Request foreground first (Phase 1)
    await locationService.requestForegroundPermission();
    // 2. Request background escalation (Phase 2 - Always Allow)
    await locationService.requestBackgroundEscalation();

    if (mounted) {
      setState(() => _currentStep = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Terminal condition: User already has vehicle setup
    if (appState.hasVehicle) {
      return const MainScaffoldScreen();
    }

    // Step 0: Welcome slides (Value Hook)
    if (_currentStep == 0) {
      return OnboardingSlidesScreen(onComplete: () async {
        await appState.completeOnboarding();
        if (mounted) {
          // If already authenticated (e.g. returning user), skip directly to permissions/vehicle
          if (appState.isAuthenticated) {
            setState(() => _currentStep = 2);
          } else {
            setState(() => _currentStep = 1);
          }
        }
      });
    }

    // Step 1: Mandatory 1-Tap Biometric Sign In (Apple / Google)
    if (_currentStep == 1 && !appState.isAuthenticated) {
      return SignInScreen(
        onAuthSuccess: () {
          if (mounted) {
            setState(() => _currentStep = 2);
          }
        },
        onContinueAsGuest: () {
          // Fallback path if requested, seamlessly transitions forward
          if (mounted) {
            setState(() => _currentStep = 2);
          }
        },
      );
    }

    // Step 2: Permission Pre-prompt (Apple Guideline 5.1.1 Compliant Soft Prompt)
    if (_currentStep == 2) {
      return PermissionPrepromptScreen(
        onEnableTracking: _handleRequestPermissions,
        onSkipOrManual: () {
          if (mounted) setState(() => _currentStep = 3);
        },
      );
    }

    // Step 3: Vehicle Setup (Data saved to cloud with verified auth user)
    return VehicleSetupFlow(
      includeBluetoothSetup: false,
      onCancel: () {
        setState(() => _currentStep = 0);
      },
      onVehicleCreated: (vehicle) async {
        await appState.completeOnboarding();
        await appState.addVehicle(vehicle);
        // appState.hasVehicle will now be true, triggering navigation to MainScaffoldScreen
      },
    );
  }
}
