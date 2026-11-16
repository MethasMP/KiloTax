import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';
import 'widgets/value_first_gate_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';
import 'widgets/value_first_gate_screen.dart';

/// Vehicle setup leads to an optional account connection before entering Home.
class OnboardingFlowScreen extends StatefulWidget {
  final int initialStep;
  const OnboardingFlowScreen({super.key, this.initialStep = 0});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late bool _showWelcome = widget.initialStep == 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.hasVehicle) return const MainScaffoldScreen();
    if (_showWelcome) {
      return OnboardingSlidesScreen(onComplete: () async {
        await appState.completeOnboarding();
        if (mounted) setState(() => _showWelcome = false);
      });
    }
    return VehicleSetupFlow(
      includeBluetoothSetup: true,
      onCancel: () => setState(() => _showWelcome = true),
      onVehicleCreated: (vehicle) async {
        if (!appState.isAuthenticated) {
          final navigator = Navigator.of(context);
          // Keep the account choice above the root, which becomes Home on save.
          navigator.push(MaterialPageRoute<void>(
            builder: (_) => ValueFirstGateScreen(
              vehicle: vehicle,
              onContinue: () => navigator.pop(),
            ),
          ));
        }
        await appState.completeOnboarding();
        await appState.addVehicle(vehicle);
      },
    );
  }
}
