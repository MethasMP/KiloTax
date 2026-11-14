import 'package:flutter/material.dart';
import '../../../state/app_state.dart';
import '../dashboard/task_home_body.dart';

class LogbookHomeBody extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;
  const LogbookHomeBody({super.key, required this.appState, this.onViewAll});
  @override
  Widget build(BuildContext context) =>
      TaskHomeBody(appState: appState, onViewAll: onViewAll);
}
