import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/vehicle.dart';

class ScaffoldBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCenterActionTap;
  final TaxMethod taxMethod;
  const ScaffoldBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCenterActionTap,
    this.taxMethod = TaxMethod.centsPerKm,
  });

  static const double barContentHeight = 80;
  static const double barBottomGap = 0;
  static double clearanceFor(BuildContext context, {TaxMethod? taxMethod}) =>
      16;

  @override
  Widget build(BuildContext context) {
    final isCpk = taxMethod == TaxMethod.centsPerKm;
    final destinations = <(String, IconData)>[
      ('Home', AppIcons.home),
      ('Trips', AppIcons.trips),
      if (!isCpk) ('Expenses', AppIcons.expenses),
      ('Tax', AppIcons.tax),
    ];
    return Material(
      color: AppColor.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          constraints: const BoxConstraints(minHeight: barContentHeight),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColor.hairline)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i <= destinations.length; i++)
              if (i == 2)
                Expanded(child: _capture())
              else
                Expanded(
                    child: _destination(
                        destinations[i < 2 ? i : i - 1], i < 2 ? i : i - 1)),
          ]),
        ),
      ),
    );
  }

  Widget _destination((String, IconData) destination, int index) {
    final selected = currentIndex == index;
    return Semantics(
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTabSelected(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AppColor.brandTint : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(destination.$2,
                  size: 23,
                  color: selected ? AppColor.brand : AppColor.inkMuted),
            ),
            const SizedBox(height: 4),
            Text(destination.$1,
                textAlign: TextAlign.center,
                style: AppType.navLabel.copyWith(
                    height: 1.3,
                    color: selected ? AppColor.brand : AppColor.inkMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _capture() => Semantics(
        label: taxMethod == TaxMethod.logbook
            ? 'Capture a receipt or trip'
            : 'Capture a trip',
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: onCenterActionTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 48,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColor.brand,
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.document_scanner_outlined,
                    color: AppColor.onNavy, size: 24),
              ),
              const SizedBox(height: 4),
              Text('Capture',
                  textAlign: TextAlign.center,
                  style: AppType.navLabel
                      .copyWith(height: 1.3, color: AppColor.brand)),
            ]),
          ),
        ),
      );
}
