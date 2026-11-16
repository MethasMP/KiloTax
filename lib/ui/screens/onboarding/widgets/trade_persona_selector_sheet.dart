import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/trade_persona.dart';

/// 1-Tap Ergonomic Persona Selection Sheet for Australian Tradies & Sole Traders.
/// Minimizes typing and Cognitive Load by setting up trade-specific smart defaults.
class TradePersonaSelectorSheet extends StatelessWidget {
  final TradePersona selectedPersona;
  final ValueChanged<TradePersona> onPersonaSelected;

  const TradePersonaSelectorSheet({
    super.key,
    required this.selectedPersona,
    required this.onPersonaSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'What is your primary trade?',
          style: AppTextStyles.pageTitle,
        ),
        const SizedBox(height: 8),
        const Text(
          'We customize your ATO trip purposes, supply merchants, and tool deductions automatically.',
          style: AppTextStyles.secondaryMedium,
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: TradePersona.values.length,
          itemBuilder: (context, index) {
            final persona = TradePersona.values[index];
            final isSelected = persona == selectedPersona;

            return InkWell(
              onTap: () => onPersonaSelected(persona),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColor.primaryMuted : AppColor.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColor.primary : AppColor.border,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColor.primary : AppColor.canvas,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            persona.icon,
                            size: 20,
                            color: isSelected ? Colors.white : AppColor.ink,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: AppColor.primary,
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          persona.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColor.primary : AppColor.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          persona.subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isSelected ? AppColor.primary.withValues(alpha: 0.8) : AppColor.muted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
