import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../cpk/cpk_home_body.dart';
import '../logbook/logbook_home_body.dart';

/// Screen 5 & 6 Polymorphic Router:
/// Routes to dedicated [CpkHomeBody] or [LogbookHomeBody] based on vehicle tax strategy.
/// Zero cross-contamination, 100% clean domain boundary.
class EvidenceHomeScreen extends StatelessWidget {
  const EvidenceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isLogbook
            ? LogbookHomeBody(appState: appState)
            : CpkHomeBody(appState: appState),
      ),
    );
  }
}
