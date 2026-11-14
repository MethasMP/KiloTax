import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_space.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../state/app_state.dart';
import 'gap_bridge_sheet.dart';

class OdometerGapReviewCard extends StatelessWidget {
  final AppState appState;
  const OdometerGapReviewCard({super.key, required this.appState});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final gaps = appState.pendingOdometerGaps;
        if (gaps.isEmpty) return const SizedBox.shrink();
        final distance = gaps.fold<double>(0, (sum, gap) => sum + gap.distance);
        return Container(
            margin: const EdgeInsets.only(bottom: S.lg),
            padding: S.cardPad,
            decoration: BoxDecoration(
                color: AppColor.attentionTintSoft,
                border: Border.all(color: AppColor.attentionTintStrong),
                borderRadius: R.cardR),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(AppIcons.attention,
                        size: AppIconSize.control,
                        color: AppColor.attentionInk),
                    const SizedBox(width: S.sm),
                    Expanded(
                        child: Text(
                            '${Formatters.distance(distance)} of travel needs review',
                            style: AppType.cardTitle)),
                  ]),
                  const SizedBox(height: S.sm),
                  const Text(
                      'Your odometer readings show travel without confirmed trip details. It has not been classified for you.',
                      style: AppType.body),
                  const SizedBox(height: S.sm),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: () =>
                              GapBridgeSheet.show(context, appState: appState),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColor.attentionInk,
                              minimumSize: const Size(48, 48)),
                          icon: const Icon(AppIcons.forward,
                              size: AppIconSize.control),
                          label: const Text('Review missing travel'))),
                ]));
      });
}
