import 'package:flutter/material.dart';
import '../../../data/models/trip.dart';
import '../../../services/engine/evidence_review_service.dart';
import '../../../state/app_state.dart';

class WorkflowTripEditor extends StatefulWidget {
  final AppState appState;
  final Trip trip;
  const WorkflowTripEditor(
      {super.key, required this.appState, required this.trip});

  static Future<void> show(BuildContext context,
          {required AppState appState, required Trip trip}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WorkflowTripEditor(appState: appState, trip: trip)));

  @override
  State<WorkflowTripEditor> createState() => _WorkflowTripEditorState();
}

class _WorkflowTripEditorState extends State<WorkflowTripEditor> {
  late final TextEditingController _purpose;
  late final TextEditingController _distance;
  late final TextEditingController _reason;
  late String _use;
  String? _job;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _purpose = TextEditingController(
        text: EvidenceReviewService.hasMeaningfulBusinessPurpose(trip.purpose)
            ? trip.purpose
            : '');
    _distance =
        TextEditingController(text: trip.businessDistanceKm.toStringAsFixed(2));
    _reason = TextEditingController(
        text: trip.review['allocationReason'] as String? ?? '');
    _use = trip.isMixed
        ? 'Mixed'
        : trip.isBusiness
            ? 'Business'
            : trip.classification == TripClassification.personal
                ? 'Personal'
                : 'Not sure';
    _job = trip.jobId;
  }

  @override
  void dispose() {
    _purpose.dispose();
    _distance.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final business = _use == 'Business' || _use == 'Mixed';
      final km = _use == 'Mixed'
          ? double.tryParse(_distance.text)
          : business
              ? widget.trip.distanceKm
              : 0.0;
      if (km == null ||
          (_use == 'Mixed' && (km <= 0 || km >= widget.trip.distanceKm))) {
        throw ArgumentError(
            'Enter a business distance greater than zero and less than the full trip.');
      }
      await widget.appState.reviewWorkflowTrip(
        tripId: widget.trip.id,
        classification: business
            ? TripClassification.business
            : _use == 'Personal'
                ? TripClassification.personal
                : TripClassification.unclassified,
        purpose: _purpose.text,
        businessKm: km,
        jobId: _job,
        allocationReason: _reason.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ArgumentError
              ? '${error.message}'
              : 'Could not save. Your changes are still here; try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final jobs = widget.appState.jobSites
        .where((j) => j.isActive || j.id == _job)
        .toList();
    final business = _use == 'Business' || _use == 'Mixed';
    return Scaffold(
      appBar: AppBar(title: const Text('Review trip')),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save review')))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('${trip.distanceKm.toStringAsFixed(2)} km recorded',
            style: Theme.of(context).textTheme.headlineSmall),
        Text(
            '${trip.originAddress ?? 'Origin not recorded'} → ${trip.destinationAddress ?? 'Destination not recorded'}'),
        Text(trip.evidenceSource.startsWith('manual')
            ? 'Entered manually'
            : 'Captured automatically'),
        const SizedBox(height: 16),
        Wrap(
            spacing: 8,
            children: ['Business', 'Personal', 'Mixed', 'Not sure']
                .map((use) => ChoiceChip(
                      label: Text(use),
                      selected: _use == use,
                      onSelected:
                          _saving ? null : (_) => setState(() => _use = use),
                    ))
                .toList()),
        if (business) ...[
          const SizedBox(height: 16),
          if (trip.review['jobSuggested'] == true)
            const Text(
                'Job suggested from a saved site. Confirm that it relates to this journey.'),
          DropdownButtonFormField<String>(
            initialValue: jobs.any((j) => j.id == _job) ? _job : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Job (optional)'),
            items: [
              const DropdownMenuItem<String>(
                  value: null, child: Text('No specific job')),
              ...jobs.map((j) => DropdownMenuItem(
                  value: j.id,
                  child: Text('${j.name} · ${j.clientName}',
                      overflow: TextOverflow.ellipsis)))
            ],
            onChanged: _saving ? null : (value) => setState(() => _job = value),
          ),
          TextField(
              controller: _purpose,
              enabled: !_saving,
              decoration: const InputDecoration(
                  labelText: 'Business purpose',
                  hintText: 'Install switchboard for Smith renovation'),
              maxLines: 3),
          const SizedBox(height: 12),
          const Text(
              'Home-to-work travel and private detours need separate consideration. A job link or a store visit does not establish a tax deduction.'),
        ],
        if (_use == 'Mixed') ...[
          TextField(
              controller: _distance,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Business distance (km)')),
          TextField(
              controller: _reason,
              enabled: !_saving,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Allocation explanation',
                  hintText: 'Private detour measured from the route…')),
          const Text(
              'The remaining distance stays private. Original distance and odometer readings are preserved. Shared reports hide this mixed route.'),
        ],
        if (_use == 'Not sure')
          const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                  'Keep this in review. No business kilometres will be included until you decide.')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 24),
      ]),
    );
  }
}
