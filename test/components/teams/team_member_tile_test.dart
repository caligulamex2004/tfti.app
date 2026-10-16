import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tftiapp/components/teams/team_member_tile.dart';
import 'package:tftiapp/services/contact_resolver.dart';

void main() {
  final sampleProfile = {
    'uid': 'user-nightwolf',
    'displayName': 'NightWolf',
    'username': 'nightwolf99',
    'phoneNumber': '+15551234567',
    'avatarColor': Colors.blue.toARGB32(),
    'hp': 92,
    'mana': 64,
    'isGoated': false,
  };

  tearDown(() {
    ContactResolver.instance.clearForTest();
  });

  Widget buildTile({
    Map<String, dynamic>? profile,
    int index = 0,
    bool sortByScore = false,
    bool isBlocked = false,
    Future<bool> Function()? onConfirmDismiss,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TeamMemberTile(
          profile: profile ?? sampleProfile,
          index: index,
          sortByScore: sortByScore,
          isBlocked: isBlocked,
          onConfirmDismiss: onConfirmDismiss ?? () async => true,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  group('TeamMemberTile Tests', () {
    testWidgets(
      'Renders profile displayName, @username, and monogram when no contact is resolved',
      (tester) async {
        await tester.pumpWidget(buildTile());

        expect(find.text('NightWolf'), findsOneWidget);
        expect(find.text('@nightwolf99'), findsOneWidget);
        expect(find.text('N'), findsOneWidget);
        expect(find.byIcon(Icons.contact_phone_outlined), findsNothing);
        expect(find.byIcon(Symbols.star), findsNothing);
        expect(find.byIcon(Icons.block), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      },
    );

    testWidgets(
      'Renders local contact name as primary title, contact badge, updated monogram, and ~ DisplayName (@username) subtitle when resolved',
      (tester) async {
        ContactResolver.instance.seedForTest({
          '(555) 123-4567': 'Dave Miller',
        });

        await tester.pumpWidget(buildTile());

        expect(find.text('Dave Miller'), findsOneWidget);
        expect(find.text('D'), findsOneWidget);
        expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
        expect(find.text('~ NightWolf (@nightwolf99)'), findsOneWidget);
      },
    );

    testWidgets(
      'Omits redundant ~ DisplayName in subtitle when contact name matches profile displayName',
      (tester) async {
        ContactResolver.instance.seedForTest({
          '+15551234567': 'NightWolf',
        });

        await tester.pumpWidget(buildTile());

        expect(find.text('NightWolf'), findsOneWidget);
        expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
        expect(find.text('@nightwolf99'), findsOneWidget);
        expect(find.text('~ NightWolf (@nightwolf99)'), findsNothing);
      },
    );

    testWidgets(
      'Renders VIP star icon when isGoated is true and hides it when isBlocked is true',
      (tester) async {
        final goatedProfile = {
          ...sampleProfile,
          'isGoated': true,
        };

        await tester.pumpWidget(buildTile(profile: goatedProfile));
        expect(find.byIcon(Symbols.star), findsOneWidget);
        expect(find.byIcon(Icons.block), findsNothing);

        await tester.pumpWidget(
          buildTile(profile: goatedProfile, isBlocked: true),
        );
        expect(find.byIcon(Symbols.star), findsNothing);
        expect(find.byIcon(Icons.block), findsOneWidget);
      },
    );

    testWidgets(
      'Renders rank badge and HP/Mana score column when sortByScore is true',
      (tester) async {
        await tester.pumpWidget(buildTile(index: 0, sortByScore: true));

        expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
        expect(find.text('92'), findsOneWidget);
        expect(find.text('64'), findsOneWidget);
        expect(find.byIcon(Icons.whatshot), findsOneWidget);
        expect(find.byIcon(Icons.water_drop), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );

    testWidgets(
      'Triggers onTap when tapped and onConfirmDismiss when swiped',
      (tester) async {
        bool tapped = false;
        bool confirmCalled = false;

        await tester.pumpWidget(
          buildTile(
            onTap: () => tapped = true,
            onConfirmDismiss: () async {
              confirmCalled = true;
              return false;
            },
          ),
        );

        await tester.tap(find.text('NightWolf'));
        await tester.pump();
        expect(tapped, isTrue);

        await tester.drag(find.text('NightWolf'), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(confirmCalled, isTrue);
      },
    );
  });
}
