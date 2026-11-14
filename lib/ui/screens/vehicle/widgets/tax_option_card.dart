import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/vehicle.dart';

class TaxOptionCard extends StatelessWidget {
  final TaxMethod method;
  final bool isSelected;
  final VoidCallback onSelect;

  const TaxOptionCard({
    super.key,
    required this.method,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final description = switch (method) {
      TaxMethod.logbook => 'Record work use and vehicle expenses.',
      TaxMethod.centsPerKm =>
        'Record work kilometres, up to 5,000 km per year.',
      TaxMethod.actualExpenses =>
        'Record expenses and business use for your commercial vehicle.',
    };
    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect();
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColor.ink : AppColor.line,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                    child: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 24,
                  color: isSelected ? AppColor.ink : AppColor.inkSubtle,
                )),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColor.ink)),
                    const SizedBox(height: 8),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColor.inkMuted)),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
