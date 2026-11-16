import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../dashboard/evidence_home_screen.dart';
import '../expenses/evidence_expenses_screen.dart';
import '../tax/tax_summary_screen.dart';
import '../expenses/scan_receipt_screen.dart';
import 'widgets/scaffold_bottom_nav_bar.dart';
import 'widgets/trips_ledger_tab.dart';

class MainScaffoldScreen extends StatefulWidget {
  const MainScaffoldScreen({super.key});

  @override
  State<MainScaffoldScreen> createState() => _MainScaffoldScreenState();
}

class _MainScaffoldScreenState extends State<MainScaffoldScreen> {
  String _destination = 'home';
  String _tripsFilter = 'All';
  String? _tripsVehicleId;
  String? _tripsFinancialYear;
  int _tripsRequest = 0;
  String? _lastPrimaryVehicleId;
  String? _lastFinancialYear;
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
    if (_lastPrimaryVehicleId != appState.primaryVehicle?.id ||
        _lastFinancialYear != appState.activeTaxRule.financialYear) {
      _lastPrimaryVehicleId = appState.primaryVehicle?.id;
      _lastFinancialYear = appState.activeTaxRule.financialYear;
      _tripsVehicleId = null;
      _tripsFinancialYear = null;
      _tripsFilter = 'All';
      _tripsRequest++;
    }

    void switchToTripsTab({String filter = 'All'}) {
      setState(() {
        _tripsFilter = filter;
        _tripsVehicleId = appState.primaryVehicle?.id;
        _tripsFinancialYear = appState.activeTaxRule.financialYear;
        _tripsRequest++;
        _destination = 'trips';
      });
    }

    final home = EvidenceHomeScreen(
      onViewAll: () => switchToTripsTab(),
      onReviewTrips: () => switchToTripsTab(filter: 'Needs review'),
      onViewTax: () => setState(() => _destination = 'tax'),
    );
    final trips = TripsLedgerTab(
      key: ValueKey(_tripsRequest),
      appState: appState,
      initialFilter: _tripsFilter,
      initialVehicleId: _tripsVehicleId,
      financialYear: _tripsFinancialYear,
    );

    // Polymorphic screen lists:
    // CPK: 3 screens (Zero Expenses/Receipts confusion, 100% passive deduction ledger)
    // Logbook: 4 screens (Requires expenses & fuel substantiation)
    final screens = isCpk
        ? [
            home,
            trips,
            TaxSummaryScreen(onViewTrips: () => switchToTripsTab()),
          ]
        : [
            home,
            trips,
            const EvidenceExpensesScreen(),
            TaxSummaryScreen(onViewTrips: () => switchToTripsTab()),
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
        onCenterActionTap: () => ScanReceiptScreen.show(context, appState),
      ),
    );
  }
}
