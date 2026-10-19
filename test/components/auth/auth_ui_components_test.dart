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

    testWidgets('AuthCheckbox triggers onTextTap when label is tapped without changing checkbox', (tester) async {
      bool textTapped = false;
      bool checkboxToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthCheckbox(
              text: 'I agree to the Terms of Service',
              value: false,
              onChanged: (_) => checkboxToggled = true,
              onTextTap: () => textTapped = true,
            ),
          ),
        ),
      );

      // Tap the text label
      await tester.tap(find.text('I agree to the Terms of Service'));
      await tester.pumpAndSettle();

      expect(textTapped, isTrue);
      expect(checkboxToggled, isFalse);
    });

    testWidgets('AuthCheckbox applies underline styling when onTextTap is supplied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: const ColorScheme.light(primary: Color(0xFF1D73CB))),
          home: Scaffold(
            body: AuthCheckbox(
              text: 'Privacy Policy',
              value: false,
              onChanged: (_) {},
              onTextTap: () {},
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Privacy Policy'));
      expect(textWidget.style?.decoration, equals(TextDecoration.underline));
      expect(textWidget.style?.color, equals(const Color(0xFF1D73CB)));
    });

    testWidgets('RecaptchaDisclosure renders attribution text and clickable links', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecaptchaDisclosure(),
          ),
        ),
      );

      expect(find.byType(RecaptchaDisclosure), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('This site is protected by reCAPTCHA and the Google'),
        ),
        findsOneWidget,
      );

      // Tapping links executes cleanly without unhandled exceptions
      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();
      await tester.tap(find.text('Terms of Service'));
      await tester.pump();
    });
  });
}
