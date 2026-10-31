import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/chat/whisper_recipient_sheet.dart';
import 'package:tftiapp/services/contact_resolver.dart';

void main() {
  group('WhisperRecipientSheet Widget Tests', () {
    final guests = [
      {
        'uid': 'user-adam',
        'displayName': 'Adam Smith',
        'tag': 'adams',
        'avatarUrl': null,
        'avatarColor': Colors.blue.toARGB32(),
        'phoneNumber': '+15551112222',
        'status': 'accepted',
      },
      {
        'uid': 'user-beth',
        'displayName': 'Beth Davis',
        'tag': 'bethd',
        'avatarUrl': null,
        'avatarColor': Colors.purple.toARGB32(),
        'phoneNumber': '+15553334444',
        'status': 'accepted',
      },
      {
        'uid': 'user-charlie',
        'displayName': 'Charlie Brown',
        'tag': 'charlieb',
        'avatarUrl': null,
        'avatarColor': Colors.green.toARGB32(),
        'phoneNumber': '+15557778888',
        'status': 'declined', // Should be excluded
      },
    ];

    tearDown(() {
      ContactResolver.instance.clearForTest();
    });

    testWidgets('Renders first names and excludes declined guests', (tester) async {
      Map<String, dynamic>? selectedRecipient;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhisperRecipientSheet(
              eventGuests: guests,
              onSelectRecipient: (recipient) {
                selectedRecipient = recipient;
              },
            ),
          ),
        ),
      );

      expect(find.text('Whisper Message'), findsOneWidget);
      expect(find.text('Only you and this person will see the message'), findsOneWidget);

      // Adam and Beth first names should appear
      expect(find.text('Adam'), findsOneWidget);
      expect(find.text('@adams'), findsOneWidget);
      expect(find.text('Beth'), findsOneWidget);
      expect(find.text('@bethd'), findsOneWidget);

      // Declined Charlie Brown should not appear
      expect(find.text('Charlie'), findsNothing);

      // Tap Adam
      await tester.tap(find.text('Adam'));
      await tester.pumpAndSettle();

      expect(selectedRecipient, isNotNull);
      expect(selectedRecipient!['uid'], equals('user-adam'));
    });

    testWidgets('Resolves contact first name and shows contact icon & display name hint', (tester) async {
      ContactResolver.instance.seedForTest({
        '+15551112222': 'Alexander Hamilton',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhisperRecipientSheet(
              eventGuests: guests,
              onSelectRecipient: (_) {},
            ),
          ),
        ),
      );

      // Resolves to contact first name "Alexander"
      expect(find.text('Alexander'), findsOneWidget);
      expect(find.text('~ Adam Smith · @adams'), findsOneWidget);
      expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
    });

    testWidgets('Search query filters guests correctly by first name or handle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhisperRecipientSheet(
              eventGuests: guests,
              onSelectRecipient: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Adam'), findsOneWidget);
      expect(find.text('Beth'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'beth');
      await tester.pumpAndSettle();

      expect(find.text('Adam'), findsNothing);
      expect(find.text('Beth'), findsOneWidget);
    });

    testWidgets('Sorts guests in ascending alphabetical order by displayed name', (tester) async {
      final unsortedGuests = [
        {
          'uid': 'user-zoe',
          'displayName': 'Zoe Saldana',
          'tag': 'zoes',
          'avatarUrl': null,
          'phoneNumber': '+15559990000',
          'status': 'accepted',
        },
        {
          'uid': 'user-adam',
          'displayName': 'Adam Smith',
          'tag': 'adams',
          'avatarUrl': null,
          'phoneNumber': '+15551112222',
          'status': 'accepted',
        },
        {
          'uid': 'user-charlie',
          'displayName': 'Charlie Brown',
          'tag': 'charlieb',
          'avatarUrl': null,
          'phoneNumber': '+15557778888',
          'status': 'accepted',
        },
        {
          'uid': 'user-beth',
          'displayName': 'Beth Davis',
          'tag': 'bethd',
          'avatarUrl': null,
          'phoneNumber': '+15553334444',
          'status': 'accepted',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhisperRecipientSheet(
              eventGuests: unsortedGuests,
              onSelectRecipient: (_) {},
            ),
          ),
        ),
      );

      final listTiles = find.byType(ListTile);
      expect(listTiles, findsNWidgets(4));

      final firstTiles = tester.widgetList<ListTile>(listTiles).map((tile) {
        return (tile.title as Text).data;
      }).toList();

      expect(firstTiles, equals(['Adam', 'Beth', 'Charlie', 'Zoe']));
    });

    testWidgets('Sorts guests taking resolved contact name into account', (tester) async {
      final unsortedGuests = [
        {
          'uid': 'user-zoe',
          'displayName': 'Zoe Saldana',
          'tag': 'zoes',
          'avatarUrl': null,
          'phoneNumber': '+15559990000',
          'status': 'accepted',
        },
        {
          'uid': 'user-adam',
          'displayName': 'Adam Smith',
          'tag': 'adams',
          'avatarUrl': null,
          'phoneNumber': '+15551112222',
          'status': 'accepted',
        },
      ];

      // Zoe resolves to "Abigail" in contacts -> Abigail should sort before Adam
      ContactResolver.instance.seedForTest({
        '+15559990000': 'Abigail Adams',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhisperRecipientSheet(
              eventGuests: unsortedGuests,
              onSelectRecipient: (_) {},
            ),
          ),
        ),
      );

      final listTiles = find.byType(ListTile);
      final firstTiles = tester.widgetList<ListTile>(listTiles).map((tile) {
        return (tile.title as Text).data;
      }).toList();

      expect(firstTiles, equals(['Abigail', 'Adam']));
    });

    testWidgets('Applies keyboard avoidance bottom padding and dismiss-on-drag', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: Material(
              child: WhisperRecipientSheet(
                eventGuests: guests,
                onSelectRecipient: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify ListView has drag-to-dismiss configured
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.keyboardDismissBehavior, equals(ScrollViewKeyboardDismissBehavior.onDrag));

      // Verify bottom padding accounts for keyboard inset
      final paddingFinder = find.byWidgetPredicate(
        (widget) => widget is Padding && widget.padding == const EdgeInsets.only(bottom: 300),
      );
      expect(paddingFinder, findsOneWidget);
    });
  });
}
