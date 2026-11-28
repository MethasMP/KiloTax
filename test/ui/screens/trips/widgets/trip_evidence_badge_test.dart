import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/trip_evidence_badge.dart';
import 'package:kiloclaim/ui/screens/workflow/workflow_screen.dart';

void main() {
  group('TripEvidenceBadge Widget Tests', () {
    testWidgets('unlinked trip renders amber "Needs evidence" badge with ≥48dp target', (tester) async {
      final unlinkedTrip = Trip(
        id: 'unlinked_trip_1',
        vehicleId: 'veh_1',
        date: DateTime.now(),
        purpose: 'Client visit',
        evidenceLinks: const [], // unlinked
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TripEvidenceBadge(unlinkedTrip),
            ),
          ),
        ),
      );

      expect(find.text('Needs evidence'), findsOneWidget);

      final size = tester.getSize(find.byType(TripEvidenceBadge));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('linked trip renders no badge', (tester) async {
      final linkedTrip = Trip(
        id: 'linked_trip_1',
        vehicleId: 'veh_1',
        date: DateTime.now(),
        purpose: 'Site work',
        evidenceLinks: [
          TripEvidenceLink(
            id: 'link_1',
            tripId: 'linked_trip_1',
            expenseId: 'exp_1',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TripEvidenceBadge(linkedTrip),
            ),
          ),
        ),
      );

      expect(find.text('Needs evidence'), findsNothing);
    });

    testWidgets('tapping badge opens WorkflowScreen for that trip', (tester) async {
      final appState = AppState();
      final unlinkedTrip = Trip(
        id: 'unlinked_trip_1',
        vehicleId: 'veh_1',
        date: DateTime.now(),
        purpose: 'Client visit',
        evidenceLinks: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TripEvidenceBadge(unlinkedTrip, appState: appState),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Needs evidence'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkflowScreen), findsOneWidget);
    });
  });
}
