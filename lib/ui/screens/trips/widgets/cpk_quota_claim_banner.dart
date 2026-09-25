import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../state/app_state.dart';

class CpkQuotaClaimBanner extends StatelessWidget {
  final AppState appState;
  final double distanceKm;

  const CpkQuotaClaimBanner({
    super.key,
    required this.appState,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final rate = appState.activeTaxRule.centsPerKmRate;
    final maxKm = appState.activeTaxRule.centsPerKmMaxKm;
    final claimedKm = appState.taxSummary.businessKm;
    final remainingKm = (maxKm - (claimedKm + distanceKm)).clamp(0.0, maxKm);
    final claimAmount = distanceKm * rate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.emeraldLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.check, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  distanceKm > 0
                      ? '+${Formatters.currency(claimAmount)} ATO deduction'
                      : 'Cents per km rate: ${(rate * 100).toInt()}c/km',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${remainingKm.toStringAsFixed(0)} km remaining of 5,000 km annual ATO quota.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.ink.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
