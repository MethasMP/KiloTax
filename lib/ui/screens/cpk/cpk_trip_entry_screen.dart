import '../../../services/tax/ato_tax_period_engine.dart';
import '../../widgets/adaptive_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../services/engine/purpose_synthesizer_service.dart';
import '../../../services/tracking/trade_poi_resolver.dart';
import '../../../state/app_state.dart';
import '../logbook/widgets/logbook_design.dart';
import '../../../core/theme/app_color.dart';

/// Dedicated Trip Entry Screen for Cents-per-Kilometre (CPK) Method
/// 100% Lean: Net Distance + 1-Tap Bulky Tools Exception. No Odometer. No Personal Trip.
class CpkTripEntryScreen extends StatefulWidget {
  final AppState appState;
  final String? vehicleId;
  final DateTime? initialDate;
  final bool requireDateConfirmation;
  final Trip? detectedTrip;

  const CpkTripEntryScreen({
    super.key,
    required this.appState,
    this.vehicleId,
    this.initialDate,
    this.requireDateConfirmation = false,
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
  bool _isSaving = false;
  late DateTime _tripDate =
      widget.detectedTrip?.date ?? widget.initialDate ?? DateTime.now();
  late bool _dateConfirmed = !widget.requireDateConfirmation;
  TradePoiMatch? _detectedTradePoi;

  @override
  void initState() {
    super.initState();
    _currentDistance = widget.detectedTrip?.distanceKm ?? 0.0;
    _bulkyToolsCarried =
        widget.detectedTrip?.purpose.contains('Bulky Tools') ?? false;

    final origAddress = widget.detectedTrip?.originAddress ?? '';
    final destAddress = widget.detectedTrip?.destinationAddress ?? '';
    _detectedTradePoi = TradePoiResolver.resolve(destAddress);

    // Tier 2: Ergonomic Auto-Detection for Tradie Commercial Utes/Vans
    final origLower = origAddress.toLowerCase();
    final destLower = destAddress.toLowerCase();
    final isHomeDeparture =
        origLower.contains('home') || origLower.contains('residence');
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
    if (_isSaving) return;
    if (!_dateConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose the actual trip date before saving.')));
      return;
    }
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();
    final parsedDist =
        double.tryParse(_distanceController.text.trim()) ?? _currentDistance;
    if (parsedDist <= 0) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.crimson,
          content: Text('Please enter a valid trip distance (km).'),
        ),
      );
      return;
    }

    final origin = _originController.text.trim();
    final dest = _destinationController.text.trim();
    if (origin.isEmpty || dest.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Add the starting and destination locations before saving.')));
      return;
    }
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
      id: widget.detectedTrip?.id ??
          'cpk_trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.vehicleId ??
          widget.detectedTrip?.vehicleId ??
          widget.appState.primaryVehicle?.id ??
          'default_vehicle',
      distanceKm: parsedDist,
      date: _tripDate,
      purpose: effectivePurpose,
      startOdometer: 0.0, // CPK does not track continuous odometer
      endOdometer: 0.0,
      classification:
          TripClassification.business, // CPK captures claimable business drives
      originAddress: origin,
      destinationAddress: dest,
      jobReference: jobRef,
    );

    widget.appState.recordTrip(trip);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
          'Work trip saved · ${Formatters.date(_tripDate)} · ${parsedDist.toStringAsFixed(1)} km'),
    ));
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _tripDate,
        firstDate: DateTime(2000),
        lastDate: _tripDate.isAfter(now) ? _tripDate : now);
    if (!mounted || date == null) return;
    setState(() => _tripDate = DateTime(
        date.year, date.month, date.day, _tripDate.hour, _tripDate.minute));
    _dateConfirmed = true;
  }

  @override
  Widget build(BuildContext context) {
    final activeYear =
        widget.appState.activeTaxRule.financialYear.replaceAll('–', '-');
    final hasEstimateScope = (widget.vehicleId ??
                widget.detectedTrip?.vehicleId ??
                widget.appState.primaryVehicle?.id) ==
            widget.appState.primaryVehicle?.id &&
        const AtoTaxPeriodEngine()
                .forDate(_tripDate)
                .shortLabel
                .replaceAll('–', '-') ==
            activeYear;
    final rate = widget.appState.activeTaxRule.centsPerKmRate;
    final rateCents = (rate * 100).toInt();
    final claimAmount = _currentDistance * rate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.ink,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          widget.detectedTrip == null ? 'Add trip' : 'Review trip',
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
      bottomNavigationBar: LogbookFooter(
          label: 'Save trip', onPressed: _isSaving ? null : _saveTrip),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Trip details', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            Text(
                hasEstimateScope
                    ? 'Record the distance and work purpose for this trip. Estimate uses $rateCents¢/km.'
                    : 'Record the distance and work purpose. View the estimate in the accountant pack for this vehicle and year.',
                style: AppTextStyles.secondaryMedium),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    label: Text(_dateConfirmed
                        ? Formatters.date(_tripDate)
                        : 'Choose actual trip date'))),
            const SizedBox(height: 12),
            TextField(
              controller: _distanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Trip distance',
                  hintText: '0.0',
                  suffixText: 'km',
                  border: OutlineInputBorder()),
              onChanged: (value) => setState(
                  () => _currentDistance = double.tryParse(value.trim()) ?? 0),
            ),
            const SizedBox(height: 20),
            // Region 2: Journey & Evidence Context (Gestalt Common Region: Audit Proofing)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepNavy.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdaptiveRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Route',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Trip locations',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Visual Route Path (Start to End - Gestalt Continuity / Closure)
                  AdaptiveRow(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColor.line,
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
                            color: AppColor.line,
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
                                  color:
                                      AppColors.emerald.withValues(alpha: 0.3),
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
                                hintText: 'From',
                                hintStyle: TextStyle(
                                    color: AppColor.inkSubtle, fontSize: 13),
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                            const Divider(
                                height: 12, color: AppColor.surfaceMuted),
                            TextField(
                              controller: _destinationController,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepNavy,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'To',
                                hintStyle: TextStyle(
                                    color: AppColor.inkSubtle, fontSize: 13),
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 4),
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
                    child: AdaptiveRow(
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
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColor.surfaceMuted),
                  const SizedBox(height: 10),

                  Material(
                      color: AppColor.surface,
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Job reference (optional)',
                            style: AppTextStyles.secondaryMedium),
                        children: [
                          TextField(
                              controller: _jobRefController,
                              decoration: const InputDecoration(
                                  labelText: 'Job or client reference',
                                  border: OutlineInputBorder()))
                        ],
                      )),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Region 3: Trade Purpose (Gestalt Common Region: Statutory Purpose)
            AdaptiveRow(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Work purpose',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Choose the reason',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Unified Grouped Card with Dividers (Apple Inset Style)
            Container(
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
              child: Column(
                children: [
                  _buildGroupedPurposeRow(
                    label: 'Client Site',
                    subtitle: 'Contract trade works & client visits',
                    icon: LucideIcons.briefcase,
                    isSelected: _selectedPurpose == 'Client Site',
                    isTop: true,
                    isBottom: false,
                    onTap: () {
                      setState(() {
                        _selectedPurpose = 'Client Site';
                        _bulkyToolsCarried = false;
                      });
                    },
                  ),
                  _buildGroupedPurposeRow(
                    label: 'Supplies Run',
                    subtitle: 'Bunnings, tools, timber & materials',
                    icon: LucideIcons.shoppingCart,
                    isSelected: _selectedPurpose == 'Supplies Run',
                    isTop: false,
                    isBottom: false,
                    onTap: () {
                      setState(() {
                        _selectedPurpose = 'Supplies Run';
                        _bulkyToolsCarried = false;
                      });
                    },
                  ),
                  _buildGroupedPurposeRow(
                    label: 'Tool Transport',
                    subtitle:
                        'Carried heavy gear (>20kg) with no secure lockup',
                    icon: LucideIcons.hammer,
                    isSelected: _selectedPurpose == 'Tool Transport' ||
                        _bulkyToolsCarried,
                    isTop: false,
                    isBottom: true,
                    onTap: () {
                      setState(() {
                        _selectedPurpose = 'Tool Transport';
                        _bulkyToolsCarried = true;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (hasEstimateScope)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Deduction estimate',
                    style: AppTextStyles.secondaryMedium),
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text('Estimated deduction',
                            style: AppTextStyles.caption),
                        Text('+${Formatters.currency(claimAmount)}',
                            style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 8),
                        Text(
                            '${(widget.appState.activeTaxRule.centsPerKmMaxKm - (widget.appState.taxSummary.businessKm + _currentDistance)).clamp(0.0, 5000.0).toStringAsFixed(0)} km remaining of 5,000 km annual ATO quota',
                            style: AppTextStyles.caption),
                        const SizedBox(height: 20),
                      ])
                ],
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(LucideIcons.trash2, size: 15),
                label: const Text(
                  'Cancel without saving',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.deepNavy,
                      content: Text('No trip was saved.'),
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
            color: AppColor.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColor.hairline),
          ),
          child: AdaptiveRow(
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

  Widget _buildGroupedPurposeRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isTop,
    required bool isBottom,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(16) : Radius.zero,
          bottom: isBottom ? const Radius.circular(16) : Radius.zero,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: AdaptiveRow(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.deepNavy
                          : AppColor.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
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
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                            color:
                                isSelected ? AppColors.deepNavy : AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isSelected ? AppColors.deepNavy : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppColors.deepNavy : AppColor.line,
                        width: 1.75,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
            if (!isBottom)
              const Padding(
                padding: EdgeInsets.only(left: 68),
                child: Divider(
                    height: 1, thickness: 1, color: AppColor.surfaceMuted),
              ),
          ],
        ),
      ),
    );
  }
}
