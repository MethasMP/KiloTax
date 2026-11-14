import '../../data/models/vehicle.dart';

/// Vehicle Classification Engine (ATO ITAA 1997 s. 995-1 & Division 28 Guard)
///
/// Under the Income Tax Assessment Act 1997 (ITAA 1997) s. 995-1(1):
/// A "car" is a motor vehicle (except a motorcycle or similar vehicle) designed to carry:
/// 1. A load of less than 1 tonne (1,000 kg); AND
/// 2. Fewer than 9 passengers.
///
/// Vehicles carrying >= 1,000 kg load (payload) or >= 9 passengers are NOT "cars".
/// They are classified as commercial vehicles / utilities / trucks.
/// Under ATO tax law, commercial vehicles:
/// - Are INELIGIBLE for Division 28 methods (Cents per km / Box D1).
/// - Must claim deductions as general business deductions under Section 8-1
///   (Actual expenses / operating costs only).
class VehicleClassificationEngine {
  /// Payload limit for car definition in kilograms under ITAA 1997 s 995-1
  static const double maxCarPayloadKg = 1000.0;

  /// Seating limit for car definition under ITAA 1997 s 995-1
  static const int maxCarSeatingCapacity = 8;

  /// Checks if the vehicle has a payload capacity of 1,000 kg (1 tonne) or greater.
  static bool isOverOneTonnePayload(Vehicle vehicle) {
    if (vehicle.payloadKg != null) {
      return vehicle.payloadKg! >= maxCarPayloadKg;
    }
    // Fallback: Trucks are always commercial vehicles over 1 tonne payload
    if (vehicle.effectiveVehicleType == VehicleType.truck) {
      return true;
    }
    return false;
  }

  /// Determines if the vehicle meets the statutory definition of a "car"
  /// under ITAA 1997 section 995-1.
  static bool isCarForTaxPurposes(Vehicle vehicle) {
    // 1. Explicit truck type check
    if (vehicle.effectiveVehicleType == VehicleType.truck) {
      return false;
    }

    // 2. Seating capacity check (must be fewer than 9 passengers)
    if (vehicle.seatingCapacity != null &&
        vehicle.seatingCapacity! > maxCarSeatingCapacity) {
      return false;
    }

    // 3. Payload threshold check (must be less than 1 tonne)
    if (vehicle.payloadKg != null &&
        vehicle.payloadKg! >= maxCarPayloadKg) {
      return false;
    }

    return true;
  }

  /// Checks if the vehicle is eligible for Cents per Kilometre (CPK) claims under Box D1.
  /// Only vehicles defined as "cars" qualify for Division 28 Cents per km.
  static bool isEligibleForCpk(Vehicle vehicle) {
    return isCarForTaxPurposes(vehicle);
  }

  /// Returns the allowable ATO tax methods for this vehicle.
  /// If commercial (non-car), only Section 8-1 actual expenses are permitted.
  /// If car, both Cents per Kilometre and Logbook are allowed.
  static List<TaxMethod> allowedTaxMethods(Vehicle vehicle) {
    if (!isCarForTaxPurposes(vehicle)) {
      return const [TaxMethod.actualExpenses];
    }
    return const [TaxMethod.centsPerKm, TaxMethod.logbook];
  }

  /// Explanatory reason when a vehicle is disqualified from CPK / Division 28 claims.
  static String? disqualificationReason(Vehicle vehicle) {
    if (vehicle.payloadKg != null && vehicle.payloadKg! >= maxCarPayloadKg) {
      return 'Payload capacity is ${vehicle.payloadKg!.toStringAsFixed(0)} kg (>= 1,000 kg). Under ITAA 1997 s 995-1, commercial utilities with 1 tonne+ load capacity cannot claim Cents per km (Box D1) and must claim actual expenses under Section 8-1.';
    }
    if (vehicle.seatingCapacity != null &&
        vehicle.seatingCapacity! > maxCarSeatingCapacity) {
      return 'Seating capacity is ${vehicle.seatingCapacity} (designed for 9 or more passengers). Non-car commercial transport must claim actual expenses under Section 8-1.';
    }
    if (vehicle.effectiveVehicleType == VehicleType.truck) {
      return 'Trucks and heavy commercial vehicles fall outside ITAA 1997 Division 28 and must claim actual operating expenses under Section 8-1.';
    }
    return null;
  }
}
