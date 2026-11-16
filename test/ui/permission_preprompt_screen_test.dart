import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/ui/screens/onboarding/widgets/permission_preprompt_screen.dart';

void main() {
  group('PermissionPrepromptScreen Widget Tests', () {
    testWidgets('renders all permission guidance bullets and buttons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PermissionPrepromptScreen(
            onEnableTracking: () async {},
            onSkipOrManual: () {},
          ),
        ),
      );

      expect(find.text('Automatic Trip Logging'), findsOneWidget);
      expect(find.text('Trip records for review'), findsOneWidget);
      expect(find.text('Select "Always Allow"'), findsOneWidget);
      expect(find.text('Battery-Optimised Motion Sensors'), findsOneWidget);
      expect(find.text('Enable automatic tracking'), findsOneWidget);
      expect(find.text('I’ll log trips manually instead'), findsOneWidget);
    });

    testWidgets('calls onSkipOrManual when manual link is tapped',
        (tester) async {
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PermissionPrepromptScreen(
            onEnableTracking: () async {},
            onSkipOrManual: () {
              skipped = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('I’ll log trips manually instead'));
      await tester.pump();

      expect(skipped, isTrue);
    });

    testWidgets('calls onEnableTracking and displays loading state',
        (tester) async {
      bool enabledCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PermissionPrepromptScreen(
            onEnableTracking: () async {
              enabledCalled = true;
            },
            onSkipOrManual: () {},
          ),
        ),
      );

      await tester.tap(find.text('Enable automatic tracking'));
      await tester.pump();

      expect(enabledCalled, isTrue);
    });

    testWidgets('does not overflow on small screen heights (e.g. iPhone SE)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PermissionPrepromptScreen(
            onEnableTracking: () async {},
            onSkipOrManual: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
