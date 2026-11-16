import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';
import 'widgets/value_first_gate_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/trade_persona.dart';
import '../../../state/app_state.dart';
import '../home/main_scaffold_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'onboarding_slides_screen.dart';
import 'widgets/trade_persona_selector_sheet.dart';
import 'widgets/value_first_gate_screen.dart';

enum OnboardingStep {
  welcome,
  tradePersona,
  vehicleSetup,
}

/// Vehicle setup leads to an optional account connection before entering Home.
class OnboardingFlowScreen extends StatefulWidget {
  final int initialStep;
  const OnboardingFlowScreen({super.key, this.initialStep = 0});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late OnboardingStep _currentStep =
      widget.initialStep == 0 ? OnboardingStep.welcome : OnboardingStep.tradePersona;
  TradePersona _selectedPersona = TradePersona.sparky;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.hasVehicle) return const MainScaffoldScreen();

    switch (_currentStep) {
      case OnboardingStep.welcome:
        return OnboardingSlidesScreen(onComplete: () {
          setState(() => _currentStep = OnboardingStep.tradePersona);
        });

      case OnboardingStep.tradePersona:
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => setState(() => _currentStep = OnboardingStep.welcome),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: TradePersonaSelectorSheet(
                        selectedPersona: _selectedPersona,
                        onPersonaSelected: (persona) {
                          setState(() => _selectedPersona = persona);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final currentProfile = appState.userProfile;
                        await appState.updateUserProfile(
                          currentProfile.copyWith(tradePersona: _selectedPersona),
                        );
                        if (mounted) {
                          setState(() => _currentStep = OnboardingStep.vehicleSetup);
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue to Vehicle',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );

      case OnboardingStep.vehicleSetup:
        return VehicleSetupFlow(
          includeBluetoothSetup: true,
          onCancel: () => setState(() => _currentStep = OnboardingStep.tradePersona),
          onVehicleCreated: (vehicle) async {
            if (!appState.isAuthenticated) {
              final navigator = Navigator.of(context);
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
}
