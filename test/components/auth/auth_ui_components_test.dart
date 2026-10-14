import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/auth/auth_ui_components.dart';

void main() {
  group('AuthUIComponents Tests', () {
    testWidgets('AuthTextField renders label, icon, prefixText, and updates controller', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthTextField(
              controller: controller,
              label: 'Username',
              icon: Icons.alternate_email,
              prefixText: '@',
              maxLength: 20,
            ),
          ),
        ),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('@'), findsOneWidget);
      expect(find.byIcon(Icons.alternate_email), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ash_ketchum');
      await tester.pump();

      expect(controller.text, 'ash_ketchum');
    });

    testWidgets('AuthButton renders text and triggers onPressed when not loading', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: 'Sign In',
              isLoading: false,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('AuthButton shows CircularProgressIndicator and disables tap when isLoading is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: 'Sign In',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Sign In'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('AuthCheckbox toggles and calls onChanged callback', (tester) async {
      bool isChecked = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: AuthCheckbox(
                  text: 'I agree to the Terms',
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      isChecked = val ?? false;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('I agree to the Terms'), findsOneWidget);
      final checkboxFinder = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(isChecked, isTrue);
      expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
    });
  });
}
