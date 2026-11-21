import 'package:intl/intl.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';

/// Service to generate 1-Click zero-mapping import artifacts for Xero Accounting
///
/// Complies with Xero's official Bills to Pay CSV Import Schema:
/// *ContactName, *InvoiceNumber, *InvoiceDate, *DueDate, Total, *Description, *Quantity, *UnitAmount, *AccountCode, *TaxType
class XeroExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Generates a standardized Xero Bills CSV import string.
  /// An Australian accountant can drag-and-drop this directly into:
  /// Business -> Bills to pay -> Import -> Bills
  static String generateBillsCsv({
    required List<VehicleExpense> expenses,
    required Vehicle vehicle,
    String motorVehicleAccountCode = '489',
    String travelAccountCode = '493',
  }) {
    final buffer = StringBuffer();

    // Mandatory Xero Bills CSV Headers
    buffer.writeln(
      '*ContactName,*InvoiceNumber,*InvoiceDate,*DueDate,Total,*Description,*Quantity,*UnitAmount,*AccountCode,*TaxType',
    );

    for (final exp in expenses) {
      final merchant = (exp.supplier != null && exp.supplier!.trim().isNotEmpty)
          ? exp.supplier!.trim()
          : (exp.receiptAudit?.ocrMerchant ?? exp.category.displayName);
      final safeMerchant = _escapeCsv(merchant);

      final invoiceNum = _escapeCsv(
        exp.receiptAudit?.batchId ?? exp.clientDedupId ?? 'EXP-${exp.id}',
      );

      final dateStr = _dateFormat.format(exp.date);
      final dueDateStr = dateStr; // Immediate due date for cash expenses
      final totalStr = exp.amount.toStringAsFixed(2);
      final unitAmountStr = exp.amount.toStringAsFixed(2);

      final desc =
          '${exp.category.displayName} - ${vehicle.regoPlate} (${exp.businessPercentage.toInt()}% Business)';
      final safeDesc = _escapeCsv(desc);

      // Map account code per category
      final accountCode = (exp.category == ExpenseCategory.tollsParking)
          ? travelAccountCode
          : motorVehicleAccountCode;

      final hasGst = (exp.gstAmount != null && exp.gstAmount! > 0) ||
          (exp.amount > 0 && exp.gstAmount == null);
      final taxType = hasGst ? 'GST on Expenses' : 'BAS Excluded';

      buffer.writeln(
        '$safeMerchant,$invoiceNum,$dateStr,$dueDateStr,$totalStr,$safeDesc,1,$unitAmountStr,$accountCode,$taxType',
      );
    }

    return buffer.toString();
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
