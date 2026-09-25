import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../services/engine/trip_confidence_classifier.dart';
import '../../../../state/app_state.dart';

/// Meta Muse-Inspired "Structured Approval Sheet"
/// Separates high-confidence work travel (1-tap sign-off) from high-audit-risk drives (user decision card)
/// to respect user laziness without compromising legal tax compliance.
class CpkBatchReviewSheet extends StatefulWidget {
  final AppState appState;

  const CpkBatchReviewSheet({super.key, required this.appState});

  static Future<void> show(BuildContext context, AppState appState) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CpkBatchReviewSheet(appState: appState),
    );
  }

  @override
  State<CpkBatchReviewSheet> createState() => _CpkBatchReviewSheetState();
}

class _CpkBatchReviewSheetState extends State<CpkBatchReviewSheet> {
  late Set<String> _selectedHighConfidenceIds;
  final TextEditingController _jobRefController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final pendingTrips = widget.appState.missingComplianceTrips;
    _selectedHighConfidenceIds = pendingTrips
        .where((t) => TripConfidenceClassifier.assess(t).isHighConfidence)
        .map((t) => t.id)
        .toSet();
  }

  @override
  void dispose() {
    _jobRefController.dispose();
    super.dispose();
  }

  void _signOffHighConfidenceBatch(List<ClassifiedTripAssessment> highConfidenceList) {
    HapticFeedback.heavyImpact();
    final rate = widget.appState.activeTaxRule.centsPerKmRate;
    final totalKm = highConfidenceList
        .where((a) => _selectedHighConfidenceIds.contains(a.trip.id))
        .fold(0.0, (sum, a) => sum + a.trip.distanceKm);
    final dollarClaimed = totalKm * rate;

    final jobRef = _jobRefController.text.trim().isNotEmpty
        ? _jobRefController.text.trim()
        : null;

    for (final assessment in highConfidenceList) {
      if (_selectedHighConfidenceIds.contains(assessment.trip.id)) {
        widget.appState.batchApproveTrips(
          tripIds: [assessment.trip.id],
          defaultPurpose: assessment.suggestedPurpose,
          jobReference: jobRef,
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepNavy,
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Color(0xFF34D399), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Signed off ${_selectedHighConfidenceIds.length} work drives (+${Formatters.currency(dollarClaimed)})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.appState.missingComplianceTrips.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _selectedHighConfidenceIds.clear();
      });
    }
  }

  void _resolveIndividualTrip(Trip trip, {required bool isBusiness, required String purpose}) {
    HapticFeedback.mediumImpact();
    if (isBusiness) {
      widget.appState.batchApproveTrips(
        tripIds: [trip.id],
        defaultPurpose: purpose,
        jobReference: _jobRefController.text.trim().isNotEmpty ? _jobRefController.text.trim() : null,
      );
    } else {
      // Mark as personal journey
      widget.appState.updateTrip(
        trip.copyWith(
          classification: TripClassification.personal,
          purpose: 'Personal journey',
        ),
      );
    }

    if (widget.appState.missingComplianceTrips.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingTrips = widget.appState.missingComplianceTrips;
    final rate = widget.appState.activeTaxRule.centsPerKmRate;

    final assessments = pendingTrips.map(TripConfidenceClassifier.assess).toList();
    final highConfidence = assessments.where((a) => a.isHighConfidence).toList();
    final requiresDecision = assessments.where((a) => !a.isHighConfidence).toList();

    final selectedHighConfidenceKm = highConfidence
        .where((a) => _selectedHighConfidenceIds.contains(a.trip.id))
        .fold(0.0, (sum, a) => sum + a.trip.distanceKm);
    final selectedHighConfidenceDollars = selectedHighConfidenceKm * rate;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.shieldCheck, color: AppColors.emerald, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart Trip Verification',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepNavy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${pendingTrips.length} drives pending • Muse Safe-Approval',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Optional Job / Client Tag Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.tag, size: 16, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _jobRefController,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Job / Client Reference (Optional, e.g. Job #402)',
                      hintStyle: TextStyle(color: AppColors.muted, fontSize: 12.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Content List with Muse Partitioning
          Expanded(
            child: ListView(
              children: [
                // SECTION 1: HIGH-CONFIDENCE PRE-COOKED WORK BUNDLE
                if (highConfidence.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(LucideIcons.sparkles, size: 14, color: AppColors.emerald),
                          SizedBox(width: 6),
                          Text(
                            'CONFIRMED WORK DRIVES (READY)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${highConfidence.length} trips',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Hero Sign-off Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.deepNavy, Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BATCH CLAIM VALUE',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${Formatters.currency(selectedHighConfidenceDollars)}',
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emerald,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _selectedHighConfidenceIds.isNotEmpty
                                    ? () => _signOffHighConfidenceBatch(highConfidence)
                                    : null,
                                icon: const Icon(LucideIcons.checkCheck, size: 16),
                                label: Text(
                                  'Sign-Off (${_selectedHighConfidenceIds.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // High-confidence list items
                  ...highConfidence.map((assessment) {
                    final isSelected = _selectedHighConfidenceIds.contains(assessment.trip.id);
                    final tripVal = assessment.trip.distanceKm * rate;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.emerald.withValues(alpha: 0.5) : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox.adaptive(
                            value: isSelected,
                            activeColor: AppColors.emerald,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedHighConfidenceIds.add(assessment.trip.id);
                                } else {
                                  _selectedHighConfidenceIds.remove(assessment.trip.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      Formatters.dateTime(assessment.trip.date),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted),
                                    ),
                                    Text(
                                      '+${Formatters.currency(tripVal)}',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.emerald),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${assessment.trip.originAddress ?? "Origin"} → ${assessment.trip.destinationAddress ?? "Destination"}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${Formatters.distance(assessment.trip.distanceKm)} • ${assessment.decisionReason}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // SECTION 2: HIGH-RISK EXCEPTIONS (MUSE SENTINEL CARDS)
                if (requiresDecision.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.amberDark),
                      SizedBox(width: 6),
                      Text(
                        'NEEDS YOUR SIGN-OFF (SENTINEL GUARD)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.amberDark,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...requiresDecision.map((assessment) {
                    final tripVal = assessment.trip.distanceKm * rate;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.amberLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  Formatters.dateTime(assessment.trip.date),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.amberDark,
                                  ),
                                ),
                              ),
                              Text(
                                '+${Formatters.currency(tripVal)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${assessment.trip.originAddress ?? "Origin"} → ${assessment.trip.destinationAddress ?? "Destination"}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${Formatters.distance(assessment.trip.distanceKm)} • ${assessment.decisionReason}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
                          ),
                          const SizedBox(height: 12),

                          // Muse Dual Sign-Off Actions (Work vs Personal)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emeraldLight,
                                    foregroundColor: AppColors.emerald,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: AppColors.emerald),
                                    ),
                                  ),
                                  icon: const Icon(LucideIcons.check, size: 14),
                                  label: const Text(
                                    'Claim Work Trip',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  onPressed: () => _resolveIndividualTrip(
                                    assessment.trip,
                                    isBusiness: true,
                                    purpose: assessment.suggestedPurpose,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.muted,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    side: const BorderSide(color: AppColors.border),
                                  ),
                                  icon: const Icon(LucideIcons.home, size: 14),
                                  label: const Text(
                                    'Personal',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                  onPressed: () => _resolveIndividualTrip(
                                    assessment.trip,
                                    isBusiness: false,
                                    purpose: 'Personal journey',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
