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
        const Text(
          'What was this trip for?',
          style: AppTextStyles.cardPrimary,
        ),
        const SizedBox(height: 12),

        _buildOption(
          label: 'Client Site',
          icon: LucideIcons.briefcase,
          isSelected: selectedPurpose == 'Client Site' || selectedPurpose == 'Client / Job',
          onTap: () => onPurposeSelected('Client Site'),
        ),
        const SizedBox(height: 10),

        _buildOption(
          label: 'Supplies Run',
          icon: LucideIcons.shoppingCart,
          isSelected: selectedPurpose == 'Supplies Run' || selectedPurpose == 'Trade Supplies / Bunnings',
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
            color: isSelected ? activeColor.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? activeColor : AppColors.muted),
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
                Icon(Icons.check_circle_rounded, size: 18, color: activeColor)
              else
                const Icon(Icons.circle_outlined, size: 18, color: AppColors.border),
            ],
          ),
        ),
      ),
    );
  }
}
