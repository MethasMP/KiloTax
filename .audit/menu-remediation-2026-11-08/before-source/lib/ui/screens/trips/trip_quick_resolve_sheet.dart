import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../../../core/theme/app_color.dart';
import '../../../services/engine/bulky_tools_suggestion_engine.dart';
import 'widgets/trade_gear_registration_sheet.dart';

/// Spec #7 & #8: Fast, Frictionless Trip Purpose Classification
/// Ultra-clean thumb-first ergonomics for tradies & sole traders.
/// Seamless 1-tap presets (Auto) + direct free-text editing (Manual).
class TripQuickResolveSheet extends StatefulWidget {
  final Trip trip;
  final AppState appState;

  final void Function(Trip resolvedTrip)? onTripResolved;

  const TripQuickResolveSheet({
    super.key,
    required this.trip,
    required this.appState,
    this.onTripResolved,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required AppState appState,
    void Function(Trip resolvedTrip)? onTripResolved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripQuickResolveSheet(
        trip: trip,
        appState: appState,
        onTripResolved: onTripResolved,
      ),
    );
  }

  @override
  State<TripQuickResolveSheet> createState() => _TripQuickResolveSheetState();
}

class _TripQuickResolveSheetState extends State<TripQuickResolveSheet> {
  late bool _bulkyToolsCarried;
  late final BulkyToolsSuggestion _suggestion;
  late final bool _isOriginHome;
  late final bool _isDestinationHome;
  late final TextEditingController _purposeController;
  late TripClassification _classification;

  bool get _isHomeCommute => _isOriginHome || _isDestinationHome;

  @override
  void initState() {
    super.initState();
    _suggestion = BulkyToolsSuggestionEngine.evaluate(widget.trip);
    _bulkyToolsCarried =
        widget.trip.purpose.contains('Bulky Tools') || _suggestion.isSuggested;
    final originLower = (widget.trip.originAddress ?? '').trim().toLowerCase();
    final destLower =
        (widget.trip.destinationAddress ?? '').trim().toLowerCase();
    _isOriginHome =
        originLower.contains('home') || originLower.contains('residence');
    _isDestinationHome =
        destLower.contains('home') || destLower.contains('residence');

    _classification = widget.trip.classification == TripClassification.personal
        ? TripClassification.personal
        : TripClassification.business;

    final initialPurpose = widget.trip.purpose
        .replaceAll(' (Bulky Tools Carried)', '')
        .replaceAll('Bulky Tools Carried', '')
        .trim();

    _purposeController = TextEditingController(
      text: initialPurpose == '?' ? '' : initialPurpose,
    );
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _handleBulkyToolsToggle(bool val) async {
    if (val && _isHomeCommute) {
      final primary = widget.appState.primaryVehicle;
      if (primary?.tradeToolsRegisteredAt == null) {
        final registered = await TradeGearRegistrationSheet.show(
          context,
          appState: widget.appState,
        );
        if (registered != true) {
          return;
        }
      }
    }
    setState(() {
      _bulkyToolsCarried = val;
    });
  }

  void _selectPreset(String purpose, TripClassification classification) {
    setState(() {
      _classification = classification;
      _purposeController.text = purpose;
    });
    _saveAndClose();
  }

  void _saveAndClose() {
    HapticFeedback.mediumImpact();
    var enteredPurpose = _purposeController.text.trim();
    final bool qualifiesForBulkyTools = _isHomeCommute && _bulkyToolsCarried;

    final effectiveClassification =
        qualifiesForBulkyTools ? TripClassification.business : _classification;

    if (enteredPurpose.isEmpty &&
        effectiveClassification == TripClassification.personal) {
      enteredPurpose = 'Personal Drive';
    }

    final effectivePurpose = qualifiesForBulkyTools &&
            effectiveClassification == TripClassification.business &&
            enteredPurpose.isNotEmpty
        ? (enteredPurpose.contains('Bulky Tools')
            ? enteredPurpose
            : '$enteredPurpose (Bulky Tools Carried)')
        : (effectiveClassification == TripClassification.personal &&
                _isHomeCommute &&
                !qualifiesForBulkyTools
            ? 'Personal Drive'
            : enteredPurpose);

    final updatedTrip = widget.trip.copyWith(
      purpose: effectivePurpose,
      classification: effectiveClassification,
    );

    widget.appState.updateTrip(updatedTrip);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();

    if (widget.onTripResolved != null) {
      widget.onTripResolved!(updatedTrip);
    } else {
      final isBiz = effectiveClassification == TripClassification.business;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isBiz ? AppColors.emerald : AppColors.deepNavy,
          content: Text(
            isBiz ? 'Saved: $effectivePurpose' : 'Marked as personal trip',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawDestination = widget.trip.destinationAddress ?? 'Trip Destination';
    final destinationParts = rawDestination.split(',');
    final destTitle = destinationParts.first.trim();

    final claimEst =
        widget.trip.distanceKm * widget.appState.activeTaxRule.centsPerKmRate;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    final recentPurposes = widget.appState.recentPurposes;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
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
              const SizedBox(height: 14),

              // Trip Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColor.surfaceSunken,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        LucideIcons.mapPin,
                        color: AppColors.deepNavy,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${Formatters.dateTime(widget.trip.date)} • ${widget.trip.originAddress?.isNotEmpty == true ? widget.trip.originAddress! : "Origin"} → $destTitle',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.distance(widget.trip.distanceKm),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (widget.appState.primaryVehicle?.taxMethod !=
                                TaxMethod.logbook &&
                            claimEst > 0)
                          Text(
                            '~\$${claimEst.toStringAsFixed(0)} claim',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Contextual Checkbox Row: Heavy tools (Only for Home commute)
              if (_isHomeCommute) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleBulkyToolsToggle(!_bulkyToolsCarried),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bulkyToolsCarried
                          ? AppColor.positiveTint.withValues(alpha: 0.15)
                          : AppColor.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _bulkyToolsCarried
                            ? AppColors.emerald.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _bulkyToolsCarried,
                            activeColor: AppColors.emerald,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) =>
                                _handleBulkyToolsToggle(val ?? false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tools on board (>20kg)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                _bulkyToolsCarried
                                    ? 'Claimable travel from home (no secure site locker).'
                                    : 'Commute from home is private unless transporting heavy gear.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Purpose Input (Manual & Live Edit)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trip purpose',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  GestureDetector(
                    onTap: _saveAndClose,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Free-text Input Field
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColor.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.pencil,
                        size: 15, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _purposeController,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Type purpose or tap a preset below...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.muted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _saveAndClose(),
                      ),
                    ),
                    if (_purposeController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _purposeController.clear();
                          });
                        },
                        child: const Icon(Icons.cancel,
                            size: 16, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Recent Purposes (Smart Memory)
              if (recentPurposes.isNotEmpty) ...[
                const Text(
                  'Recent',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: recentPurposes.map((p) {
                    return ActionChip(
                      label: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      backgroundColor: AppColor.surfaceSunken,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onPressed: () =>
                          _selectPreset(p, TripClassification.business),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // 1-Tap Fast Presets (Auto 2x2 grid)
              const Text(
                'Quick presets',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _QuickPurposeButton(
                      icon: LucideIcons.briefcase,
                      label: 'Client / Job',
                      subtitle: 'Site work, client job',
                      accentColor: AppColors.workBlue,
                      onTap: () => _selectPreset(
                          'Client / Job', TripClassification.business),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickPurposeButton(
                      icon: LucideIcons.shoppingBag,
                      label: 'Supplier / Bunnings',
                      subtitle: 'Materials, tools, parts',
                      accentColor: AppColors.emerald,
                      onTap: () => _selectPreset(
                          'Supplier / Materials', TripClassification.business),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickPurposeButton(
                      icon: LucideIcons.hardHat,
                      label: 'Work Site',
                      subtitle: 'Inspection, build site',
                      accentColor: AppColors.amber,
                      onTap: () => _selectPreset(
                          'Work Site Inspection', TripClassification.business),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickPurposeButton(
                      icon: LucideIcons.user,
                      label: 'Personal Drive',
                      subtitle: 'Private, non-tax trip',
                      accentColor: AppColors.muted,
                      onTap: () => _selectPreset(
                          'Personal Drive', TripClassification.personal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.clock,
                      size: 14, color: AppColors.muted),
                  label: const Text(
                    'Review later',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
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
}

class _QuickPurposeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickPurposeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColor.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
