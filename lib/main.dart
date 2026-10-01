import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'state/app_state.dart';
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
    // 1. Configured vehicle exists (Guest local mode or Authenticated) -> Main Dashboard
    if (appState.hasVehicle) {
      return const MainScaffoldScreen();
    }
    // 2. Vehicle chosen, but still needs to complete Value-First Gate or GPS setup
    if (appState.primaryVehicle != null && !appState.hasVehicle) {
      return const OnboardingFlowScreen(initialStep: 2);
    }
    // 3. Has already seen intro slides but no vehicle yet -> Value-First Vehicle Setup (Step 1)
    if (appState.hasSeenOnboarding) {
      return const OnboardingFlowScreen(initialStep: 1);
    }
    // 4. Fresh first-time launch -> Onboarding slides (Step 0)
    return const OnboardingFlowScreen(initialStep: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiloTax',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'AU'),
      supportedLocales: const [
        Locale('en', 'AU'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
