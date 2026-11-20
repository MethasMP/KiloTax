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
                Expanded(child: _scan(context))
              else
                Expanded(
                    child: _destination(
                        context,
                        destinations[i < 2 ? i : i - 1],
                        i < 2 ? i : i - 1)),
          ]),
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
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

  Widget _scan(BuildContext context) => Semantics(
        label: 'Scan receipt',
        onTap: () {
          HapticFeedback.mediumImpact();
          onCenterActionTap();
        },
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onCenterActionTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColor.brandBright,
                        AppColor.brand,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.brand.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: AppColor.onNavy,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.navLabel.copyWith(
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColor.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
