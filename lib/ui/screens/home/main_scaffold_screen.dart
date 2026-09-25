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

/// Spec #16 & UI.png Master Navigation Scaffold:
/// Adaptive Architecture:
/// - CPK (3 tabs): Dashboard (0), Trips Ledger (1), Tax D1 (2)
/// - Logbook (4 tabs + center FAB): Home (0), Trips (1), Expenses (2), Tax (3)
class MainScaffoldScreen extends StatefulWidget {
  const MainScaffoldScreen({super.key});

  @override
  State<MainScaffoldScreen> createState() => _MainScaffoldScreenState();
}

class _MainScaffoldScreenState extends State<MainScaffoldScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final taxMethod = appState.primaryVehicle?.taxMethod ?? TaxMethod.centsPerKm;
    final isCpk = taxMethod == TaxMethod.centsPerKm;

    // Polymorphic screen lists:
    // CPK: 3 screens (Zero Expenses/Receipts confusion, 100% passive deduction ledger)
    // Logbook: 4 screens (Requires expenses & fuel substantiation)
    final screens = isCpk
        ? [
            const EvidenceHomeScreen(),
            TripsLedgerTab(appState: appState),
            const TaxSummaryScreen(),
          ]
        : [
            const EvidenceHomeScreen(),
            TripsLedgerTab(appState: appState),
            const EvidenceExpensesScreen(),
            const TaxSummaryScreen(),
          ];

    // Ensure index bounds safety if switching vehicles
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: ScaffoldBottomNavBar(
        currentIndex: safeIndex,
        taxMethod: taxMethod,
        onTabSelected: (index) => setState(() => _currentIndex = index),
        onCenterActionTap: () => QuickCaptureBottomSheet.show(context, appState),
      ),
    );
  }
}
