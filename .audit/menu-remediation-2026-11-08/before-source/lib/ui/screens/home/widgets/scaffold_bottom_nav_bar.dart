import '../../../../core/theme/app_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../core/theme/app_color.dart';

/// Spec: Dynamic Floating Island Tab Bar (Architect Standard)
/// Features:
/// 1. Dual-elevation ambient drop shadows for separation from scrolling feed
/// 2. 24px Frosted Glass BackdropFilter (0.88 opacity slate surface)
/// 3. Subtle specular rim light border (1px)
/// 4. Adaptive geometry: Compact 3-tab pill for CPK vs 4-tab + Hero FAB for Logbook
/// 5. Ergonomic 48-52pt hit-target slop to eliminate dead-zone ghost taps
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

  /// Height of the floating pill itself, excluding the bottom safe inset.
  static const double barContentHeight = 66.0;

  /// Breathing room between the pill and the bottom safe inset.
  static const double barBottomGap = 8.0;

  /// Bottom padding a scroll view needs so its last row clears the floating
  /// bar. Derived from the real geometry: the bar's height varies with the
  /// device's bottom inset, so a hardcoded 120 both wasted space on some
  /// devices and trapped content on others.
  static double clearanceFor(BuildContext context) =>
      barContentHeight +
      barBottomGap +
      MediaQuery.of(context).padding.bottom +
      16.0;

  @override
  Widget build(BuildContext context) {
    final isCpk = taxMethod == TaxMethod.centsPerKm;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final effectiveBottom = bottomPadding > 0 ? bottomPadding : 16.0;
    final totalBarHeight = barContentHeight + effectiveBottom + barBottomGap;

    return SizedBox(
      height: totalBarHeight,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: Container(
          color: Colors.transparent,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: effectiveBottom,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCpk ? 340 : 420,
              ),
              child: Container(
                height: barContentHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(33),
                  boxShadow: [
                    // Layer 1: Ambient soft linen aura
                    BoxShadow(
                      color: AppColors.deepNavy.withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                    // Layer 2: Tight ground contact shadow
                    BoxShadow(
                      color: AppColor.ink.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(33),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(33),
                        border: Border.all(
                          color: AppColor.hairline.withValues(alpha: 0.90),
                          width: 1.2,
                        ),
                      ),
                      child: isCpk ? _buildCpkNav() : _buildLogbookNav(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 3-Tab Lean Auto-CPK Navigation: Dashboard, Trips, Tax
  Widget _buildCpkNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _NavBarItem(
            icon: AppIcons.dashboard,
            label: 'Dashboard',
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: AppIcons.trips,
            label: 'Trips',
            isSelected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: AppIcons.tax,
            label: 'Tax',
            isSelected: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
        ),
      ],
    );
  }

  /// Standard 4-Tab + Center Button Navigation for 12-Week Logbook Method
  Widget _buildLogbookNav() {
    return Row(
      children: [
        Expanded(
          child: _NavBarItem(
            icon: AppIcons.home,
            label: 'Home',
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: AppIcons.trips,
            label: 'Trips',
            isSelected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
        ),
        Expanded(
          child: CenterCaptureButton(
            onTap: onCenterActionTap,
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: AppIcons.expenses,
            label: 'Expenses',
            isSelected: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: AppIcons.tax,
            label: 'Tax',
            isSelected: currentIndex == 3,
            onTap: () => onTabSelected(3),
          ),
        ),
      ],
    );
  }
}

class CenterCaptureButton extends StatelessWidget {
  final VoidCallback onTap;

  const CenterCaptureButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // The app's primary action was a bare GestureDetector: unnamed and
    // role-less for assistive tech, and only exactly 48dp with no slop.
    return Semantics(
      button: true,
      label: 'Log a trip or add an expense',
      excludeSemantics: true,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.heavyImpact();
            onTap();
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColor.surfaceNavy,
              border: Border.all(
                color: AppColor.navyLine,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColor.surfaceNavy.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(AppIcons.add,
                color: Colors.white, size: AppIconSize.control),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColor.ink;
    final inactiveColor = AppColor.inkSubtle;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(22),
          splashColor: AppColor.ink.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color:
                          isSelected ? AppColor.brandTint : Colors.transparent,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon,
                      color: isSelected ? activeColor : inactiveColor,
                      size: AppIconSize.navigation),
                ),
                const SizedBox(height: 3),
                // The bar has a fixed height, so the label must never wrap.
                // Scaling is capped too: nav labels are supplementary, and at
                // 200% they would truncate to a single letter anyway.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
