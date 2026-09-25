import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/vehicle.dart';

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

  @override
  Widget build(BuildContext context) {
    final isCpk = taxMethod == TaxMethod.centsPerKm;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final effectiveBottom = bottomPadding > 0 ? bottomPadding : 16.0;
    final totalBarHeight = 66.0 + effectiveBottom + 8.0;

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
                height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                boxShadow: [
                  // Layer 1: Ambient soft aura
                  BoxShadow(
                    color: AppColors.deepNavy.withValues(alpha: 0.10),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                    spreadRadius: 0,
                  ),
                  // Layer 2: Tight ground contact shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(33),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
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
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Dashboard',
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: Icons.directions_car_outlined,
            activeIcon: Icons.directions_car_filled_rounded,
            label: 'Trips',
            isSelected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
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
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Home',
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: Icons.directions_car_outlined,
            activeIcon: Icons.directions_car_filled_rounded,
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
            icon: Icons.receipt_outlined,
            activeIcon: Icons.receipt_rounded,
            label: 'Expenses',
            isSelected: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
        ),
        Expanded(
          child: _NavBarItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
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
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.heavyImpact();
          onTap();
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.deepNavy,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.deepNavy.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(LucideIcons.plus, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.deepNavy : AppColors.muted;
    final displayIcon = (isSelected && activeIcon != null) ? activeIcon! : icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.deepNavy.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    displayIcon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

