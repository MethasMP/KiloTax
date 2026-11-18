import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'state/app_state.dart';
import 'ui/screens/onboarding/onboarding_flow_screen.dart';
import 'ui/screens/home/main_scaffold_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
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
    if (appState.hasVehicle) {
      return const MainScaffoldScreen();
    }
    if (!appState.isAuthenticated && !appState.isGuestMode) {
      return const OnboardingFlowScreen(initialStep: 0);
    }
    if (appState.hasSeenOnboarding) {
      return const OnboardingFlowScreen(initialStep: 2);
    }
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
      theme: AppTheme.light,
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
