import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_space.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';

class TripPurposeSelector extends StatelessWidget {
  final String selectedPurpose;
  final bool isLogbook;
  final ValueChanged<String> onPurposeSelected;

  const TripPurposeSelector({
    super.key,
    required this.selectedPurpose,
    required this.isLogbook,
    required this.onPurposeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What was this trip for?',
          style: isLogbook ? AppType.section : AppTextStyles.cardPrimary,
        ),
        const SizedBox(height: 12),

        _buildOption(
          label: 'Client Site',
          icon: AppIcons.business,
          isSelected: selectedPurpose == 'Client Site' ||
              selectedPurpose == 'Client / Job',
          onTap: () => onPurposeSelected('Client Site'),
        ),
        const SizedBox(height: 10),

        _buildOption(
          label: 'Supplies Run',
          icon: LucideIcons.shoppingCart,
          isSelected: selectedPurpose == 'Supplies Run' ||
              selectedPurpose == 'Trade Supplies / Bunnings',
          onTap: () => onPurposeSelected('Supplies Run'),
        ),
        const SizedBox(height: 10),

        _buildOption(
          label: 'Tool Transport',
          icon: LucideIcons.hammer,
          isSelected: selectedPurpose == 'Tool Transport' ||
              selectedPurpose == 'Heavy Tools & Equipment' ||
              selectedPurpose == 'Carrying Heavy Tools' ||
              selectedPurpose == 'Work Site (Bulky Tools Carried)',
          onTap: () => onPurposeSelected('Tool Transport'),
        ),

        // Personal Journey Option (Visible strictly for Logbook Method)
        if (isLogbook) ...[
          const SizedBox(height: 10),
          _buildOption(
            label: 'Personal',
            icon: LucideIcons.home,
            isSelected: selectedPurpose == 'Personal',
            onTap: () => onPurposeSelected('Personal'),
            isPersonal: true,
          ),
        ],
      ],
    );
  }

  Widget _buildOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isPersonal = false,
  }) {
    if (isLogbook) {
      return Semantics(
          button: true,
          selected: isSelected,
          child: Material(
            color: isSelected ? AppColor.brandTint : AppColor.surface,
            shape: RoundedRectangleBorder(
                borderRadius: R.controlR,
                side: BorderSide(
                    color: isSelected ? AppColor.ink : AppColor.hairline)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Padding(
                  padding: const EdgeInsets.all(S.lg),
                  child: Row(children: [
                    Icon(icon,
                        size: AppIconSize.control, color: AppColor.inkMuted),
                    const SizedBox(width: S.md),
                    Expanded(
                        child: Text(label,
                            style: isSelected
                                ? AppType.bodyStrong
                                : AppType.body)),
                    const SizedBox(width: S.sm),
                    Icon(isSelected ? AppIcons.selected : AppIcons.unselected,
                        size: AppIconSize.control,
                        color: isSelected ? AppColor.ink : AppColor.inkSubtle),
                  ])),
            ),
          ));
    }
    final activeColor = isPersonal ? AppColors.muted : AppColors.deepNavy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:
                isSelected ? activeColor.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: AppIconSize.control,
                  color: isSelected ? activeColor : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14.5,
                    color: isSelected ? activeColor : AppColors.ink,
                  ),
                ),
              ),
              if (isSelected)
                Icon(AppIcons.selected,
                    size: AppIconSize.control, color: activeColor)
              else
                const Icon(AppIcons.unselected,
                    size: AppIconSize.control, color: AppColors.border),
            ],
          ),
        ),
      ),
    );
  }
}
