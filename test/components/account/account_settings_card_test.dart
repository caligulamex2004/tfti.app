import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/account/account_settings_card.dart';

void main() {
  group('AccountSettingsCard Tests', () {
    testWidgets(
      'Renders Preferences, Terms of Service, Privacy Policy, and Support the Developer',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccountSettingsCard(
                onPreferencesTap: () {},
                onTipJarTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Preferences'), findsOneWidget);
        expect(find.text('Notifications & Appearance'), findsOneWidget);
        expect(find.text('Terms of Service'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Support the Developer'), findsOneWidget);
        expect(find.text('Help keep the servers running'), findsOneWidget);
      },
    );

    testWidgets('Tapping Preferences triggers onPreferencesTap callback', (
      tester,
    ) async {
      bool preferencesTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSettingsCard(
              onPreferencesTap: () => preferencesTapped = true,
              onTipJarTap: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Preferences'));
      await tester.pump();

      expect(preferencesTapped, isTrue);
    });

    testWidgets('Tapping Support the Developer triggers onTipJarTap callback', (
      tester,
    ) async {
      bool tipJarTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSettingsCard(
              onPreferencesTap: () {},
              onTipJarTap: () => tipJarTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Support the Developer'));
      await tester.pump();

      expect(tipJarTapped, isTrue);
    });

    testWidgets(
      'Tapping Terms and Privacy tiles invokes legal handler gracefully',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccountSettingsCard(
                onPreferencesTap: () {},
                onTipJarTap: () {},
              ),
            ),
          ),
        );

        // Tap Terms of Service
        await tester.tap(find.text('Terms of Service'));
        await tester.pumpAndSettle();

        // Tap Privacy Policy
        await tester.tap(find.text('Privacy Policy'));
        await tester.pumpAndSettle();

        // Should not crash and UI remains stable
        expect(find.text('Terms of Service'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
      },
    );
  });
}
