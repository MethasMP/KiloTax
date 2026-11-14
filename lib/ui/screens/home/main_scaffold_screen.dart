import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../dashboard/evidence_home_screen.dart';
import '../expenses/evidence_expenses_screen.dart';
import '../tax/tax_summary_screen.dart';
import 'widgets/quick_capture_bottom_sheet.dart';
import 'widgets/scaffold_bottom_nav_bar.dart';
import 'widgets/trips_ledger_tab.dart';

class MainScaffoldScreen extends StatefulWidget {
  const MainScaffoldScreen({super.key});

  @override
  State<MainScaffoldScreen> createState() => _MainScaffoldScreenState();
}

class _MainScaffoldScreenState extends State<MainScaffoldScreen> {
  String _destination = 'home';
  late final AppLifecycleListener _lifecycle;
  bool _checkingReview = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkWeeklyReview);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWeeklyReview());
  }

  Future<void> _checkWeeklyReview() async {
    if (!mounted || _checkingReview) return;
    _checkingReview = true;
    try {
      try {
        await context.read<AppState>().refreshLocationPermission();
      } catch (error) {
        debugPrint('Could not refresh location status: $error');
      }
      if (!mounted) return;
      await context.read<AppState>().evaluateWeeklyEvidenceReview();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Could not prepare weekly review: $error');
    } finally {
      _checkingReview = false;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final taxMethod =
        appState.primaryVehicle?.taxMethod ?? TaxMethod.centsPerKm;
    final isCpk = taxMethod == TaxMethod.centsPerKm;

    void switchToTripsTab() {
      setState(() => _destination = 'trips');
    }

    // Polymorphic screen lists:
    // CPK: 3 screens (Zero Expenses/Receipts confusion, 100% passive deduction ledger)
    // Logbook: 4 screens (Requires expenses & fuel substantiation)
    final screens = isCpk
        ? [
            EvidenceHomeScreen(onViewAll: switchToTripsTab),
            TripsLedgerTab(appState: appState),
            const TaxSummaryScreen(),
          ]
        : [
            EvidenceHomeScreen(onViewAll: switchToTripsTab),
            TripsLedgerTab(appState: appState),
            const EvidenceExpensesScreen(),
            const TaxSummaryScreen(),
          ];

    final destinations =
        isCpk ? ['home', 'trips', 'tax'] : ['home', 'trips', 'expenses', 'tax'];
    if (!destinations.contains(_destination)) _destination = 'home';
    final safeIndex = destinations.indexOf(_destination);

    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: ScaffoldBottomNavBar(
        currentIndex: safeIndex,
        taxMethod: taxMethod,
        onTabSelected: (index) =>
            setState(() => _destination = destinations[index]),
        onCenterActionTap: () =>
            QuickCaptureBottomSheet.show(context, appState),
      ),
    );
  }
}
