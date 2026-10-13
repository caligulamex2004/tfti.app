import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/account/account_edit_card.dart';

void main() {
  group('AccountEditCard Phone Privacy Tests', () {
    late TextEditingController nameController;
    late TextEditingController statusController;

    setUp(() {
      nameController = TextEditingController(text: 'Ash Ketchum');
      statusController = TextEditingController(text: 'Catching them all');
    });

    tearDown(() {
      nameController.dispose();
      statusController.dispose();
    });

    testWidgets('Renders phone privacy row and info icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountEditCard(
              nameController: nameController,
              statusController: statusController,
              phoneNumber: '+1 (555) 019-2834',
              showPhoneNumber: true,
              onShowPhoneChanged: (_) {},
              selectedColorValue: Colors.blue.toARGB32(),
              colors: [Colors.blue, Colors.red],
              onColorSelected: (_) {},
              onSave: () {},
            ),
          ),
        ),
      );

      expect(find.text('+1 (555) 019-2834'), findsOneWidget);
      expect(find.text('Show to Squad'), findsOneWidget);
      expect(find.byKey(const ValueKey('phone_privacy_info_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('phone_privacy_switch')), findsOneWidget);
    });

    testWidgets('Tapping info icon opens Phone Privacy dialog and closes on Got it', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountEditCard(
              nameController: nameController,
              statusController: statusController,
              phoneNumber: '+1 (555) 019-2834',
              showPhoneNumber: false,
              onShowPhoneChanged: (_) {},
              selectedColorValue: Colors.blue.toARGB32(),
              colors: [Colors.blue, Colors.red],
              onColorSelected: (_) {},
              onSave: () {},
            ),
          ),
        ),
      );

      // Dialog is not shown yet
      expect(find.text('Phone Privacy'), findsNothing);

      // Tap info icon
      await tester.tap(find.byKey(const ValueKey('phone_privacy_info_icon')));
      await tester.pumpAndSettle();

      // Dialog should be displayed with explanatory content
      expect(find.text('Phone Privacy'), findsOneWidget);
      expect(
        find.textContaining('When disabled, your phone number is hidden from your profile and blocked from manual phone searches.'),
        findsOneWidget,
      );

      // Tap 'Got it' to dismiss
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Phone Privacy'), findsNothing);
    });

    testWidgets('Toggling phone switch triggers onShowPhoneChanged and onSave', (WidgetTester tester) async {
      bool? updatedValue;
      bool saveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountEditCard(
              nameController: nameController,
              statusController: statusController,
              phoneNumber: '+1 (555) 019-2834',
              showPhoneNumber: true,
              onShowPhoneChanged: (val) {
                updatedValue = val;
              },
              selectedColorValue: Colors.blue.toARGB32(),
              colors: [Colors.blue, Colors.red],
              onColorSelected: (_) {},
              onSave: () {
                saveCalled = true;
              },
            ),
          ),
        ),
      );

      // Tap switch to toggle from true to false
      await tester.tap(find.byKey(const ValueKey('phone_privacy_switch')));
      await tester.pumpAndSettle();

      expect(updatedValue, isFalse);
      expect(saveCalled, isTrue);
    });
  });
}
