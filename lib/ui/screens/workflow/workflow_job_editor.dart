import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/job_site.dart';
import '../../../services/sync/sync_engine_service.dart';
import '../../../state/app_state.dart';

class WorkflowJobEditor extends StatefulWidget {
  final AppState appState;
  final JobSite? job;
  const WorkflowJobEditor({super.key, required this.appState, this.job});
  @override
  State<WorkflowJobEditor> createState() => _WorkflowJobEditorState();
}

class _WorkflowJobEditorState extends State<WorkflowJobEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.job?.name);
  late final _client = TextEditingController(text: widget.job?.clientName);
  late final _reference = TextEditingController(text: widget.job?.projectCode);
  late final _address = TextEditingController(text: widget.job?.address);
  late bool _tracking = widget.job?.trackingEnabled ?? false;
  double? _latitude;
  double? _longitude;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _client.dispose();
    _reference.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _location() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
            'Location access is needed to save this site location. You can still save the job without it.');
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15)));
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _tracking = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not get this location. Check location access or save the job without automatic site matching.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final original = widget.job;
      final job = JobSite(
        id: original?.id ??
            SyncEngineService.cloudId(
                'job_${DateTime.now().microsecondsSinceEpoch}',
                widget.appState.currentUser?.id),
        userId: original?.userId ?? widget.appState.currentUser?.id ?? '',
        name: _name.text.trim(),
        clientName: _client.text.trim(),
        projectCode: _reference.text.trim(),
        address: _address.text.trim(),
        latitude: _latitude ?? original?.latitude ?? 0,
        longitude: _longitude ?? original?.longitude ?? 0,
        radiusMeters: original?.radiusMeters ?? 150,
        trackingEnabled: _tracking,
        isActive: original?.isActive ?? true,
        createdAt: original?.createdAt,
      );
      await widget.appState.addJobSite(job);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save. Your changes are still here; try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(widget.job == null ? 'Add job' : 'Edit job')),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Job name'),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Enter a job name'),
              TextFormField(
                  controller: _client,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Client'),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Enter a client'),
              TextFormField(
                  controller: _reference,
                  enabled: !_busy,
                  decoration:
                      const InputDecoration(labelText: 'Reference (optional)')),
              TextFormField(
                  controller: _address,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      labelText: 'Site address (optional)')),
              const SizedBox(height: 16),
              const Text(
                  'At the site? Save your current location to suggest this job for future trips. A location match still needs a business-purpose review.'),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _location,
                  icon: const Icon(Icons.my_location),
                  label: Text(_latitude == null
                      ? 'Use current location'
                      : 'Site location captured')),
              if (_latitude != null || widget.job?.trackingEnabled == true)
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Suggest this job near the site'),
                    value: _tracking,
                    onChanged:
                        _busy ? null : (v) => setState(() => _tracking = v)),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save job')),
            ])),
      );
}
