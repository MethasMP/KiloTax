import '../../data/models/vehicle.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../core/constants/app_constants.dart';
import 'ato_report_service.dart';

/// Service dedicated to ITAA 1997 s 28-25 Multi-Vehicle aggregation schedules.
class MultiVehicleExportService {
  /// Generates the combined multi-vehicle lodgement slip text
  static String generateCombinedMultiVehicleSlipText({
    required List<Vehicle> vehicles,
    required Map<String, List<Trip>> tripsByVehicleId,
    required Map<String, TaxSummary> summariesByVehicleId,
    required AtoTaxRule taxRule,
    String taxpayerName = 'Tradie Client',
    String abn = '',
  }) {
    return AtoReportService.generateMultiVehicleBoxD1SummaryText(
      vehicles: vehicles,
      tripsByVehicleId: tripsByVehicleId,
      summariesByVehicleId: summariesByVehicleId,
      taxRule: taxRule,
      taxpayerName: taxpayerName,
      abn: abn,
    );
  }

  /// Generates the combined multi-vehicle Box D1 CSV schedule
  static String generateCombinedMultiVehicleCsv({
    required List<Vehicle> vehicles,
    required Map<String, List<Trip>> tripsByVehicleId,
    required Map<String, TaxSummary> summariesByVehicleId,
    required AtoTaxRule taxRule,
  }) {
    return AtoReportService.generateMultiVehicleBoxD1SummaryCsv(
      vehicles: vehicles,
      tripsByVehicleId: tripsByVehicleId,
      summariesByVehicleId: summariesByVehicleId,
      taxRule: taxRule,
    );
  }
}
