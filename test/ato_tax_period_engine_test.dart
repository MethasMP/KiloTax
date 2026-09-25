import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/tax/ato_tax_period_engine.dart';

void main() {
  const engine = AtoTaxPeriodEngine();

  group('AtoTaxPeriodEngine - Australian FY Math', () {
    test('Calculates correct FY start & cutoff dates', () {
      // 13 Sep 2026 -> FY 2026-27
      final fy = engine.forDate(DateTime(2026, 9, 13));
      expect(fy.label, equals('FY 2026–27'));
      expect(fy.startDate, equals(DateTime(2026, 7, 1)));
      expect(fy.expenseCutoffDate, equals(DateTime(2027, 6, 30, 23, 59, 59)));
      expect(fy.lodgmentOpenDate, equals(DateTime(2027, 7, 1)));
      expect(fy.selfLodgeDeadline, equals(DateTime(2027, 10, 31, 23, 59, 59)));
      expect(fy.taxAgentDeadline, equals(DateTime(2028, 5, 15, 23, 59, 59)));
    });

    test('January belongs to current FY ending in June', () {
      // 15 Jan 2027 belongs to FY 2026-27 (which started 1 Jul 2026)
      final fy = engine.forDate(DateTime(2027, 1, 15));
      expect(fy.label, equals('FY 2026–27'));
    });
  });

  group('AtoTaxPeriodEngine - Receipt Routing Decisions', () {
    final systemDate = DateTime(2026, 9, 13); // Today

    test('Receipt from Jan 2026 is rejected as Stale Prior Year when today is Sep 2026', () {
      // Jan 2026 belongs to FY 2025-26, which closed on 30 June 2026
      // Today is 13 Sep 2026 (Tax Season for FY25-26!)
      // So this receipt can be claimed in the pending upcoming tax return (lodgment)!
      final decision = engine.routeReceipt(
        receiptDate: DateTime(2026, 1, 15),
        systemDate: systemDate,
      );
      expect(decision, equals(ReceiptRoutingDecision.claimInPendingTaxReturn));
    });

    test('Receipt from 10 Aug 2026 is saved to current FY', () {
      // 10 Aug 2026 belongs to FY 2026-27
      final decision = engine.routeReceipt(
        receiptDate: DateTime(2026, 8, 10),
        systemDate: systemDate,
      );
      expect(decision, equals(ReceiptRoutingDecision.saveToCurrentFinancialYear));
    });

    test('Future receipt is strictly rejected', () {
      final decision = engine.routeReceipt(
        receiptDate: DateTime(2026, 9, 20),
        systemDate: systemDate,
      );
      expect(decision, equals(ReceiptRoutingDecision.rejectedFutureDate));
    });

    test('Receipt from 2024 is rejected as stale', () {
      final decision = engine.routeReceipt(
        receiptDate: DateTime(2024, 5, 10),
        systemDate: systemDate,
      );
      expect(decision, equals(ReceiptRoutingDecision.rejectedStalePriorYear));
    });
  });

  group('AtoTaxPeriodEngine - Tax Season Countdown', () {
    test('Shows self-lodgment countdown when in Aug/Sep/Oct', () {
      final msg = engine.getTaxSeasonCountdownMessage(
        systemDate: DateTime(2026, 9, 13),
      );
      expect(msg, contains('31 Oct deadline'));
    });

    test('Shows tax agent extension when user has accountant', () {
      final msg = engine.getTaxSeasonCountdownMessage(
        systemDate: DateTime(2026, 11, 15),
        hasRegisteredTaxAgent: true,
      );
      expect(msg, contains('15 May deadline'));
    });
  });
}
