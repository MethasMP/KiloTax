import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/migration/csv_importer_service.dart';
import '../../../state/app_state.dart';

/// Spec #19: Migration UX (Driversnote, Xero, CSV, ATO myDeductions)
/// "Import your existing records:
///  Driversnote / CSV / Excel / ATO myDeductions / Xero / MYOB
///  -> 2,481 trips imported, 97% matched automatically, 14 trips need attention"
class MigrationScreen extends StatefulWidget {
  final AppState appState;

  const MigrationScreen({super.key, required this.appState});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  bool _isImporting = false;
  MigrationImportResult? _result;

  void _showImportSheet(String platformName) {
    final csvController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Import from $platformName',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste your CSV data below (columns: Date, DistanceKm, Purpose, Type, From, To):',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: csvController,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Date,DistanceKm,Purpose,Type,From,To\n2026-08-01,34.2,Site visit to client,Business,Home,Job Site',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        csvController.text = data!.text!;
                      }
                    },
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('Paste Clipboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final text = csvController.text.trim();
                  Navigator.of(ctx).pop();
                  if (text.isNotEmpty) {
                    _processCsvContent(text);
                  }
                },
                child: const Text('Import & Substantiate Records', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runMigration(String platformName) {
    _showImportSheet(platformName);
  }

  void _processCsvContent(String csvContent) async {
    setState(() => _isImporting = true);
    HapticFeedback.mediumImpact();

    final vehicleId = widget.appState.primaryVehicle?.id ?? 'default_vehicle';
    final result = CsvImporterService.parseMileageCsv(
      csvContent: csvContent,
      defaultVehicleId: vehicleId,
    );

    // Save imported trips into Evidence Engine
    for (final trip in result.importedTrips) {
      widget.appState.recordTrip(trip);
    }

    setState(() {
      _isImporting = false;
      _result = result;
    });

    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import Past Records', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.arrowLeftRight, color: AppColors.workBlue, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Zero-Friction Switcher', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink)),
                        Text('Bring your historical trips over from Driversnote or accounting apps with 1 tap.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_result == null) ...[
              const Text('Select Source Platform', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink)),
              const SizedBox(height: 12),

              _SourceOptionCard(
                name: 'Driversnote Export',
                description: 'Import CSV or trip history spreadsheet',
                icon: LucideIcons.car,
                isLoading: _isImporting,
                onTap: () => _runMigration('Driversnote'),
              ),
              _SourceOptionCard(
                name: 'ATO myDeductions',
                description: 'Import ATO mobile app backup CSV',
                icon: LucideIcons.fileText,
                isLoading: _isImporting,
                onTap: () => _runMigration('ATO myDeductions'),
              ),
              _SourceOptionCard(
                name: 'Xero / MYOB Mileage',
                description: 'Sync logged business trips directly',
                icon: LucideIcons.downloadCloud,
                isLoading: _isImporting,
                onTap: () => _runMigration('Xero'),
              ),
              _SourceOptionCard(
                name: 'Custom CSV / Excel Spreadsheet',
                description: 'Any date, km, purpose spreadsheet',
                icon: LucideIcons.table,
                isLoading: _isImporting,
                onTap: () => _runMigration('Custom CSV'),
              ),
            ] else ...[
              // RESULT STATE (Spec #19)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.emeraldLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.checkCircle, color: AppColors.emerald, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${_result!.totalParsed} Trips Imported',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_result!.matchRate.toStringAsFixed(0)}% matched automatically',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.emerald),
                    ),
                    const Divider(height: 28, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResultStat(
                          label: 'Total Imported',
                          value: '${_result!.totalParsed}',
                          color: AppColors.ink,
                        ),
                        _ResultStat(
                          label: 'Auto Matched',
                          value: '${_result!.autoMatched}',
                          color: AppColors.emerald,
                        ),
                        _ResultStat(
                          label: 'Need Attention',
                          value: '${_result!.needsAttention}',
                          color: _result!.needsAttention > 0 ? AppColors.amber : AppColors.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.workBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go to Dashboard', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _SourceOptionCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.workBlueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.workBlue, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink)),
                      Text(description, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
      ],
    );
  }
}
