import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'state/app_state.dart';
import 'ui/screens/onboarding/vehicle_onboarding_screen.dart';
import 'ui/screens/dashboard/tax_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const KiloTaxApp(),
    ),
  );
}

class KiloTaxApp extends StatelessWidget {
  const KiloTaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiloTax',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.workBlue,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, _) {
          if (!appState.hasVehicle) {
            return const VehicleOnboardingScreen();
          }
          return const TaxDashboardScreen();
        },
      ),
    );
  }
}
