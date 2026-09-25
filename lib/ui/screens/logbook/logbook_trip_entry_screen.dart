import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/trip.dart';
import '../../../state/app_state.dart';
import '../trips/widgets/logbook_odometer_card.dart';
import '../trips/widgets/trip_purpose_selector.dart';
import '../trips/widgets/tax_savings_ticker_dialog.dart';

/// Dedicated Trip Entry Screen for Logbook Method (TR 97/11)
/// 100% Focused on Gapless Continuous Odometer & Statutory Business/Personal Ratio.
class LogbookTripEntryScreen extends StatefulWidget {
  final AppState appState;
  final Trip? detectedTrip;

  const LogbookTripEntryScreen({
    super.key,
    required this.appState,
    this.detectedTrip,
  });

  @override
  State<LogbookTripEntryScreen> createState() => _LogbookTripEntryScreenState();
}

class _LogbookTripEntryScreenState extends State<LogbookTripEntryScreen> {
  String _selectedPurpose = 'Client / Job';
  late TextEditingController _distanceController;
  late TextEditingController _originController;
  late TextEditingController _destinationController;
  double _currentDistance = 0.0;
  double _customStartOdo = 0.0;

  @override
  void initState() {
    super.initState();
    _currentDistance = widget.detectedTrip?.distanceKm ?? 0.0;
    _distanceController = TextEditingController(
      text: _currentDistance > 0 ? _currentDistance.toStringAsFixed(1) : '',
    );
    _originController = TextEditingController(
      text: widget.detectedTrip?.originAddress ?? '',
    );
    _destinationController = TextEditingController(
      text: widget.detectedTrip?.destinationAddress ?? '',
    );
    _customStartOdo = widget.detectedTrip?.startOdometer ?? widget.appState.currentOdometer;
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _saveTrip() {
    HapticFeedback.heavyImpact();
    final parsedDist = double.tryParse(_distanceController.text.trim()) ?? _currentDistance;
    if (parsedDist <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.crimson,
          content: Text('Please enter a valid trip distance (km).'),
        ),
      );
      return;
    }

    final startOdo = _customStartOdo;
    final endOdo = startOdo + parsedDist;
    final isPersonal = _selectedPurpose == 'Personal';
    final origin = _originController.text.trim().isNotEmpty
        ? _originController.text.trim()
        : (isPersonal ? '[Private Journey]' : 'Work Site / Depot');
    final dest = _destinationController.text.trim().isNotEmpty
        ? _destinationController.text.trim()
        : (isPersonal ? '[Private Journey]' : 'Client Job Location');

    // Gapless Odometer Protection: If user advanced startOdo beyond currentOdometer,
    // automatically bridge the gap as Personal Travel so the ATO continuous chain remains intact.
    final odoGap = widget.appState.detectOdometerGap(startOdo);
    if (odoGap > 0.1) {
      widget.appState.fillOdometerGap(
        gapEndOdometer: startOdo,
        isBusiness: false,
        purpose: 'Personal travel (Bridging)',
      );
    }

    // Home-to-Work Compliance Guard (TR 2021/1)
    final isBulkyTools = _selectedPurpose == 'Heavy Tools & Equipment' ||
        _selectedPurpose == 'Carrying Heavy Tools' ||
        _selectedPurpose == 'Work Site (Bulky Tools Carried)';
    if (!isPersonal) {
      final (isCompliant, warning) = widget.appState.validateHomeToWorkCompliance(
        origin: origin,
        destination: dest,
        purpose: _selectedPurpose,
        isBulkyToolsCarried: isBulkyTools,
      );
      if (!isCompliant && warning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.amber,
            content: Text(warning),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    final trip = Trip(
      id: widget.detectedTrip?.id ?? 'logbook_trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.appState.primaryVehicle?.id ?? 'default_vehicle',
      distanceKm: parsedDist,
      date: widget.detectedTrip?.date ?? DateTime.now(),
      purpose: _selectedPurpose,
      startOdometer: startOdo,
      endOdometer: endOdo,
      classification: isPersonal ? TripClassification.personal : TripClassification.business,
      originAddress: origin,
      destinationAddress: dest,
    );

    widget.appState.recordTrip(trip);
    Navigator.of(context).pop();

    if (!isPersonal) {
      TaxSavingsTickerDialog.show(
        context,
        tripDistanceKm: parsedDist,
        appState: widget.appState,
        bulkyToolsCarried: isBulkyTools,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.muted,
          content: Text('Personal drive recorded: ${startOdo.toStringAsFixed(0)} → ${endOdo.toStringAsFixed(0)} km'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final endOdo = _customStartOdo + _currentDistance;
    final tripDate = widget.detectedTrip?.date ?? DateTime.now();
    final isWeekend = tripDate.weekday == DateTime.saturday || tripDate.weekday == DateTime.sunday;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Log Logbook Drive (TR 97/11)', style: AppTextStyles.cardPrimary),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Weekend Audit Trap Shield Banner
            if (isWeekend) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amberDark.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 20, color: AppColors.amberDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Weekend Trip Audit Flag (TR 97/11)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.amberDark,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'ATO audits scrutinize weekend drives. Ensure you select a distinct business purpose or mark as Personal if private.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Distance & Suburb Route Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trip Distance (km)', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _distanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: widget.detectedTrip == null,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '0.0',
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.deepNavy, width: 2)),
                      suffixText: 'km',
                      suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _currentDistance = double.tryParse(val.trim()) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),

                  // Origin field
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 15, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _originController,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Start suburb / depot (TR 97/11 Required)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Destination field
                  Row(
                    children: [
                      const Icon(LucideIcons.navigation, size: 15, color: AppColors.emerald),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'End suburb / destination (TR 97/11 Required)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Purpose Selector (Includes Mandatory Personal Option for Logbook Ratio)
            TripPurposeSelector(
              selectedPurpose: _selectedPurpose,
              isLogbook: true,
              onPurposeSelected: (p) => setState(() => _selectedPurpose = p),
            ),
            const SizedBox(height: 18),

            // 3. Continuous Odometer Card
            LogbookOdometerCard(
              appState: widget.appState,
              startOdometer: _customStartOdo,
              endOdometer: endOdo,
              onStartOdometerChanged: (val) => setState(() => _customStartOdo = val),
            ),
            const SizedBox(height: 24),

            // 4. Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _saveTrip,
              child: const Text('Save Audit Record', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
