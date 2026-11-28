import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_color.dart';
import '../../../widgets/adaptive_row.dart';

/// Prominent ATO s 8-1 Bulky Tools badge & explanatory sheet.
/// Meets ATO TR 2021/1 and ITAA 1997 s 8-1 travel deduction substantiation.
/// Ergonomics: Minimum 48x48dp interactive touch target on mobile.
class BulkyToolsBadge extends StatelessWidget {
  final bool compact;
  final bool showInfoOnTap;
  final String? customLabel;
  final VoidCallback? onTap;

  const BulkyToolsBadge({
    super.key,
    this.compact = false,
    this.showInfoOnTap = true,
    this.customLabel,
    this.onTap,
  });

  static void showAtoExplanationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _BulkyToolsExplanationModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = customLabel ?? (compact ? 'ATO s 8-1 · Bulky Tools' : 'ATO Section 8-1 · Bulky Tools Exemption');

    final badgeWidget = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.0 : 12.0,
        vertical: compact ? 3.0 : 6.0,
      ),
      decoration: BoxDecoration(
        color: AppColor.positiveTint,
        borderRadius: BorderRadius.circular(compact ? 6.0 : 10.0),
        border: Border.all(
          color: AppColor.positiveStrong.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.hammer,
            size: compact ? 12.0 : 15.0,
            color: AppColor.positiveInk,
          ),
          const SizedBox(width: 5.0),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11.0 : 12.5,
              fontWeight: FontWeight.w700,
              color: AppColor.positiveInk,
              letterSpacing: -0.1,
            ),
          ),
          if (!compact && showInfoOnTap) ...[
            const SizedBox(width: 6.0),
            Icon(
              LucideIcons.info,
              size: 14.0,
              color: AppColor.positiveStrong.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );

    if (!showInfoOnTap && onTap == null) {
      return badgeWidget;
    }

    return Semantics(
      button: true,
      label: 'Bulky Tools exemption under ATO section 8-1. Tap to view explanation.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 6.0 : 10.0),
          onTap: onTap ?? () => showAtoExplanationSheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 48.0,
              minWidth: 48.0,
            ),
            child: Center(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: badgeWidget,
            ),
          ),
        ),
      ),
    );
  }
}

class _BulkyToolsExplanationModal extends StatelessWidget {
  const _BulkyToolsExplanationModal();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColor.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AdaptiveRow(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColor.positiveTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.shieldCheck,
                    color: AppColor.positiveStrong,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATO Section 8-1 Exemption',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColor.ink,
                        ),
                      ),
                      Text(
                        'ITAA 1997 s 8-1 & ATO Ruling TR 2021/1',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColor.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColor.inkMuted),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColor.positiveTint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColor.positiveStrong.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why This Commute Is 100% Tax Deductible',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColor.positiveInk,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Under ordinary ATO rules, travel between home and a work site is treated as private and cannot be claimed. '
                    'However, under ITAA 1997 s 8-1 (supported by Vogt\'s Case 75 ATC 4073 and ATO TR 2021/1 §27), '
                    'home-to-work travel becomes fully tax-deductible when you carry bulky tools or equipment necessary for your trade duties and no secure lockup is available on site.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColor.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Statutory Audit Criteria',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColor.ink,
              ),
            ),
            const SizedBox(height: 10),
            _buildCriterionRow(
              icon: LucideIcons.weight,
              title: 'Heavy / Bulky Gear (>20kg)',
              desc: 'Tools or materials transported are cumbersome or exceed 20kg (e.g. drop saws, ladders, compressors, toolboxes).',
            ),
            const SizedBox(height: 10),
            _buildCriterionRow(
              icon: LucideIcons.lock,
              title: 'No Secure On-Site Storage',
              desc: 'The job site lacks safe, locked facilities where equipment can remain overnight without theft or weather risk.',
            ),
            const SizedBox(height: 10),
            _buildCriterionRow(
              icon: LucideIcons.briefcase,
              title: 'Employment / Business Requirement',
              desc: 'Transporting the tools is essential to complete trade duties at the destination site.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColor.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.fileSpreadsheet, size: 18, color: AppColor.brand),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'KiloClaim logs GPS coordinates, vehicle registration, and bulky tools flags directly into your accountant-ready export pack.',
                      style: TextStyle(fontSize: 12, color: AppColor.inkMuted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColor.ink,
                  foregroundColor: AppColor.onNavy,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got It, Keep Compliant'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCriterionRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColor.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColor.line, width: 0.8),
          ),
          child: Icon(icon, size: 14, color: AppColor.ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColor.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColor.inkMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
