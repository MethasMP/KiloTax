import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/vehicle.dart';

/// 3D Vehicle Category Bento Item Model
class VehicleCategoryMeta {
  final VehicleType type;
  final String title;
  final String examples;
  final String taxSuitability;
  final bool isCommercialOnly;

  const VehicleCategoryMeta({
    required this.type,
    required this.title,
    required this.examples,
    required this.taxSuitability,
    this.isCommercialOnly = false,
  });
}

/// Tactile 5-Type 3D Vehicle Selector Widget
/// Designed for Step 1 of Vehicle Setup (Add Vehicle)
/// Implements Gestalt Principles:
/// - Common Region: Distinct bento card per vehicle category
/// - Similarity: Equal 3D perspective, scale and typography
/// - Figure-Ground: Selected state elevates with brand accent and depth
class VehicleCategory3dSelector extends StatelessWidget {
  final VehicleType? selectedType;
  final ValueChanged<VehicleType> onSelected;

  const VehicleCategory3dSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  static const List<VehicleCategoryMeta> categories = [
    VehicleCategoryMeta(
      type: VehicleType.ute,
      title: 'Dual-Cab & Tray Ute',
      examples: 'HiLux, Ranger, D-Max, Triton',
      taxSuitability: 'CPK (<1t) or Logbook (Most popular)',
    ),
    VehicleCategoryMeta(
      type: VehicleType.van,
      title: 'Commercial Work Van',
      examples: 'HiAce, Staria Load, Transit',
      taxSuitability: 'Logbook (Tool Carrier & High km)',
    ),
    VehicleCategoryMeta(
      type: VehicleType.suv,
      title: 'SUV & 4WD Wagon',
      examples: 'RAV4, Prado, Pajero, Outback',
      taxSuitability: 'CPK (<5,000 km) or Logbook',
    ),
    VehicleCategoryMeta(
      type: VehicleType.car,
      title: 'Sedan & Hatchback',
      examples: 'Corolla, Camry, i30, Model 3',
      taxSuitability: 'CPK (Ideal for client & site runs)',
    ),
    VehicleCategoryMeta(
      type: VehicleType.truck,
      title: 'Cab-Chassis / Light Truck',
      examples: 'Isuzu N-Series, 79 Series Tray',
      taxSuitability: 'Section 8-1 Actuals Only (>=1t Payload)',
      isCommercialOnly: true,
    ),
  ];

  static VehicleCategoryMeta getMeta(VehicleType type) {
    return categories.firstWhere(
      (c) => c.type == type,
      orElse: () => categories.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Body Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColor.brandTint,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColor.brandTintStrong),
              ),
              child: const Text(
                '5 ATO CATEGORIES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColor.brand,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, index) {
            final item = categories[index];
            final isSelected = selectedType == item.type;

            return _buildCategoryCard(context, item, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    VehicleCategoryMeta meta,
    bool isSelected,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelected(meta.type);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColor.surfaceSunken,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColor.brandBright : AppColors.border,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColor.brandBright.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: AppColor.scrimSoft,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // 3D Studio Cutout Container
              Container(
                width: 72,
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColor.brandTint
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColor.brandTintStrong
                        : AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  child: Icon(
                    meta.type.iconData,
                    size: 24,
                    color: isSelected ? AppColor.brand : AppColor.ink,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Metadata & ATO Tax Suitability
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected ? AppColor.brand : AppColors.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (meta.isCommercialOnly)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amberDark.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              's 8-1 only',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.amberDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.examples,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.taxSuitability,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: meta.isCommercialOnly
                            ? AppColors.amberDark
                            : AppColor.positiveStrong,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Selection Radio indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColor.brandBright : AppColors.border,
                    width: isSelected ? 5.5 : 1.5,
                  ),
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
