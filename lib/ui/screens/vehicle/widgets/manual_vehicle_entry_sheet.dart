import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../services/vehicle/australian_vehicle_catalog.dart';
import '../../../widgets/adaptive_row.dart';
import '../../../widgets/tactile_primary_button.dart';

class ManualVehicleEntrySheet extends StatefulWidget {
  final void Function(String make, String model, VehicleType type) onSubmitted;

  const ManualVehicleEntrySheet({super.key, required this.onSubmitted});

  @override
  State<ManualVehicleEntrySheet> createState() =>
      __ManualVehicleEntrySheetState();
}

class __ManualVehicleEntrySheetState extends State<ManualVehicleEntrySheet> {
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
            AdaptiveRow(
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
            AdaptiveRow(
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
                      return AustralianVehicleCatalog.popularMakes
                          .where((make) {
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
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
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
                              borderSide:
                                  const BorderSide(color: AppColor.line)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColor.line)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColor.ink, width: 1.4)),
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
                            constraints: const BoxConstraints(
                                maxHeight: 180, maxWidth: 220),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColor.line),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColor.line),
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
                          borderSide: const BorderSide(
                              color: AppColor.ink, width: 1.4)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                          child: AdaptiveRow(
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
              label: 'Use this vehicle',
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
