import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';

class TaxShieldHeroCard extends StatelessWidget {
  final AppState appState;

  const TaxShieldHeroCard({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final vehicle = appState.primaryVehicle;
    final isLogbook = vehicle?.taxMethod == TaxMethod.logbook;

    return isLogbook
        ? _buildLogbookHeroCard(context, appState)
        : _buildCentsPerKmHeroCard(context, appState);
  }

  Widget _buildCentsPerKmHeroCard(BuildContext context, AppState appState) {
    final vehicle = appState.primaryVehicle;
    final summary = appState.taxSummary;
    final businessKm = summary.businessKm;
    final maxKm = AppConstants.centsPerKmCapKm;
    final remainingKm = (maxKm - businessKm).clamp(0.0, maxKm);
    final percentage = (businessKm / maxKm).clamp(0.0, 1.0);
    final isAuditReady = appState.missingComplianceTrips.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status Bar inside the Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Audit Ready Status Indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isAuditReady ? AppColors.emerald : AppColors.amberDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isAuditReady ? 'AUDIT-READY • 100%' : 'ACTION REQUIRED',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      letterSpacing: 0.6,
                      color: isAuditReady ? AppColors.emerald : AppColors.amberDark,
                    ),
                  ),
                ],
              ),

              // Vehicle Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.car, size: 12, color: AppColors.muted),
                    const SizedBox(width: 5),
                    Text(
                      vehicle != null && vehicle.model.isNotEmpty ? vehicle.model : 'Vehicle',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Estimated Deduction Header
          const Text(
            'Estimated deduction',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 4),

          // Hero Metric
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Formatters.currency(summary.centsPerKmClaim),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  color: AppColors.deepNavy,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(appState.activeTaxRule.centsPerKmRate * 100).toInt()}c/km ATO rate',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quota Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${Formatters.distance(businessKm)} of 5,000 km claimed',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '${remainingKm.toStringAsFixed(0)} km left',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sleek Progress Track
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: percentage == 0.0 && businessKm > 0 ? 0.01 : percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogbookHeroCard(BuildContext context, AppState appState) {
    final summary = appState.taxSummary;
    final businessUse = summary.businessPercentage;
    final businessKm = summary.businessKm;
    final totalKm = summary.totalKm;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green "LOGBOOK" pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emeraldLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.bookOpen, color: AppColors.emerald, size: 14),
                const SizedBox(width: 4),
                Text(
                  'LOGBOOK • Week ${appState.currentLogbookWeek} of 12',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: AppColors.emerald,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Circular Progress + Business Use
          Row(
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: businessUse / 100.0,
                      strokeWidth: 7,
                      backgroundColor: AppColors.background,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                    ),
                    Center(
                      child: Text(
                        '${businessUse.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${businessUse.toStringAsFixed(1)}%',
                      style: AppTextStyles.pageTitle,
                    ),
                    const Text('Business use', style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          // Km stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Formatters.distance(businessKm), style: AppTextStyles.cardPrimary),
                  const Text('Business', style: AppTextStyles.caption),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatters.distance(totalKm), style: AppTextStyles.cardPrimary),
                  const Text('Total', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          // Logbook status row
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.emerald),
              const SizedBox(width: 6),
              Text(
                'Active • ${Formatters.date(appState.primaryVehicle?.logbookStartDate ?? DateTime.now())} - ${Formatters.date((appState.primaryVehicle?.logbookStartDate ?? DateTime.now()).add(Duration(days: AppConstants.statutoryLogbookDays)))}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
