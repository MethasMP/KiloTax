import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../dashboard/evidence_home_screen.dart';
import '../expenses/evidence_expenses_screen.dart';
import '../tax/tax_summary_screen.dart';
import '../evidence/evidence_review_screen.dart';
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
  int _reviewRequest = 0;
  final _recordsBodyKey = GlobalKey();
  String? _packVehicleId;
  String? _packYear;
  int _packRequest = 0;
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
      final recordsContext = _recordsBodyKey.currentContext;
      if (recordsContext != null) {
        DefaultTabController.maybeOf(recordsContext)?.animateTo(0);
      }
      setState(() {
        _tripsFilter = filter;
        _tripsVehicleId = appState.primaryVehicle?.id;
        _tripsFinancialYear = appState.activeTaxRule.financialYear;
        _tripsRequest++;
        _destination = 'records';
      });
    }

    void openPack() => setState(() {
          _packVehicleId = appState.primaryVehicle?.id;
          _packYear = appState.activeTaxRule.financialYear;
          _packRequest++;
          _destination = 'pack';
        });
    final screens = <Widget>[
      EvidenceHomeScreen(
        onViewAll: () => switchToTripsTab(),
        onReviewTrips: () => setState(() {
          _reviewRequest++;
          _destination = 'review';
        }),
        onViewTax: openPack,
      ),
      EvidenceReviewScreen(
          appState: appState,
          vehicleId: appState.primaryVehicle?.id,
          financialYear: appState.activeTaxRule.financialYear,
          onOpenPack: openPack,
          allPendingRequest: _reviewRequest),
      DefaultTabController(
          length: isCpk ? 1 : 2,
          child: Column(key: _recordsBodyKey, children: [
            SafeArea(
                bottom: false,
                child: TabBar(tabs: [
                  const Tab(text: 'Trips'),
                  if (!isCpk) const Tab(text: 'Expenses')
                ])),
            Expanded(
                child: TabBarView(children: [
              _KeepAliveRecordTab(
                  child: TripsLedgerTab(
                      key: ValueKey(_tripsRequest),
                      appState: appState,
                      initialFilter: _tripsFilter,
                      initialVehicleId: _tripsVehicleId,
                      financialYear: _tripsFinancialYear)),
              if (!isCpk)
                const _KeepAliveRecordTab(child: EvidenceExpensesScreen()),
            ])),
          ])),
      TaxSummaryScreen(
          onViewTrips: () => switchToTripsTab(),
          initialVehicleId: _packVehicleId,
          initialFinancialYear: _packYear,
          scopeRequest: _packRequest),
    ];
    const destinations = ['home', 'review', 'records', 'pack'];
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

class _KeepAliveRecordTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveRecordTab({required this.child});
  @override
  State<_KeepAliveRecordTab> createState() => _KeepAliveRecordTabState();
}

class _KeepAliveRecordTabState extends State<_KeepAliveRecordTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
