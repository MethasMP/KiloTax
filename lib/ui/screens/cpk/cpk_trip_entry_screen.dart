import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../services/engine/purpose_synthesizer_service.dart';
import '../../../services/tracking/trade_poi_resolver.dart';
import '../../../state/app_state.dart';
import '../trips/widgets/cpk_quota_claim_banner.dart';
import '../trips/widgets/tax_savings_ticker_dialog.dart';

/// Dedicated Trip Entry Screen for Cents-per-Kilometre (CPK) Method
/// 100% Lean: Net Distance + 1-Tap Bulky Tools Exception. No Odometer. No Personal Trip.
class CpkTripEntryScreen extends StatefulWidget {
  final AppState appState;
  final Trip? detectedTrip;

  const CpkTripEntryScreen({
    super.key,
    required this.appState,
    this.detectedTrip,
  });

  @override
  State<CpkTripEntryScreen> createState() => _CpkTripEntryScreenState();
}

class _CpkTripEntryScreenState extends State<CpkTripEntryScreen> {
  String _selectedPurpose = 'Client Site';
  bool _bulkyToolsCarried = false;
  late TextEditingController _distanceController;
  late TextEditingController _originController;
  late TextEditingController _destinationController;
  late TextEditingController _jobRefController;
  double _currentDistance = 0.0;
  TradePoiMatch? _detectedTradePoi;

  @override
  void initState() {
    super.initState();
    _currentDistance = widget.detectedTrip?.distanceKm ?? 0.0;
    _bulkyToolsCarried = widget.detectedTrip?.purpose.contains('Bulky Tools') ?? false;

    final origAddress = widget.detectedTrip?.originAddress ?? '';
    final destAddress = widget.detectedTrip?.destinationAddress ?? '';
    _detectedTradePoi = TradePoiResolver.resolve(destAddress);

    // Tier 2: Ergonomic Auto-Detection for Tradie Commercial Utes/Vans
    final origLower = origAddress.toLowerCase();
    final destLower = destAddress.toLowerCase();
    final isHomeDeparture = origLower.contains('home') || origLower.contains('residence');
    final isJobDestination = destLower.contains('site') ||
        destLower.contains('job') ||
        destLower.contains('client') ||
        _detectedTradePoi != null;

    if (isHomeDeparture && isJobDestination) {
      _bulkyToolsCarried = true;
    }

    if (_bulkyToolsCarried) {
      _selectedPurpose = 'Tool Transport';
    } else if (_detectedTradePoi != null) {
      _selectedPurpose = 'Supplies Run';
    } else {
      _selectedPurpose = 'Client Site';
    }

    _distanceController = TextEditingController(
      text: _currentDistance > 0 ? _currentDistance.toStringAsFixed(1) : '',
    );
    _originController = TextEditingController(
      text: origAddress,
    );
    _destinationController = TextEditingController(
      text: destAddress,
    );
    _jobRefController = TextEditingController(
      text: widget.detectedTrip?.jobReference ?? '',
    );
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _jobRefController.dispose();
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

    final origin = _originController.text.trim().isNotEmpty
        ? _originController.text.trim()
        : 'Work Site';
    final dest = _destinationController.text.trim().isNotEmpty
        ? _destinationController.text.trim()
        : 'Client Destination';
    final jobRef = _jobRefController.text.trim().isNotEmpty
        ? _jobRefController.text.trim()
        : null;

    final effectivePurpose = PurposeSynthesizerService.synthesize(
      selectedPurpose: _selectedPurpose,
      destination: dest,
      bulkyToolsCarried: _bulkyToolsCarried,
      jobReference: jobRef,
    );

    final trip = Trip(
      id: widget.detectedTrip?.id ?? 'cpk_trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.appState.primaryVehicle?.id ?? 'default_vehicle',
      distanceKm: parsedDist,
      date: widget.detectedTrip?.date ?? DateTime.now(),
      purpose: effectivePurpose,
      startOdometer: 0.0, // CPK does not track continuous odometer
      endOdometer: 0.0,
      classification: TripClassification.business, // CPK captures claimable business drives
      originAddress: origin,
      destinationAddress: dest,
      jobReference: jobRef,
    );

    widget.appState.recordTrip(trip);
    Navigator.of(context).pop();

    TaxSavingsTickerDialog.show(
      context,
      tripDistanceKm: parsedDist,
      appState: widget.appState,
      bulkyToolsCarried: _bulkyToolsCarried,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rate = widget.appState.activeTaxRule.centsPerKmRate;
    final rateCents = (rate * 100).toInt();
    final tripDate = widget.detectedTrip?.date ?? DateTime.now();
    final isWeekend = tripDate.weekday == DateTime.saturday || tripDate.weekday == DateTime.sunday;
    final claimAmount = _currentDistance * rate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.ink),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),
        ),
        title: const Text(
          'Review Work Drive (CPK)',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Weekend Audit Trap Shield Banner (Poka-Yoke Guard)
            if (isWeekend) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.amberDark.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.amberDark.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.amberDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Weekend Drive Audit Alert (s 28-25)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.amberDark,
                              letterSpacing: -0.1,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'ATO closely audits weekend travel. Ensure trade purpose or Bulky Tools is selected below to guarantee statutory deduction immunity.',
                            style: TextStyle(fontSize: 12, color: AppColors.ink, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 2. HERO CASH DEDUCTION PAYOFF CARD (Linear Gradient + Glass accents)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepNavy, Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepNavy.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF34D399)),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ATO BOX D1 CLAIM VALUE',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          '$rateCents¢ / km',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '+${Formatters.currency(claimAmount)}',
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AUD Tax Deduction',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Distance & Route Telemetry Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DISTANCE TRAVELED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(LucideIcons.navigation, size: 11, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'Asphalt Verified (OSRM)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Distance Input Highlight Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.gauge, size: 22, color: AppColors.deepNavy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _distanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: widget.detectedTrip == null,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepNavy,
                              letterSpacing: -0.5,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '0.0',
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _currentDistance = double.tryParse(val.trim()) ?? 0.0;
                              });
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'KM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),

                  // Visual Route Path (Start to End)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 32,
                            color: const Color(0xFFCBD5E1),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _originController,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Start location (e.g. Home Depot / Base)',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                            const Divider(height: 12, color: Color(0xFFF1F5F9)),
                            TextField(
                              controller: _destinationController,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepNavy,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Destination (e.g. Client Site)',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1-Tap Quick Destination Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildQuickLocChip('Client Job Site', () {
                          _destinationController.text = 'Client Job Site';
                          setState(() => _selectedPurpose = 'Client Site');
                        }),
                        const SizedBox(width: 8),
                        _buildQuickLocChip('Bunnings Warehouse', () {
                          _destinationController.text = 'Bunnings Warehouse';
                          setState(() => _selectedPurpose = 'Supplies Run');
                        }),
                        const SizedBox(width: 8),
                        _buildQuickLocChip('Reece Plumbing', () {
                          _destinationController.text = 'Reece Plumbing';
                          setState(() => _selectedPurpose = 'Supplies Run');
                        }),
                        const SizedBox(width: 8),
                        _buildQuickLocChip('Total Tools', () {
                          _destinationController.text = 'Total Tools';
                          setState(() => _selectedPurpose = 'Supplies Run');
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tier 2: Job / Client Reference (Evidence Chain Link)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                        hintText: 'Job / Client Ref (Optional, e.g. Job #402)',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Trade Purpose Selection (Pareto 80/20 Core)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Trade Purpose',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'ITAA 1997 s 28-25',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPurposeTile(
              label: 'Client Site',
              subtitle: 'Contract trade works & customer site visits',
              icon: LucideIcons.briefcase,
              isSelected: _selectedPurpose == 'Client Site',
              onTap: () => setState(() => _selectedPurpose = 'Client Site'),
            ),
            const SizedBox(height: 8),
            _buildPurposeTile(
              label: 'Supplies Run',
              subtitle: 'Bunnings, Reece, tools, timber & materials',
              icon: LucideIcons.shoppingCart,
              isSelected: _selectedPurpose == 'Supplies Run',
              onTap: () => setState(() => _selectedPurpose = 'Supplies Run'),
            ),
            const SizedBox(height: 8),
            _buildPurposeTile(
              label: 'Tool Transport',
              subtitle: 'Heavy gear (>20kg) with no secure site lockup (s 8-1)',
              icon: LucideIcons.hammer,
              isSelected: _selectedPurpose == 'Tool Transport',
              onTap: () => setState(() {
                _selectedPurpose = 'Tool Transport';
                _bulkyToolsCarried = true;
              }),
            ),
            const SizedBox(height: 14),

            // 5. Bulky Tools Audit Shield Switch
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _bulkyToolsCarried ? AppColors.emeraldLight : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _bulkyToolsCarried ? AppColors.emerald : AppColors.border,
                  width: _bulkyToolsCarried ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _bulkyToolsCarried ? AppColors.emerald.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.shieldCheck,
                      size: 20,
                      color: _bulkyToolsCarried ? AppColors.emerald : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Carried Bulky Equipment (s 8-1)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _bulkyToolsCarried
                              ? '✓ Home-to-work drive legally converted to business deduction'
                              : 'Enable if carrying heavy gear with no secure on-site storage',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _bulkyToolsCarried ? AppColors.emerald : AppColors.muted,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _bulkyToolsCarried,
                    activeTrackColor: AppColors.emerald,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _bulkyToolsCarried = val;
                        if (val && _selectedPurpose == 'Client / Job') {
                          _selectedPurpose = 'Work Site (Bulky Tools Carried)';
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. Quota Banner
            CpkQuotaClaimBanner(
              appState: widget.appState,
              distanceKm: _currentDistance,
            ),
            const SizedBox(height: 26),

            // 7. Giant Primary Save Button (Apple Human Ergonomics)
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                onPressed: _saveTrip,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(LucideIcons.check, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Save Work Trip',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 8. 1-Tap Personal Discard Button
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: Colors.white,
                ),
                icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.muted),
                label: const Text(
                  'Personal Trip / Discard (Preserve 5,000 km Quota)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.deepNavy,
                      content: Text('Personal trip discarded. 5,000 km quota preserved for higher deductions.'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLocChip(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.mapPin, size: 12, color: AppColors.muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepNavy,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.deepNavy : AppColors.border,
          width: isSelected ? 1.75 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.deepNavy.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.deepNavy : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                          color: isSelected ? AppColors.deepNavy : AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.deepNavy : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppColors.deepNavy : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

