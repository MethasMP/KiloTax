import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';
import '../../../services/tracking/location_permission_service.dart';
import '../auth/sign_in_screen.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';
import 'widgets/permission_preprompt_screen.dart';

class OnboardingFlowScreen extends StatefulWidget {
  final int initialStep;
  const OnboardingFlowScreen({super.key, this.initialStep = 0});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late int _currentStep;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
  }

  Future<void> _handleRequestPermissions() async {
    final locationService = LocationPermissionService();
    final permission = await locationService.requestForegroundPermission();
    if (permission == AppLocationPermissionStatus.grantedForeground) {
      await locationService.requestBackgroundEscalation();
    }

    if (mounted) {
      setState(() => _currentStep = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.hasVehicle) {
      return const MainScaffoldScreen();
    }

    if (_currentStep == 0) {
      return OnboardingSlidesScreen(onComplete: () {
        setState(() => _currentStep = appState.isAuthenticated ? 2 : 1);
        unawaited(appState.completeOnboarding());
      });
    }

    if (_currentStep == 1 && !appState.isAuthenticated) {
      return SignInScreen(
        onAuthSuccess: () {
          if (mounted) {
            setState(() => _currentStep = 2);
          }
        },
        onContinueAsGuest: () {
          if (mounted) {
            setState(() => _currentStep = 2);
          }
        },
      );
    }

    if (_currentStep == 2) {
      return PermissionPrepromptScreen(
        onEnableTracking: _handleRequestPermissions,
        onSkipOrManual: () {
          if (mounted) setState(() => _currentStep = 3);
        },
      );
    }

    return VehicleSetupFlow(
      includeBluetoothSetup: false,
      onCancel: () {
        setState(() => _currentStep = 0);
      },
      onVehicleCreated: (vehicle) async {
        await appState.completeOnboarding();
        await appState.addVehicle(vehicle);
      },
    );
  }
}
