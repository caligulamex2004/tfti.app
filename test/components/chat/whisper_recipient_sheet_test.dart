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
  });
}
