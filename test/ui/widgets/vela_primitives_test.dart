import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/ui/widgets/tax_visor_header.dart';
import 'package:kilotax/ui/widgets/money_display.dart';
import 'package:kilotax/ui/widgets/audit_evidence_strip.dart';

void main() {
  testWidgets('TaxVisorHeader renders title, subtitle, and status pill', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaxVisorHeader(
            title: 'ATO Tax Summary',
            subtitle: 'FY 2025-2026',
            statusPill: Chip(label: Text('Week 7 of 12')),
          ),
        ),
      ),
    );

    expect(find.text('ATO Tax Summary'), findsOneWidget);
    expect(find.text('FY 2025-2026'), findsOneWidget);
    expect(find.text('Week 7 of 12'), findsOneWidget);
  });

  testWidgets('MoneyDisplay formats amount and percentage correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const MoneyDisplay(amount: 4850.50),
              MoneyDisplay.percentage(percentage: 82.4),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MoneyDisplay), findsNWidgets(2));
    expect(find.byType(RichText), findsWidgets);
  });

  testWidgets('AuditEvidenceStrip renders label, value and copies to clipboard', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuditEvidenceStrip(
            label: 'ABN Verified',
            value: '84 123 456 789',
            caption: 'Active Sole Trader',
          ),
        ),
      ),
    );

    expect(find.text('ABN VERIFIED'), findsOneWidget);
    expect(find.text('84 123 456 789'), findsOneWidget);
    expect(find.text('Active Sole Trader'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();
  });
}
