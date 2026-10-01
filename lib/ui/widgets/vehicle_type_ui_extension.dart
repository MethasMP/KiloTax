import 'package:flutter/material.dart';
import '../../data/models/vehicle.dart';

/// UI-layer presentation extension for [VehicleType] (Material icon mappings)
extension VehicleTypeUIExtension on VehicleType {
  IconData get iconData {
    switch (this) {
      case VehicleType.ute:
        return Icons
            .minor_crash_rounded; // Front-facing vehicle badge for Ute / Work rig
      case VehicleType.van:
        return Icons.airport_shuttle_rounded; // Commercial van
      case VehicleType.suv:
        return Icons.directions_car_filled_rounded; // SUV
      case VehicleType.truck:
        return Icons.local_shipping_rounded; // Truck
      case VehicleType.car:
        return Icons.directions_car_rounded; // Car / Sedan
    }
  }
}
