import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const double barContentHeight = 64;
  static const double barBottomGap = 0;
  static double clearanceFor(BuildContext context, {TaxMethod? taxMethod}) =>
      16;

  @override
  Widget build(BuildContext context) {
    const destinations = <(String, IconData)>[
      ('Home', AppIcons.home),
      ('Review', Icons.fact_check_outlined),
      ('Records', AppIcons.trips),
      ('Pack', AppIcons.tax),
    ];

    return Material(
      color: AppColor.surface,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: barContentHeight),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const BoxDecoration(
            color: AppColor.surface,
            border: Border(top: BorderSide(color: AppColor.hairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _destination(context, destinations[0], 0)),
              Expanded(child: _destination(context, destinations[1], 1)),
              Expanded(child: _captureAction(context)),
              Expanded(child: _destination(context, destinations[2], 2)),
              Expanded(child: _destination(context, destinations[3], 3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destination(
      BuildContext context, (String, IconData) destination, int index) {
    final selected = currentIndex == index;
    return Semantics(
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTabSelected(index);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? AppColor.brandTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(destination.$2,
                    size: 22,
                    color: selected ? AppColor.brand : AppColor.inkMuted),
              ),
              const SizedBox(height: 2),
              Text(
                destination.$1,
                textAlign: TextAlign.center,
                style: AppType.navLabel.copyWith(
                    height: 1.3,
                    color: selected ? AppColor.brand : AppColor.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _captureAction(BuildContext context) {
    const semanticsLabel = 'Capture';
    const iconData = Icons.add;

    return Semantics(
      label: semanticsLabel,
      onTap: () {
        HapticFeedback.mediumImpact();
        onCenterActionTap();
      },
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.mediumImpact();
          onCenterActionTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: AppColor.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: AppColor.onNavy, size: 22),
            ),
            const SizedBox(height: 2),
            Text('Capture',
                textAlign: TextAlign.center,
                style: AppType.navLabel
                    .copyWith(height: 1.3, color: AppColor.brand)),
          ]),
        ),
      ),
    );
  }
}
