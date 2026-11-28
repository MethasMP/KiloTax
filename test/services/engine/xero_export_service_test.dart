import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/xero_export_service.dart';

void main() {
  group('XeroExportService', () {
    test('generates compliant Xero Bills CSV with exact mandatory headers', () {
      final vehicle = Vehicle(
        id: 'v-hilux-1',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TRD-999',
        initialOdometer: 50000,
        taxMethod: TaxMethod.logbook,
      );

      final expenses = [
        VehicleExpense(
          id: 'exp-fuel-1',
          vehicleId: vehicle.id,
          amount: 110.00,
          date: DateTime(2025, 8, 15),
          category: ExpenseCategory.fuel,
          supplier: 'BP Connect Mascot',
          supplierAbn: '51 824 753 556',
          gstAmount: 10.00,
          businessPercentage: 80.0,
        ),
        VehicleExpense(
          id: 'exp-maint-1',
          vehicleId: vehicle.id,
          amount: 440.00,
          date: DateTime(2025, 9, 20),
          category: ExpenseCategory.maintenanceTyres,
          supplier: 'Ultra Tune Alexandria',
          gstAmount: 40.00,
          businessPercentage: 80.0,
        ),
      ];

      final csvContent = XeroExportService.generateBillsCsv(
        expenses: expenses,
        vehicle: vehicle,
      );

      expect(csvContent, isNotEmpty);
      final lines = csvContent.trim().split('\n');

      // 1. Verify exact Xero Bills standard CSV header line
      expect(
        lines.first,
        equals(
          '*ContactName,*InvoiceNumber,*InvoiceDate,*DueDate,Total,*Description,*Quantity,*UnitAmount,*AccountCode,*TaxType',
        ),
      );

      // 2. Verify rows match
      expect(lines.length, equals(3)); // 1 header + 2 expenses
      expect(lines[1], contains('BP Connect Mascot'));
      expect(lines[1], contains('489')); // Motor Vehicle Expenses
      expect(lines[1], contains('GST on Expenses'));
      expect(lines[1], contains('110.00'));

      expect(lines[2], contains('Ultra Tune Alexandria'));
      expect(lines[2], contains('440.00'));
    });
  });
}
