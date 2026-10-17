import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/squad/add_friend_section.dart';
import 'package:tftiapp/components/squad/suggested_squad_rail.dart';
import 'package:tftiapp/components/squad/qr_duo_sheet.dart';

void main() {
  group('AddFriendSection Widget Tests', () {
    testWidgets('Renders Grow the Squad header and action pills', (WidgetTester tester) async {
      bool qrOpened = false;
      bool linkShared = false;
      bool contactsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddFriendSection(
              isDark: false,
              primaryColor: Colors.deepPurple,
              myUid: 'my-uid-123',
              myFriendUids: const {},
              statusMessage: '',
              onOpenQrDuo: () => qrOpened = true,
              onShareLink: () => linkShared = true,
              onImportContacts: () => contactsOpened = true,
              onSendSquadRequest: (_, __) {},
              onInvitePhone: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Grow the Squad'), findsOneWidget);
      expect(find.text('QR Duo'), findsOneWidget);
      expect(find.text('Share Link'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Tap QR Duo pill
      await tester.tap(find.text('QR Duo'));
      expect(qrOpened, isTrue);

      // Tap Share Link pill
      await tester.tap(find.text('Share Link'));
      expect(linkShared, isTrue);

      // Tap Contacts pill
      await tester.tap(find.text('Contacts'));
      expect(contactsOpened, isTrue);
    });

    testWidgets('Typing query displays clear button and resets on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddFriendSection(
              isDark: false,
              primaryColor: Colors.deepPurple,
              myUid: 'my-uid-123',
              myFriendUids: const {},
              statusMessage: '',
              onOpenQrDuo: () {},
              onShareLink: () {},
              onImportContacts: () {},
              onSendSquadRequest: (_, __) {},
              onInvitePhone: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'ash');
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(find.text('ash'), findsNothing);
    });
  });

  group('SuggestedSquadRail Widget Tests', () {
    final sampleSuggestions = [
      {
        'uid': 'user-brock',
        'displayName': 'Brock',
        'contactName': 'Brock Gym',
        'username': 'brock_pewter',
        'avatarColor': Colors.amber.toARGB32(),
        'phoneNumber': '+15551234567',
      },
      {
        'uid': 'user-misty',
        'displayName': 'Misty',
        'contactName': null,
        'username': 'misty_water',
        'avatarColor': Colors.blue.toARGB32(),
        'phoneNumber': '+15559876543',
      },
    ];

    testWidgets('Renders suggested cards and handles + Add tap', (WidgetTester tester) async {
      Map<String, dynamic>? addedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestedSquadRail(
              isDark: false,
              primaryColor: Colors.deepPurple,
              isLandscape: false,
              suggestions: sampleSuggestions,
              hasContactsPermission: true,
              addedUids: const {},
              onRequestContacts: () {},
              onSquadUp: (user) => addedUser = user,
            ),
          ),
        ),
      );

      expect(find.text('SUGGESTED SQUAD'), findsOneWidget);
      expect(find.text('Brock Gym'), findsOneWidget);
      expect(find.text('@brock_pewter'), findsOneWidget);
      expect(find.text('Misty'), findsOneWidget);
      expect(find.text('@misty_water'), findsOneWidget);
      expect(find.text('+ Add'), findsNWidgets(2));

      // Tap + Add on first suggestion
      await tester.tap(find.text('+ Add').first);
      expect(addedUser?['uid'], equals('user-brock'));
    });

    testWidgets('Renders sync banner when suggestions empty and no permission', (WidgetTester tester) async {
      bool syncRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestedSquadRail(
              isDark: false,
              primaryColor: Colors.deepPurple,
              isLandscape: false,
              suggestions: const [],
              hasContactsPermission: false,
              addedUids: const {},
              onRequestContacts: () => syncRequested = true,
              onSquadUp: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Find friends on TFTI'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);

      await tester.tap(find.text('Sync'));
      expect(syncRequested, isTrue);
    });

    testWidgets('Renders in landscape without overflow', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SuggestedSquadRail(
                isDark: true,
                primaryColor: Colors.deepPurple,
                isLandscape: true,
                suggestions: sampleSuggestions,
                hasContactsPermission: true,
                addedUids: const {},
                onRequestContacts: () {},
                onSquadUp: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('SUGGESTED SQUAD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('QrDuoSheet Widget Tests', () {
    testWidgets('Renders My Code tab and switches to Scan Code tab', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrDuoSheet(
              username: 'red_trainer',
              displayName: 'Red Champion',
              avatarColor: Colors.red.toARGB32(),
              onScanned: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('My Code'), findsOneWidget);
      expect(find.text('Scan Code'), findsOneWidget);
      expect(find.text('Red Champion'), findsOneWidget);
      expect(find.text('@red_trainer'), findsOneWidget);
      expect(find.text('Copy My Invite Link'), findsOneWidget);

      // Tap Scan Code tab
      await tester.tap(find.text('Scan Code'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
