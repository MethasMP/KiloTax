import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/core/theme/app_motion.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/bulky_tools_toggle_chip.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('BulkyToolsToggleChip', () {
    testWidgets('meets 48x48 pt ergonomic touch target requirement',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsToggleChip(
                isSelected: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final finder = find.byType(BulkyToolsToggleChip);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
        'renders inactive surfaceMuted state with Lucide hammer and micro-copy',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsToggleChip(
                isSelected: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify inactive micro-copy and icon
      expect(find.text('Bulky Tools'), findsOneWidget);
      expect(find.byIcon(LucideIcons.hammer), findsOneWidget);
      expect(find.text('Tools on Board'), findsNothing);
      expect(find.text(r'+$18.20 AUD'), findsNothing);

      // Verify recessed surfaceMuted styling
      final animatedContainerFinder = find.descendant(
        of: find.byType(BulkyToolsToggleChip),
        matching: find.byType(AnimatedContainer),
      );
      final animatedContainer =
          tester.widget<AnimatedContainer>(animatedContainerFinder);
      final decoration = animatedContainer.decoration as BoxDecoration;
      expect(decoration.color, equals(AppColor.surfaceMuted));
      final border = decoration.border as Border;
      expect(border.top.color, equals(AppColor.line));

      // Verify inactive icon color
      final iconWidget = tester.widget<Icon>(find.byIcon(LucideIcons.hammer));
      expect(iconWidget.color, equals(AppColor.inkMuted));
    });

    testWidgets('does not invent a deduction when no estimate is supplied',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BulkyToolsToggleChip(
        isSelected: true,
        onChanged: (_) {},
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Tools on Board'), findsOneWidget);
      expect(find.textContaining('AUD'), findsNothing);
    });

    testWidgets(
        'springs up rolling deduction ticker and switches to positiveTint on toggle ON',
        (tester) async {
      bool isSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BulkyToolsToggleChip(
                  isSelected: isSelected,
                  estimatedDeductionDelta: r'+$18.20 AUD',
                  onChanged: (val) {
                    setState(() {
                      isSelected = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text(r'+$18.20 AUD'), findsNothing);

      // Tap to toggle ON
      await tester.tap(find.byType(BulkyToolsToggleChip));
      await tester.pump();

      // AnimatedSwitcher should transition ticker into place
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedSwitcher), findsOneWidget);

      await tester.pumpAndSettle();

      // Active state verification
      expect(isSelected, isTrue);
      expect(find.text('Tools on Board'), findsOneWidget);
      expect(find.text('ATO s 8-1'), findsOneWidget);
      expect(find.text(r'+$18.20 AUD'), findsOneWidget);

      // Verify confident stamped positiveTint styling
      final animatedContainerFinder = find.descendant(
        of: find.byType(BulkyToolsToggleChip),
        matching: find.byType(AnimatedContainer),
      );
      final animatedContainer =
          tester.widget<AnimatedContainer>(animatedContainerFinder);
      final decoration = animatedContainer.decoration as BoxDecoration;
      expect(decoration.color, equals(AppColor.positiveTint));
      final border = decoration.border as Border;
      expect(border.top.color, equals(AppColor.positiveStrong));

      // Verify active positiveInk text and icon
      final iconWidget = tester.widget<Icon>(find.byIcon(LucideIcons.hammer));
      expect(iconWidget.color, equals(AppColor.positiveInk));
      final labelWidget = tester.widget<Text>(find.text('Tools on Board'));
      expect(labelWidget.style?.color, equals(AppColor.positiveInk));
    });

    testWidgets('supports dynamic custom deduction delta in rolling ticker',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsToggleChip(
                isSelected: true,
                estimatedDeductionDelta: r'+$35.50 AUD',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text(r'+$35.50 AUD'), findsOneWidget);
      expect(find.text(r'+$18.20 AUD'), findsNothing);
    });

    testWidgets(
        'triggers mechanical haptics: commit on toggle ON, light on toggle OFF',
        (tester) async {
      final List<String> hapticFeedbackCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'HapticFeedback.vibrate') {
            hapticFeedbackCalls.add(methodCall.arguments as String);
          }
          return null;
        },
      );

      bool isSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BulkyToolsToggleChip(
                  isSelected: isSelected,
                  onChanged: (val) {
                    setState(() {
                      isSelected = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap ON -> AppHaptic.commit (mediumImpact)
      await tester.tap(find.byType(BulkyToolsToggleChip));
      await tester.pumpAndSettle();
      expect(hapticFeedbackCalls, contains('HapticFeedbackType.mediumImpact'));

      // Tap OFF -> AppHaptic.light (lightImpact)
      await tester.tap(find.byType(BulkyToolsToggleChip));
      await tester.pumpAndSettle();
      expect(hapticFeedbackCalls, contains('HapticFeedbackType.lightImpact'));
    });

    testWidgets('notifies onChanged callback with toggled value on tap',
        (tester) async {
      bool? latestValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsToggleChip(
                isSelected: false,
                onChanged: (val) => latestValue = val,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BulkyToolsToggleChip));
      await tester.pump();

      expect(latestValue, isTrue);
    });

    testWidgets('applies press motion scale down and recovers on release',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsToggleChip(
                isSelected: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(BulkyToolsToggleChip)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Animated scale should compress towards AppMotion.pressScale
      final scaleFinder = find.descendant(
        of: find.byType(BulkyToolsToggleChip),
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget);
      final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidget.scale.value, closeTo(AppMotion.pressScale, 0.01));

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(scaleWidget.scale.value, closeTo(1.0, 0.01));
    });

    testWidgets(
        'renders informational suggestion without implying confirmation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BulkyToolsToggleChip(
                isSelected: false,
                isSuggested: true,
                suggestionLabel: 'Suggested based on supplier stop',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // A contextual suggestion must remain unselected.
      expect(find.text('Bulky Tools'), findsOneWidget);
      expect(find.text('Suggested based on supplier stop'), findsOneWidget);
      expect(
          tester
              .widget<BulkyToolsToggleChip>(find.byType(BulkyToolsToggleChip))
              .isSelected,
          isFalse);
      expect(find.byIcon(LucideIcons.hammer), findsNWidgets(2));
    });
  });
}
