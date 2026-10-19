import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/forms/vibe_options_card.dart';

void main() {
  group('VibeOptionsCard Widget Tests', () {
    testWidgets('Renders options header, badge, and option cards', (
      WidgetTester tester,
    ) async {
      final titleCtrl1 = TextEditingController(text: 'Beach Volleyball');
      final locCtrl1 = TextEditingController(text: 'Mission Beach');
      final titleCtrl2 = TextEditingController(text: 'Bonfire');
      final locCtrl2 = TextEditingController();

      final pollOptions = [
        {'id': 'opt_1', 'title': titleCtrl1, 'location': locCtrl1},
        {'id': 'opt_2', 'title': titleCtrl2, 'location': locCtrl2},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VibeOptionsCard(
                pollOptions: pollOptions,
                onAddOption: () {},
                onRemoveOption: (_) {},
                onSelectLocation: (_) {},
                onClearLocation: (_) {},
              ),
            ),
          ),
        ),
      );

      // Card Title uppercased
      expect(find.text('VIBE OPTIONS'), findsOneWidget);
      expect(find.text('2/5 OPTIONS'), findsOneWidget);

      // Option Badges
      expect(find.text('OPTION 1'), findsOneWidget);
      expect(find.text('OPTION 2'), findsOneWidget);

      // Option 1 & 2 have no remove button
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Add Option CTA exists
      expect(find.text('Add Option (2/5)'), findsOneWidget);
    });

    testWidgets('Displays remove button for option 3 and triggers onRemoveOption', (
      WidgetTester tester,
    ) async {
      final titleCtrl1 = TextEditingController(text: 'Activity 1');
      final locCtrl1 = TextEditingController();
      final titleCtrl2 = TextEditingController(text: 'Activity 2');
      final locCtrl2 = TextEditingController();
      final titleCtrl3 = TextEditingController(text: 'Activity 3');
      final locCtrl3 = TextEditingController();

      final pollOptions = [
        {'id': 'opt_1', 'title': titleCtrl1, 'location': locCtrl1},
        {'id': 'opt_2', 'title': titleCtrl2, 'location': locCtrl2},
        {'id': 'opt_3', 'title': titleCtrl3, 'location': locCtrl3},
      ];

      int? removedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VibeOptionsCard(
                pollOptions: pollOptions,
                onAddOption: () {},
                onRemoveOption: (index) => removedIndex = index,
                onSelectLocation: (_) {},
                onClearLocation: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('3/5 OPTIONS'), findsOneWidget);
      expect(find.text('OPTION 3'), findsOneWidget);

      // Only Option 3 has remove icon
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(removedIndex, equals(2));
    });

    testWidgets('Tapping add option button triggers onAddOption', (
      WidgetTester tester,
    ) async {
      bool addTapped = false;
      final pollOptions = [
        {'id': '1', 'title': TextEditingController(), 'location': TextEditingController()},
        {'id': '2', 'title': TextEditingController(), 'location': TextEditingController()},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VibeOptionsCard(
                pollOptions: pollOptions,
                onAddOption: () => addTapped = true,
                onRemoveOption: (_) {},
                onSelectLocation: (_) {},
                onClearLocation: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Option (2/5)'));
      expect(addTapped, isTrue);
    });
  });
}
