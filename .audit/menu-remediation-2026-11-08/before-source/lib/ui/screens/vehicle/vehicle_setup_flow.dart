import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/tracking/geocoding_service.dart';
import '../../../services/tracking/hardware_bluetooth_service.dart';
import '../../../services/vehicle/australian_vehicle_catalog.dart';
import '../../widgets/tactile_primary_button.dart';
import '../../../core/theme/app_color.dart';
import '../../../services/vehicle/vehicle_classification_engine.dart';

enum VehicleSetupStage {
  searchAndSelect, // Step 1: Smart Search & Popular List
  confirmVehicle, // Step 2: Confirmation card & Optional Rego / Odo
  taxMethod, // Step 3: Choose Tax Method
  bluetoothLink, // Step 4: Optional Car Bluetooth auto-detect link
}

/// Standalone & Reusable Vehicle Setup Flow
/// Faithfully implementing the ChatGPT specifications:
/// Search / Popular Select -> Confirm Vehicle & Optional Rego -> Tax Method
class VehicleSetupFlow extends StatefulWidget {
  final Function(Vehicle) onVehicleCreated;
  final VoidCallback? onCancel;
  final VehicleSetupStage initialStage;
  final AustralianVehicleCatalogEntry? initialVehicle;

  const VehicleSetupFlow({
    super.key,
    required this.onVehicleCreated,
    this.onCancel,
    this.initialStage = VehicleSetupStage.searchAndSelect,
    this.initialVehicle,
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
  String? _regoError;
  String? _odometerError;
  String? _selectedState = 'NSW';
  late AustralianVehicleCatalogEntry _selectedVehicle = widget.initialVehicle ??
      AustralianVehicleCatalog.popularTradieVehicles.first;
  bool _isSearching = false;
  List<AustralianVehicleCatalogEntry> _searchResults = [];

  // Tax method: Default to Logbook matching RECOMMENDED status
  TaxMethod _selectedTaxMethod = TaxMethod.logbook;

  // Bluetooth link
  String? _selectedBluetoothDevice;
  StreamSubscription<List<HardwareBluetoothDevice>>? _btScanSub;
  List<HardwareBluetoothDevice> _discoveredDevices = [];
  bool _isBtScanning = false;

  @override
  void initState() {
    super.initState();
    _searchResults = AustralianVehicleCatalog.popularTradieVehicles;
    _searchController.addListener(_onSearchChanged);
    _autoDetectState();
    if (_stage == VehicleSetupStage.bluetoothLink) {
      _startBluetoothScan();
    }
  }

  void _startBluetoothScan() {
    setState(() {
      _isBtScanning = true;
    });

    _btScanSub?.cancel();
    _btScanSub = HardwareBluetoothService()
        .continuousRadarStream(preferredVehicleMake: _selectedVehicle.make)
        .listen(
      (devices) {
        if (mounted) {
          setState(() {
            _discoveredDevices = devices;
            // Smart auto-select first recommended device if user hasn't selected one
            if (_selectedBluetoothDevice == null && devices.isNotEmpty) {
              final first = devices.first;
              if (HardwareBluetoothService()
                  .isRecommendedForVehicle(first, _selectedVehicle.make)) {
                _selectedBluetoothDevice = first.name;
              }
            }
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isBtScanning = false;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isBtScanning = false;
          });
        }
      },
    );
  }

  Future<void> _autoDetectState() async {
    if (_selectedState != null) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(timeLimit: Duration(seconds: 2)),
            );
        final detected =
            GeocodingService.stateFromCoordinates(pos.latitude, pos.longitude);
        if (mounted && _selectedState == null) {
          setState(() {
            _selectedState = detected;
          });
          return;
        }
      }
    } catch (e, stack) {
      debugPrint(
          '[VehicleSetupFlow] Warning detecting state from GPS location: $e\n$stack');
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

  void _selectVehicle(AustralianVehicleCatalogEntry vehicle) {
    HapticFeedback.mediumImpact();
    _regoController.clear();
    _odometerController.clear();
    setState(() {
      _selectedVehicle = vehicle;
      _selectedState = 'NSW';
      _regoError = null;
      _odometerError = null;
      _stage = VehicleSetupStage.confirmVehicle;
    });
  }

  @override
  void dispose() {
    _btScanSub?.cancel();
    HardwareBluetoothService().stopScan();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _regoController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  void _finishVehicleCreation() {
    _btScanSub?.cancel();
    HardwareBluetoothService().stopScan();
    HapticFeedback.heavyImpact();

    final odo =
        double.tryParse(_odometerController.text.replaceAll(',', '').trim()) ??
            0.0;
    final cleanPlateText = _regoController.text.trim().toUpperCase();
    final rego = cleanPlateText.isNotEmpty
        ? (_selectedState != null
            ? '$cleanPlateText ($_selectedState)'
            : cleanPlateText)
        : '';

    final modelName = _selectedVehicle.model;

    final created = Vehicle(
      id: 'vehicle_${DateTime.now().millisecondsSinceEpoch}',
      make: _selectedVehicle.make,
      model: modelName,
      regoPlate: rego,
      initialOdometer: odo,
      vehicleType: _selectedVehicle.vehicleType,
      taxMethod: _selectedTaxMethod,
      logbookStartDate:
          _selectedTaxMethod == TaxMethod.logbook ? DateTime.now() : null,
      bluetoothDeviceName: _selectedBluetoothDevice,
    );

    widget.onVehicleCreated(created);
  }

  void _showManualVehicleEntryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ManualVehicleEntrySheet(
        onSubmitted: (make, model, type) {
          Navigator.of(context).pop();
          _regoController.clear();
          _odometerController.clear();
          setState(() {
            _selectedVehicle = AustralianVehicleCatalogEntry(
              make: make,
              model: model,
              year: null,
              vehicleType: type,
              fuelType: 'Diesel',
            );
            _selectedState = 'NSW';
            _regoError = null;
            _odometerError = null;
            _stage = VehicleSetupStage.confirmVehicle;
          });
        },
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
      case VehicleSetupStage.bluetoothLink:
        return _buildBluetoothLinkView();
    }
  }

  // -------------------------------------------------------------
  // STAGE 1: SEARCH & SELECT VEHICLE
  // -------------------------------------------------------------
  Widget _buildSearchAndSelectView() {
    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.onCancel != null
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColor.ink),
                onPressed: widget.onCancel,
              )
            : null,
        title: const Text('Add Vehicle',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColor.ink,
            )),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What do you drive?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColor.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search or select your primary work vehicle.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColor.inkSubtle,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Search Box
              TextField(
                controller: _searchController,
                cursorColor: AppColor.ink,
                decoration: InputDecoration(
                  hintText: 'Search make or model',
                  hintStyle: const TextStyle(
                      color: AppColor.inkSubtle,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 18, color: AppColor.inkSubtle),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 16, color: AppColor.inkSubtle),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _isSearching = false);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColor.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColor.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColor.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColor.ink, width: 1.2)),
                ),
              ),
              const SizedBox(height: 22),

              if (_isSearching) ...[
                const Text(
                  'Search results',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColor.ink),
                ),
                const SizedBox(height: 8),
                Material(
                  color: AppColor.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColor.line),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColor.hairline),
                    itemBuilder: (ctx, idx) {
                      final item = _searchResults[idx];
                      return ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColor.surfaceSunken,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColor.line),
                          ),
                          child: Icon(
                            item.vehicleType.iconData,
                            size: 18,
                            color: AppColor.ink,
                          ),
                        ),
                        title: Text(
                          '${item.make} ${item.model}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColor.ink),
                        ),
                        subtitle: Text(
                          item.vehicleType.displayName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColor.inkSubtle),
                        ),
                        trailing: const Icon(LucideIcons.chevronRight,
                            size: 16, color: AppColor.inkSubtle),
                        onTap: () => _selectVehicle(item),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Text(
                  'Common models in Australia',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: AppColor.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: AppColor.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColor.line),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        AustralianVehicleCatalog.popularTradieVehicles.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColor.hairline),
                    itemBuilder: (ctx, idx) {
                      final item =
                          AustralianVehicleCatalog.popularTradieVehicles[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColor.surfaceSunken,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColor.line),
                          ),
                          child: Icon(
                            item.vehicleType.iconData,
                            size: 18,
                            color: AppColor.ink,
                          ),
                        ),
                        title: Text(
                          '${item.make} ${item.model}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: -0.2,
                              color: AppColor.ink),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.vehicleType.displayName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColor.inkSubtle,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        trailing: const Icon(LucideIcons.chevronRight,
                            size: 18, color: AppColor.inkSubtle),
                        onTap: () => _selectVehicle(item),
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
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plusCircle,
                              size: 15,
                              color: AppColor.inkSubtle),
                          SizedBox(width: 6),
                          Text(
                            "Vehicle not listed? Enter manually",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColor.inkMuted,
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
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColor.ink),
          onPressed: () => setState(() {
            _regoError = null;
            _odometerError = null;
            _stage = VehicleSetupStage.searchAndSelect;
          }),
        ),
        title: const Text('Confirm Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColor.ink,
            )),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Vehicle Card with Integrated Tax Classification
              Container(
                decoration: BoxDecoration(
                  color: AppColor.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColor.line, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColor.scrimSoft,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                child: Column(
                  children: [
                    // Clean Vehicle Type Icon Circle
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColor.surfaceSunken,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColor.line),
                      ),
                      child: Icon(
                        _selectedVehicle.vehicleType.iconData,
                        size: 25,
                        color: AppColor.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedVehicle.make} ${_selectedVehicle.model}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColor.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Single Clean Body Type Pill (Minimalist & Focused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColor.surfaceSunken,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColor.line),
                      ),
                      child: Text(
                        _selectedVehicle.vehicleType.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColor.inkMuted,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Rego Plate Section
              const Text(
                'Number plate',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColor.ink,
                ),
              ),
              const SizedBox(height: 8),
              // Plate Input Box with Integrated State Dropdown Button
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _regoController,
                builder: (context, regoVal, _) {
                  final hasPlate = regoVal.text.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColor.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _regoError != null
                            ? AppColor.critical
                            : (hasPlate ? AppColor.ink : AppColor.line),
                        width: _regoError != null || hasPlate ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // State Selector inside plate box (Mini Menu with Optical Comfort)
                        PopupMenuButton<String>(
                          initialValue: _selectedState,
                          tooltip: 'Select state',
                          onSelected: (state) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedState = state);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColor.line),
                          ),
                          color: AppColor.surface,
                          elevation: 4,
                          itemBuilder: (context) {
                            return AustralianVehicleCatalog.states.map((st) {
                              return PopupMenuItem<String>(
                                value: st,
                                height: 38,
                                child: Row(
                                  children: [
                                    Text(
                                      st,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _selectedState == st
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: AppColor.ink,
                                      ),
                                    ),
                                    if (_selectedState == st) ...[
                                      const Spacer(),
                                      const Icon(LucideIcons.check,
                                          size: 14, color: AppColor.brand),
                                    ],
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 54),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: const BoxDecoration(
                              color: AppColor.surfaceSunken,
                              borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(11)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedState ?? 'NSW',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColor.ink,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(
                                  LucideIcons.chevronDown,
                                  size: 13,
                                  color: AppColor.inkMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Inset Optical Seam Divider
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColor.line,
                        ),
                        // Plate Text Input
                        Expanded(
                          child: TextField(
                            controller: _regoController,
                            textCapitalization: TextCapitalization.characters,
                            cursorColor: AppColor.ink,
                            onChanged: (_) {
                              if (_regoError != null) {
                                setState(() => _regoError = null);
                              }
                            },
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                color: AppColor.ink,
                                letterSpacing: 1.0),
                            decoration: const InputDecoration(
                              hintText: 'CQ84YK',
                              hintStyle: TextStyle(
                                  color: AppColor.inkSubtle,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14.5,
                                  letterSpacing: 0.5),
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (hasPlate)
                          IconButton(
                            icon: const Icon(Icons.clear,
                                size: 16, color: AppColor.inkSubtle),
                            onPressed: () => _regoController.clear(),
                          ),
                      ],
                    ),
                  );
                },
              ),
              if (_regoError != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.circleAlert,
                          size: 14, color: AppColor.critical),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _regoError!,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColor.critical,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // Starting Odometer (Fintech Tax-Baseline Pattern)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('Opening odometer',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColor.ink)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text('ATO BASELINE',
                        style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.4,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _odometerController,
                builder: (context, odoVal, _) {
                  final hasOdo = odoVal.text.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColor.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _odometerError != null
                            ? AppColor.critical
                            : (hasOdo ? AppColor.ink : AppColor.line),
                        width: _odometerError != null || hasOdo ? 1.4 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _odometerController,
                      cursorColor: AppColor.ink,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ThousandsSeparatorInputFormatter(),
                      ],
                      onChanged: (_) {
                        if (_odometerError != null) {
                          setState(() => _odometerError = null);
                        }
                      },
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: AppColor.ink,
                          fontFeatures: [FontFeature.tabularFigures()]),
                      decoration: const InputDecoration(
                        hintText: 'Enter km',
                        hintStyle: TextStyle(
                            color: AppColor.inkSubtle,
                            fontWeight: FontWeight.w400,
                            fontSize: 14.5),
                        prefixIcon: Icon(LucideIcons.gauge,
                            size: 17, color: AppColor.inkSubtle),
                        suffixText: 'km',
                        suffixStyle: TextStyle(
                            color: AppColor.inkSubtle,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        filled: false,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 5),
              const Text(
                'Recorded for your ATO logbook baseline. Can be confirmed before export.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColor.inkSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_odometerError != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.circleAlert,
                          size: 14, color: AppColor.critical),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _odometerError!,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColor.critical,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Tactile Primary Button
              TactilePrimaryButton(
                label: 'Continue to Tax Method',
                trailingIcon: LucideIcons.arrowRight,
                onPressed: () {
                  final cleanPlate = _regoController.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
                  if (cleanPlate.isEmpty) {
                    HapticFeedback.heavyImpact();
                    setState(() => _regoError = 'Enter your number plate to continue.');
                    return;
                  }
                  if (!RegExp(r'^[A-Z0-9]+$').hasMatch(cleanPlate)) {
                    HapticFeedback.heavyImpact();
                    setState(() => _regoError = 'Use only letters and numbers.');
                    return;
                  }
                  if (cleanPlate.length < 2 || cleanPlate.length > 7) {
                    HapticFeedback.heavyImpact();
                    setState(() => _regoError = 'Australian plates must be 2 to 7 characters.');
                    return;
                  }

                  final rawOdo = _odometerController.text.replaceAll(',', '').trim();
                  if (rawOdo.isNotEmpty) {
                    final parsed = double.tryParse(rawOdo);
                    if (parsed == null || parsed <= 0) {
                      HapticFeedback.heavyImpact();
                      setState(() => _odometerError = 'Enter a valid odometer reading.');
                      return;
                    }
                    if (parsed > 1500000) {
                      HapticFeedback.heavyImpact();
                      setState(() => _odometerError = 'Odometer reading cannot exceed 1,500,000 km.');
                      return;
                    }
                  }

                  HapticFeedback.mediumImpact();
                  setState(() {
                    _regoError = null;
                    _odometerError = null;
                    _stage = VehicleSetupStage.taxMethod;
                  });
                },
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.shieldCheck,
                      size: 13, color: Color(0xFF10B981)),
                  SizedBox(width: 5.5),
                  Text(
                    'Stored locally • Compliant with ATO Tax Rulings',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColor.inkSubtle,
                    ),
                  ),
                ],
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
    final previewVehicle = Vehicle(
      id: 'preview',
      make: _selectedVehicle.make,
      model: _selectedVehicle.model,
      vehicleType: _selectedVehicle.vehicleType,
    );
    final isCar =
        VehicleClassificationEngine.isCarForTaxPurposes(previewVehicle);
    final allowedMethods =
        VehicleClassificationEngine.allowedTaxMethods(previewVehicle);

    if (!allowedMethods.contains(_selectedTaxMethod)) {
      _selectedTaxMethod = allowedMethods.first;
    }

    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColor.ink),
          onPressed: () =>
              setState(() => _stage = VehicleSetupStage.confirmVehicle),
        ),
        title: const Text('Tax Method',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColor.ink,
            )),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Choose how you want to claim',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColor.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Every trip is tracked for both methods in parallel. You or your accountant can switch anytime with zero lost data.',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: AppColor.inkMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // If non-car (Truck / commercial vehicle): show Section 8-1 actual expenses callout
                        if (!isCar) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.amberLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.alertTriangle,
                                    size: 20, color: AppColors.amber),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    VehicleClassificationEngine.disqualificationReason(
                                            previewVehicle) ??
                                        'Commercial vehicles carrying 1,000 kg or more cannot use Cents per km under ATO rules. Claim actual expenses under Section 8-1 instead.',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.amberDark,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _TaxOptionCard(
                            method: TaxMethod.actualExpenses,
                            isSelected: _selectedTaxMethod == TaxMethod.actualExpenses,
                            onSelect: () => setState(() => _selectedTaxMethod = TaxMethod.actualExpenses),
                          ),
                        ] else ...[
                          _TaxOptionCard(
                            method: TaxMethod.logbook,
                            isSelected: _selectedTaxMethod == TaxMethod.logbook,
                            onSelect: () => setState(() => _selectedTaxMethod = TaxMethod.logbook),
                          ),
                          const SizedBox(height: 16),
                          _TaxOptionCard(
                            method: TaxMethod.centsPerKm,
                            isSelected: _selectedTaxMethod == TaxMethod.centsPerKm,
                            onSelect: () => setState(() => _selectedTaxMethod = TaxMethod.centsPerKm),
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: TactilePrimaryButton(
                        label: 'Continue to Auto-Track',
                        trailingIcon: LucideIcons.arrowRight,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _stage = VehicleSetupStage.bluetoothLink;
                          });
                          _startBluetoothScan();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STAGE 4: CAR BLUETOOTH LINK
  // -------------------------------------------------------------
  Widget _buildBluetoothLinkView() {
    if (_btScanSub == null && !_isBtScanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _stage == VehicleSetupStage.bluetoothLink &&
            _btScanSub == null) {
          _startBluetoothScan();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColor.ink),
          onPressed: () {
            _btScanSub?.cancel();
            HardwareBluetoothService().stopScan();
            setState(() {
              _isBtScanning = false;
              _stage = VehicleSetupStage.taxMethod;
            });
          },
        ),
        title: const Text('Car Bluetooth',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColor.ink,
            )),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Vehicle & Radar Card
                        Container(
                          decoration: BoxDecoration(
                            color: AppColor.surface,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColor.line, width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColor.scrimSoft,
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 16),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColor.surfaceSunken,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColor.line),
                                    ),
                                    child: Icon(
                                      _selectedVehicle.vehicleType.iconData,
                                      size: 28,
                                      color: AppColor.ink,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColor.ink,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColor.surface, width: 2),
                                      ),
                                      child: const Icon(
                                        LucideIcons.bluetooth,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Connect to ${_selectedVehicle.make} ${_selectedVehicle.model}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: AppColor.ink,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Auto-detect work trips the moment you get in your car.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppColor.inkMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bluetooth Discovered Devices or Scanning Placeholder
                        if (_discoveredDevices.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'NEARBY BLUETOOTH DEVICES',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColor.inkSubtle,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (_isBtScanning)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColor.inkSubtle,
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: _startBluetoothScan,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.refreshCw,
                                          size: 12, color: AppColor.inkSubtle),
                                      SizedBox(width: 4),
                                      Text(
                                        'Rescan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColor.inkSubtle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: AppColor.surface,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColor.line),
                            ),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _discoveredDevices.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColor.hairline),
                              itemBuilder: (ctx, idx) {
                                final dev = _discoveredDevices[idx];
                                final isSelected =
                                    _selectedBluetoothDevice == dev.name;
                                final isRecommended = HardwareBluetoothService()
                                    .isRecommendedForVehicle(
                                        dev, _selectedVehicle.make);
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColor.surfaceNavy
                                          : isRecommended
                                              ? const Color(0xFFEFF6FF)
                                              : AppColor.surfaceSunken,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColor.surfaceNavy
                                            : isRecommended
                                                ? const Color(0xFF93C5FD)
                                                : AppColor.line,
                                      ),
                                    ),
                                    child: Icon(
                                      dev.isAudioRoute
                                          ? LucideIcons.speaker
                                          : LucideIcons.bluetooth,
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : isRecommended
                                              ? const Color(0xFF2563EB)
                                              : AppColor.ink,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dev.name,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 14.5,
                                            color: AppColor.ink,
                                          ),
                                        ),
                                      ),
                                      if (isRecommended)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: const Text(
                                            'Matched',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    dev.isAudioRoute
                                        ? 'Active Car Audio / CarPlay'
                                        : isRecommended
                                            ? 'Recommended for ${_selectedVehicle.make}'
                                            : 'Bluetooth Device',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isRecommended
                                          ? const Color(0xFF2563EB)
                                          : AppColor.inkSubtle,
                                      fontWeight: isRecommended
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 20,
                                    color: isSelected
                                        ? AppColor.brand
                                        : AppColor.line,
                                  ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedBluetoothDevice = dev.name;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          // Continuous Active Radar State - never drops to dead "No Bluetooth devices found" box
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 28, horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColor.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColor.line),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColor.brand.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColor.brand,
                                      ),
                                    ),
                                    const Icon(
                                      LucideIcons.bluetooth,
                                      size: 16,
                                      color: AppColor.brand,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Listening for your car...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColor.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Turn on your car ignition or audio.\nDiscovered devices will appear automatically.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColor.inkSubtle,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TactilePrimaryButton(
                            label: 'Save & Start Tracking',
                            onPressed: _finishVehicleCreation,
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _selectedBluetoothDevice = null;
                                _finishVehicleCreation();
                              },
                              child: const Text(
                                "I'm not in my car right now (Skip)",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.inkSubtle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Extracted, performant Tax Option Card widget following Flutter element reuse best practices.
class _TaxOptionCard extends StatelessWidget {
  final TaxMethod method;
  final bool isSelected;
  final VoidCallback onSelect;

  const _TaxOptionCard({
    required this.method,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isLogbook = method == TaxMethod.logbook;

    final String headline = isLogbook
        ? 'Claim actual vehicle running costs'
        : 'Flat rate per kilometre';

    final String subline = isLogbook
        ? 'Best for regular work driving. Unlocks full deductions on fuel, repairs, insurance, and depreciation with no yearly limit.'
        : 'Best for occasional work trips. Simple claim with no receipts needed, capped at 5,000 km per year.';

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColor.ink : AppColor.line,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColor.scrimSoft,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 14),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? AppColor.ink : AppColor.inkSubtle,
                size: 24,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          method.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColor.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (isLogbook) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.emerald.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'RECOMMENDED FOR UTES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ] else if (method == TaxMethod.actualExpenses) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                            color: AppColor.surfaceSunken,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColor.line),
                          ),
                          child: const Text(
                            'COMMERCIAL',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColor.inkMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColor.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subline,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColor.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats numeric input with comma separators as thousands separators (e.g., 42150 -> 42,150)
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Strip non-digits
    final cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Format with commas from right to left
    final buffer = StringBuffer();
    final len = cleanText.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(cleanText[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ManualVehicleEntrySheet extends StatefulWidget {
  final void Function(String make, String model, VehicleType type) onSubmitted;

  const _ManualVehicleEntrySheet({required this.onSubmitted});

  @override
  State<_ManualVehicleEntrySheet> createState() => _ManualVehicleEntrySheetState();
}

class _ManualVehicleEntrySheetState extends State<_ManualVehicleEntrySheet> {
  late final TextEditingController _makeController;
  final _modelController = TextEditingController();
  final _makeFocusNode = FocusNode();
  VehicleType _manualType = VehicleType.ute;

  @override
  void initState() {
    super.initState();
    _makeController = TextEditingController();
    _makeController.addListener(_onTextChanged);
    _modelController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  bool get _isValid =>
      _makeController.text.trim().isNotEmpty &&
      _modelController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _makeController.removeListener(_onTextChanged);
    _modelController.removeListener(_onTextChanged);
    _makeController.dispose();
    _modelController.dispose();
    _makeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: 14,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
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
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.muted),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: RawAutocomplete<String>(
                    textEditingController: _makeController,
                    focusNode: _makeFocusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return AustralianVehicleCatalog.popularMakes.where((make) {
                        return make.toLowerCase().contains(query);
                      });
                    },
                    onSelected: (String selection) {
                      _makeController.text = selection;
                      _makeController.selection = TextSelection.fromPosition(
                        TextPosition(offset: selection.length),
                      );
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: AppColor.ink),
                        decoration: InputDecoration(
                          labelText: 'Make (Brand)',
                          labelStyle: const TextStyle(
                              fontSize: 13, color: AppColor.inkSubtle),
                          hintText: 'Toyota, Ford',
                          hintStyle: const TextStyle(
                              color: AppColor.inkSubtle,
                              fontWeight: FontWeight.w400,
                              fontSize: 13),
                          filled: true,
                          fillColor: AppColor.canvas,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColor.line)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColor.line)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColor.ink, width: 1.4)),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          color: AppColor.canvas,
                          shadowColor: AppColor.ink.withValues(alpha: 0.12),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColor.line),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: AppColor.line),
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColor.ink,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: _modelController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: AppColor.ink),
                    decoration: InputDecoration(
                      labelText: 'Model',
                      labelStyle: const TextStyle(
                          fontSize: 13, color: AppColor.inkSubtle),
                      hintText: 'HiLux, Ranger',
                      hintStyle: const TextStyle(
                          color: AppColor.inkSubtle,
                          fontWeight: FontWeight.w400,
                          fontSize: 13),
                      filled: true,
                      fillColor: AppColor.canvas,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColor.line)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColor.line)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColor.ink, width: 1.4)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'Body Type',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColor.inkSubtle),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColor.canvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColor.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VehicleType>(
                      value: _manualType,
                      isExpanded: true,
                      items: VehicleType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColor.surfaceSunken,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColor.line),
                                ),
                                child: Icon(
                                  type.iconData,
                                  size: 15,
                                  color: AppColor.ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                type.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColor.ink,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _manualType = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TactilePrimaryButton(
              label: 'Next: Add Plate & Odometer',
              trailingIcon: LucideIcons.arrowRight,
              onPressed: _isValid
                  ? () {
                      final make = _makeController.text.trim();
                      final model = _modelController.text.trim();
                      widget.onSubmitted(make, model, _manualType);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
