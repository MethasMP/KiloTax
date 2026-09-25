import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/tracking/geocoding_service.dart';
import '../../../services/vehicle/australian_vehicle_catalog.dart';

enum VehicleSetupStage {
  searchAndSelect, // Step 1: Smart Search & Popular List
  confirmVehicle,  // Step 2: Confirmation card & Optional Rego / Odo
  taxMethod,       // Step 3: Choose Tax Method
}

/// Standalone & Reusable Vehicle Setup Flow
/// Faithfully implementing the ChatGPT specifications:
/// Search / Popular Select -> Confirm Vehicle & Optional Rego -> Tax Method
class VehicleSetupFlow extends StatefulWidget {
  final Function(Vehicle) onVehicleCreated;
  final VoidCallback? onCancel;
  final VehicleSetupStage initialStage;

  const VehicleSetupFlow({
    super.key,
    required this.onVehicleCreated,
    this.onCancel,
    this.initialStage = VehicleSetupStage.searchAndSelect,
  });

  @override
  State<VehicleSetupFlow> createState() => _VehicleSetupFlowState();
}

class _VehicleSetupFlowState extends State<VehicleSetupFlow> {
  late VehicleSetupStage _stage = widget.initialStage;

  // Search & Catalog
  final _searchController = TextEditingController();
  final _regoController = TextEditingController();
  final _odometerController = TextEditingController();
  String? _selectedState;
  AustralianVehicleCatalogEntry _selectedVehicle = AustralianVehicleCatalog.popularTradieVehicles.first;
  bool _isSearching = false;
  List<AustralianVehicleCatalogEntry> _searchResults = [];

  // Tax method
  TaxMethod _selectedTaxMethod = TaxMethod.centsPerKm;

  @override
  void initState() {
    super.initState();
    _searchResults = AustralianVehicleCatalog.popularTradieVehicles;
    _searchController.addListener(_onSearchChanged);
    _regoController.addListener(() => setState(() {}));
    _autoDetectState();
  }

  Future<void> _autoDetectState() async {
    if (_selectedState != null) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(timeLimit: Duration(seconds: 2)),
            );
        final detected = GeocodingService.stateFromCoordinates(pos.latitude, pos.longitude);
        if (mounted && _selectedState == null) {
          setState(() {
            _selectedState = detected;
          });
          return;
        }
      }
    } catch (_) {
      // Graceful offline fallback
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = AustralianVehicleCatalog.popularTradieVehicles;
      });
      return;
    }

    setState(() => _isSearching = true);
    AustralianVehicleCatalog.searchAsync(q).then((results) {
      if (mounted && _searchController.text.trim() == q) {
        setState(() => _searchResults = results);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _regoController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  void _finishVehicleCreation() {
    HapticFeedback.heavyImpact();

    final odo = double.tryParse(_odometerController.text.replaceAll(',', '').trim()) ?? 0.0;
    final cleanPlateText = _regoController.text.trim().toUpperCase();
    final rego = cleanPlateText.isNotEmpty
        ? (_selectedState != null ? '$cleanPlateText ($_selectedState)' : cleanPlateText)
        : 'No Plate';

    final modelName = _selectedVehicle.model;

    final created = Vehicle(
      id: 'vehicle_${DateTime.now().millisecondsSinceEpoch}',
      make: _selectedVehicle.make,
      model: modelName,
      regoPlate: rego,
      initialOdometer: odo,
      vehicleType: _selectedVehicle.vehicleType,
      taxMethod: _selectedTaxMethod,
      logbookStartDate: _selectedTaxMethod == TaxMethod.logbook ? DateTime.now() : null,
    );

    widget.onVehicleCreated(created);
  }

  void _showManualVehicleEntryDialog() {
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    VehicleType manualType = VehicleType.ute;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: 14,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vehicle Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                        color: AppColors.ink,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
                      onPressed: () => Navigator.of(ctx).pop(),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Make & Model Input with crystal-clear Australian terminology
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: makeController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppColors.ink),
                        decoration: InputDecoration(
                          labelText: 'Make (Brand)',
                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                          hintText: 'Toyota, Ford',
                          hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: modelController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppColors.ink),
                        decoration: InputDecoration(
                          labelText: 'Model',
                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                          hintText: 'HiLux, Ranger',
                          hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Full-width Body Type Selector (Crucial for ATO Ute/Van vs Car compliance)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'Body Type (for ATO Tax Classification)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<VehicleType>(
                          value: manualType,
                          isExpanded: true,
                          items: VehicleType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  type.buildSilhouette(width: 24, height: 18, color: AppColors.deepNavy),
                                  const SizedBox(width: 10),
                                  Text(
                                    type.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => manualType = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepNavy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final make = makeController.text.trim().isNotEmpty ? makeController.text.trim() : 'Work';
                      final model = modelController.text.trim().isNotEmpty ? modelController.text.trim() : 'Vehicle';

                      setState(() {
                        _selectedVehicle = AustralianVehicleCatalogEntry(
                          make: make,
                          model: model,
                          year: null,
                          vehicleType: manualType,
                          fuelType: 'Diesel',
                        );
                        _stage = VehicleSetupStage.confirmVehicle;
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case VehicleSetupStage.searchAndSelect:
        return _buildSearchAndSelectView();
      case VehicleSetupStage.confirmVehicle:
        return _buildConfirmVehicleView();
      case VehicleSetupStage.taxMethod:
        return _buildTaxMethodView();
    }
  }

  // -------------------------------------------------------------
  // STAGE 1: SEARCH & SELECT VEHICLE
  // -------------------------------------------------------------
  Widget _buildSearchAndSelectView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onCancel != null
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                onPressed: widget.onCancel,
              )
            : null,
        title: const Text('Add your vehicle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What do you drive?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search or select your work vehicle to begin tracking trips.',
                style: TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
              const SizedBox(height: 18),

              // Search Box
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search make or model',
                  hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14.5, fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.muted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppColors.muted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _isSearching = false);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 20),

              if (_isSearching) ...[
                const Text(
                  'Search Results',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (ctx, idx) {
                      final item = _searchResults[idx];
                      return ListTile(
                        leading: Container(
                          width: 54,
                          height: 40,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: item.vehicleType.build3dRender(
                              make: item.make,
                              model: item.model,
                              width: 50,
                              height: 36,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        title: Text(
                          '${item.make} ${item.model}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                        ),
                        subtitle: Text(
                          '${item.vehicleType.shortCategoryName} · ${item.fuelType}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.muted),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _selectedVehicle = item;
                            _stage = VehicleSetupStage.confirmVehicle;
                          });
                        },
                      );
                    },
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Popular Tradie Vehicles',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      'Instant select',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: AustralianVehicleCatalog.popularTradieVehicles.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (ctx, idx) {
                      final item = AustralianVehicleCatalog.popularTradieVehicles[idx];
                      return ListTile(
                        leading: Container(
                          width: 54,
                          height: 40,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: item.vehicleType.build3dRender(
                              make: item.make,
                              model: item.model,
                              width: 50,
                              height: 36,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        title: Text(
                          '${item.make} ${item.model}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                        ),
                        subtitle: Text(
                          '${item.vehicleType.shortCategoryName} · ${item.fuelType}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.muted),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _selectedVehicle = item;
                            _stage = VehicleSetupStage.confirmVehicle;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showManualVehicleEntryDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 15, color: AppColors.muted.withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Text(
                            "Can't find your vehicle? Enter manually",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted.withValues(alpha: 0.9),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STAGE 2: CONFIRM VEHICLE & OPTIONAL REGO
  // -------------------------------------------------------------
  Widget _buildConfirmVehicleView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
          onPressed: () => setState(() => _stage = VehicleSetupStage.searchAndSelect),
        ),
        title: const Text('Your Vehicle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.workBlue, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.workBlueLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _selectedVehicle.vehicleType.build3dRender(
                          make: _selectedVehicle.make,
                          model: _selectedVehicle.model,
                          width: 72,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedVehicle.make} ${_selectedVehicle.model}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedVehicle.vehicleType.displayName} • ${_selectedVehicle.fuelType}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _stage = VehicleSetupStage.searchAndSelect),
                      child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Rego Plate (Optional)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rego Plate', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Optional', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Australian Rego Plate Input with Smart State Detection
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _regoController.text.isNotEmpty ? AppColors.deepNavy : AppColors.border,
                    width: _regoController.text.isNotEmpty ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // State Badge on Plate (Aussie Style)
                    InkWell(
                      onTap: _selectedState != null
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedState = null);
                            }
                          : null,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedState != null ? AppColors.workBlueLight : AppColors.background,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                          border: Border(right: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
                        ),
                        child: Text(
                          _selectedState ?? 'STATE',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: _selectedState != null ? AppColors.deepNavy : AppColors.muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    // Plate Text Input
                    Expanded(
                      child: TextField(
                        controller: _regoController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink, letterSpacing: 1.2),
                        decoration: const InputDecoration(
                          hintText: '1AB 2CD',
                          hintStyle: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400, fontSize: 14.5, letterSpacing: 1.0),
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_regoController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: AppColors.muted),
                        onPressed: () {
                          _regoController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 1-Tap State Picker Chips (Zero friction, no dropdown hidden menus)
              Row(
                children: [
                  Text(
                    _selectedState == null ? 'Select State:' : 'State:',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: AustralianVehicleCatalog.states.map((state) {
                          final isSelected = _selectedState == state;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (_selectedState == state) {
                                    _selectedState = null;
                                  } else {
                                    _selectedState = state;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.deepNavy : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppColors.deepNavy : AppColors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  state,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Why add it? Helps identify your vehicle when reviewing ATO tax records.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _stage = VehicleSetupStage.taxMethod);
                },
                child: const Text('Next: Choose Tax Method', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STAGE 3: TAX METHOD SELECTION
  // -------------------------------------------------------------
  Widget _buildTaxMethodView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
          onPressed: () => setState(() => _stage = VehicleSetupStage.confirmVehicle),
        ),
        title: const Text('Tax Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How do you want to track\nyour vehicle deduction?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink, height: 1.25),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select your preferred ATO deduction method for this vehicle.',
                style: TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
              const SizedBox(height: 20),

              // Primary Method: Cents per Kilometre
              _buildTaxOptionCard(
                method: TaxMethod.centsPerKm,
                title: 'Cents per kilometre',
                badgeText: 'RECOMMENDED',
                badgeColor: AppColors.emerald,
                badgeBg: AppColors.emeraldLight,
                valueHeadline: 'Claim up to \$4,550 / year',
                valueSubtext: 'Statutory 91¢/km rate (up to 5,000 km per vehicle)',
                bulletPoints: const [
                  'No logbook or odometer readings required',
                  'No fuel, service, or repair receipts needed',
                  'Simply log your daily business drives',
                ],
                icon: LucideIcons.gauge,
              ),
              const SizedBox(height: 16),

              // Secondary Method: 12-Week Logbook
              _buildTaxOptionCard(
                method: TaxMethod.logbook,
                title: 'Logbook method',
                badgeText: 'COMING SOON',
                badgeColor: AppColors.muted,
                badgeBg: const Color(0xFFF3F4F6),
                valueHeadline: 'Claim actual car expenses',
                valueSubtext: 'Best for heavy drivers exceeding 5,000 work km/yr',
                bulletPoints: const [
                  'No \$4,550 deduction ceiling (% business use)',
                  'Requires continuous 12-week trip logbook',
                  'Requires odometer & expense receipts',
                ],
                icon: LucideIcons.bookOpen,
                isComingSoon: true,
              ),

              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _finishVehicleCreation,
                child: const Text('Save Vehicle & Finish', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxOptionCard({
    required TaxMethod method,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required String valueHeadline,
    required String valueSubtext,
    required List<String> bulletPoints,
    required IconData icon,
    bool isComingSoon = false,
  }) {
    final isSelected = _selectedTaxMethod == method;
    return InkWell(
      onTap: isComingSoon
          ? () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.deepNavy,
                  content: Text('Logbook method is coming soon. Starting with Cents-per-km.'),
                ),
              );
            }
          : () {
              HapticFeedback.selectionClick();
              setState(() => _selectedTaxMethod = method);
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isComingSoon ? const Color(0xFFFAFAFB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.deepNavy : AppColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.deepNavy.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title + Badge + Radio/Lock
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.deepNavy.withValues(alpha: 0.08)
                        : (isComingSoon ? AppColors.border.withValues(alpha: 0.5) : AppColors.background),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? AppColors.deepNavy
                        : (isComingSoon ? AppColors.muted.withValues(alpha: 0.5) : AppColors.muted),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isComingSoon ? AppColors.ink.withValues(alpha: 0.7) : AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isComingSoon
                      ? Icons.lock_outline_rounded
                      : (isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                  color: isSelected
                      ? AppColors.deepNavy
                      : (isComingSoon ? AppColors.muted.withValues(alpha: 0.4) : AppColors.border),
                  size: 22,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Value Headline (Money / Tax Impact)
            Text(
              valueHeadline,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: isComingSoon ? AppColors.muted : AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              valueSubtext,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Key Substantiation Bullets (Clear Ergonomics for Tradies)
            ...bulletPoints.map((bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.5),
                        child: Icon(
                          isComingSoon ? Icons.circle : Icons.check_circle_rounded,
                          size: 13,
                          color: isComingSoon
                              ? AppColors.muted.withValues(alpha: 0.4)
                              : (isSelected ? AppColors.emerald : AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isComingSoon ? AppColors.muted.withValues(alpha: 0.8) : const Color(0xFF344054),
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
