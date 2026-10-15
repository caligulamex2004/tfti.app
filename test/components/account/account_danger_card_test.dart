import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/account/account_danger_card.dart';

void main() {
  group('AccountLogoutCard & AccountDangerCard Tests', () {
    testWidgets('AccountLogoutCard renders Log Out and triggers callback on tap', (
      tester,
    ) async {
      bool loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountLogoutCard(
              onLogout: () => loggedOut = true,
            ),
          ),
        ),
      );

      expect(find.text('Log Out'), findsOneWidget);
      expect(
        find.text('Sign out of your account on this device'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.logout), findsOneWidget);

      await tester.tap(find.text('Log Out'));
      await tester.pump();

      expect(loggedOut, isTrue);
    });

    testWidgets(
      'AccountDangerCard renders DANGER ZONE header, warning icon, and triggers onDeleteAccount',
      (tester) async {
        bool accountDeleted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccountDangerCard(
                onDeleteAccount: () => accountDeleted = true,
              ),
            ),
          ),
        );

        expect(find.text('DANGER ZONE'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('Delete Account'), findsOneWidget);
        expect(
          find.text('Permanently wipe your account and all data'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.delete_forever), findsOneWidget);

        await tester.tap(find.text('Delete Account'));
        await tester.pump();

        expect(accountDeleted, isTrue);
      },
    );

    testWidgets('AccountDangerCard with onLogout renders both Logout and Danger Zone', (
      tester,
    ) async {
      bool loggedOut = false;
      bool accountDeleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountDangerCard(
                onLogout: () => loggedOut = true,
                onDeleteAccount: () => accountDeleted = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('DANGER ZONE'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);

      await tester.tap(find.text('Log Out'));
      await tester.pump();
      expect(loggedOut, isTrue);

      await tester.tap(find.text('Delete Account'));
      await tester.pump();
      expect(accountDeleted, isTrue);
    });
  });
}
