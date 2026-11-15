import 'package:flutter/material.dart';
import '../../../data/models/job_site.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/engine/evidence_review_service.dart';
import '../../../state/app_state.dart';
import 'workflow_job_editor.dart';
import '../cpk/cpk_trip_entry_screen.dart';
import '../logbook/logbook_trip_entry_screen.dart';
import '../trips/trip_detection_screen.dart';
import '../expenses/expense_detail_screen.dart';
import '../../../services/engine/tax_pack_share_helper.dart';
import 'workflow_trip_editor.dart';

class WorkflowScreen extends StatefulWidget {
  final AppState appState;
  const WorkflowScreen({super.key, required this.appState});
  static Future<void> show(BuildContext context, AppState state) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WorkflowScreen(appState: state)));
  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  int _step = 0;
  bool _pendingOnly = true;
  AppState get state => widget.appState;

  Future<void> _job([JobSite? existing]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WorkflowJobEditor(appState: state, job: existing)));

  void _error(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _link(VehicleExpense expense) async {
    String? tripId = expense.linkedTripId;
    String? jobId = expense.jobId;
    final trips = state.trips
        .where((t) => t.vehicleId == expense.vehicleId && !t.isDeleted)
        .toList()
      ..sort((a, b) => (a.date.difference(expense.date).abs())
          .compareTo(b.date.difference(expense.date).abs()));
    final jobs =
        state.jobSites.where((j) => j.isActive || j.id == jobId).toList();
    bool saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                  title: const Text('Link receipt'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text(
                            'Closest dates appear first. Choose a trip or job only when related; linking does not change the expense allocation.'),
                        DropdownButtonFormField<String>(
                          initialValue:
                              trips.any((t) => t.id == tripId) ? tripId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Trip'),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No trip / period expense')),
                            ...trips.map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(
                                    '${t.date.toIso8601String().substring(0, 10)} · ${t.distanceKm.toStringAsFixed(1)} km · ${t.purpose}',
                                    overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: saving
                              ? null
                              : (v) => update(() {
                                    tripId = v;
                                    jobId = trips
                                        .where((t) => t.id == v)
                                        .firstOrNull
                                        ?.jobId;
                                  }),
                        ),
                        DropdownButtonFormField<String>(
                          key: ValueKey('$tripId:$jobId'),
                          initialValue:
                              jobs.any((j) => j.id == jobId) ? jobId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Job'),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null, child: Text('No specific job')),
                            ...jobs.map((j) => DropdownMenuItem(
                                value: j.id,
                                child: Text('${j.name} · ${j.clientName}',
                                    overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged:
                              saving ? null : (v) => update(() => jobId = v),
                        ),
                        if (error != null) Text(error!),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                update(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  await state.assignWorkflowExpense(
                                      expenseId: expense.id,
                                      tripId: tripId,
                                      jobId: jobId);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (_) {
                                  if (ctx.mounted) {
                                    update(() {
                                      saving = false;
                                      error =
                                          'Could not save. Check the trip and try again.';
                                    });
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save links'))
                  ],
                )));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final report = const EvidenceReviewService().evaluate(
            vehicle: state.primaryVehicle,
            financialYear: state.activeTaxRule.financialYear,
            trips: state.trips,
            expenses: state.expenses);
        final pending = report.items
            .whereType<TripReviewItem>()
            .map((i) => i.tripId)
            .toSet();
        final trips = report.trips
            .where((t) => !_pendingOnly || pending.contains(t.id))
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Trip → Job → Receipt → Pack')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Text(
                '${state.primaryVehicle?.displayName ?? 'Choose a vehicle first'} · FY ${report.financialYear}'),
            if (state.syncStatus == SyncStatus.error)
              TextButton.icon(
                  onPressed: () => state.triggerSyncToCloud(),
                  icon: const Icon(Icons.cloud_off),
                  label: const Text(
                      'Retry cloud sync — records stay on this device')),
            if (state.syncStatus == SyncStatus.syncing)
              const Text('Syncing records…'),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                children: ['Trips', 'Jobs', 'Receipts', 'Pack']
                    .indexed
                    .map((entry) => ChoiceChip(
                        label: Text('${entry.$1 + 1}. ${entry.$2}'),
                        selected: _step == entry.$1,
                        onSelected: (_) => setState(() => _step = entry.$1)))
                    .toList()),
            const SizedBox(height: 16),
            if (_step == 0) ...[
              const Text(
                  'Capture automatically, then confirm only the facts that need review. Personal and undecided travel stays out of business kilometres.'),
              Wrap(spacing: 8, children: [
                OutlinedButton(
                    onPressed: state.primaryVehicle == null
                        ? null
                        : () => TripDetectionScreen.show(context, state),
                    child: const Text('Tracking settings')),
                OutlinedButton(
                    onPressed: state.primaryVehicle == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => state
                                            .primaryVehicle!.taxMethod ==
                                        TaxMethod.logbook
                                    ? LogbookTripEntryScreen(appState: state)
                                    : CpkTripEntryScreen(appState: state))),
                    child: const Text('Add trip')),
              ]),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Needs review only'),
                  value: _pendingOnly,
                  onChanged: (v) => setState(() => _pendingOnly = v)),
              if (trips.isEmpty)
                Text(_pendingOnly
                    ? 'No trips waiting for review. Turn off the filter to edit saved reviews.'
                    : 'No trips in this year. Start tracking or add a trip.'),
              ...trips.map((t) => Card(
                  child: ListTile(
                      isThreeLine: true,
                      title: Text(
                          '${t.distanceKm.toStringAsFixed(1)} km · ${t.useLabel}'),
                      subtitle: Text(
                          '${t.date.toIso8601String().substring(0, 10)} · ${EvidenceReviewService.hasMeaningfulBusinessPurpose(t.purpose) ? t.purpose : 'Purpose needs review'}\n${t.jobReference ?? 'No job linked'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => WorkflowTripEditor.show(context,
                          appState: state, trip: t)))),
            ],
            if (_step == 1) ...[
              const Text(
                  'Save a job once and reuse it for trips and receipts. Archived jobs keep their historical links.'),
              FilledButton(
                  onPressed: () => _job(), child: const Text('Add job')),
              if (state.jobSites.isEmpty)
                const Text(
                    'No jobs yet. Jobs are optional for expenses that relate to a whole period.'),
              ...state.jobSites.map((job) => Card(
                      child: Column(children: [
                    ListTile(
                        title: Text(job.name),
                        subtitle: Text(
                            '${job.clientName} · ${job.projectCode ?? ''}${job.isActive ? '' : ' · Archived'}'),
                        onTap: () => _job(job)),
                    Text(
                        '${report.trips.where((t) => t.jobId == job.id).length} trips · ${report.expenses.where((e) => e.jobId == job.id || report.trips.any((t) => t.id == e.linkedTripId && t.jobId == job.id)).length} receipts this year'),
                    TextButton(
                        onPressed: () async {
                          try {
                            await state.addJobSite(job.copyWith(
                                isActive: !job.isActive,
                                updatedAt: DateTime.now()));
                          } catch (_) {
                            _error('Could not save. Try again.');
                          }
                        },
                        child:
                            Text(job.isActive ? 'Archive job' : 'Restore job')),
                  ]))),
            ],
            if (_step == 2) ...[
              const Text(
                  'Add or edit receipt details, then connect the record to a trip or job. Review work/private allocations in the receipt editor.'),
              FilledButton(
                  onPressed: state.primaryVehicle == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => ExpenseDetailScreen(
                                  appState: state,
                                  receiptDate: DateTime.now()))),
                  child: const Text('Add receipt manually')),
              if (report.expenses.isEmpty)
                const Text('No receipt records in this year.'),
              ...report.expenses.map((e) => Card(
                      child: Column(children: [
                    ListTile(
                        title: Text(
                            '${e.supplier ?? e.category.displayName} · \$${e.amount.toStringAsFixed(2)}'),
                        subtitle: Text(
                            '${e.date.toIso8601String().substring(0, 10)} · ${e.linkedTripId == null ? 'No trip linked' : 'Trip linked'}'),
                        onTap: () => ExpenseDetailScreen.show(context,
                            appState: state, expense: e)),
                    TextButton(
                        onPressed: () => _link(e),
                        child: const Text('Review trip / job link')),
                  ]))),
            ],
            if (_step == 3) ...[
              Text(
                  '${report.trips.length} trips · ${report.expenses.length} receipt records'),
              const SizedBox(height: 12),
              const Text(
                  'Your summary, spreadsheet and available receipts are collected together. Any missing details stay visible for your accountant.'),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: !report.canExport
                      ? null
                      : () => TaxPackShareHelper.shareTaxPack(context, state),
                  child: const Text('Send to accountant')),
            ],
          ]),
        );
      });
}
