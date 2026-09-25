import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'state/app_state.dart';
import 'ui/screens/auth/sign_in_screen.dart';
import 'ui/screens/onboarding/onboarding_flow_screen.dart';
import 'ui/screens/home/main_scaffold_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppConstants.supabaseAnonKey,
  );
  final appState = AppState();
  await appState.init();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const KiloTaxApp(),
    ),
  );
}

class KiloTaxApp extends StatelessWidget {
  const KiloTaxApp({super.key});

  Widget _resolveRootScreen(AppState appState) {
    // 1. Authenticated with configured vehicle -> Main Dashboard
    if (appState.isAuthenticated && appState.hasVehicle) {
      return const MainScaffoldScreen();
    }
    // 2. Authenticated but no vehicle configured -> Resume vehicle setup
    if (appState.isAuthenticated && !appState.hasVehicle) {
      return const OnboardingFlowScreen(initialStep: 2);
    }
    // 3. Not authenticated, but has already seen slides (e.g. after Sign Out) -> Pure Sign In Screen
    if (appState.hasSeenOnboarding) {
      return const SignInScreen();
    }
    // 4. Fresh first-time launch -> Onboarding slides
    return const OnboardingFlowScreen(initialStep: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiloTax',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.deepNavy,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Consumer<AppState>(
            builder: (context, appState, _) => _resolveRootScreen(appState),
          ),
          settings: settings,
        );
      },
      home: Consumer<AppState>(
        builder: (context, appState, _) => _resolveRootScreen(appState),
      ),
    );
  }
}
