import 'package:flutter/material.dart';
import '../../../state/app_state.dart';
import '../dashboard/task_home_body.dart';

class LogbookHomeBody extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;
  final VoidCallback? onReviewTrips;
  final VoidCallback? onViewTax;
  const LogbookHomeBody(
      {super.key,
      required this.appState,
      this.onViewAll,
      this.onReviewTrips,
      this.onViewTax});
  @override
  Widget build(BuildContext context) => TaskHomeBody(
      appState: appState,
      onViewAll: onViewAll,
      onReviewTrips: onReviewTrips,
      onViewTax: onViewTax);
}
