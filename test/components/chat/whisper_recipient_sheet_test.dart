import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/chat/whisper_recipient_sheet.dart';

void main() {
  group('WhisperRecipientSheet Widget Tests', () {
    final guests = [
      {
        'uid': 'user-adam',
        'displayName': 'Adam Smith',
        'tag': 'adams',
        'avatarUrl': null,
        'avatarColor': Colors.blue.toARGB32(),
        'status': 'accepted',
      },
      {
        'uid': 'user-beth',
        'displayName': 'Beth Davis',
        'tag': 'bethd',
        'avatarUrl': null,
        'avatarColor': Colors.purple.toARGB32(),
        'status': 'accepted',
      },
      {
        'uid': 'user-charlie',
        'displayName': 'Charlie Brown',
        'tag': 'charlieb',
        'avatarUrl': null,
        'avatarColor': Colors.green.toARGB32(),
        'status': 'declined', // Should be excluded
      },
    ];

    testWidgets('Renders available guests and excludes declined guests', (tester) async {
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

      // Adam and Beth should appear
      expect(find.text('Adam Smith'), findsOneWidget);
      expect(find.text('@adams'), findsOneWidget);
      expect(find.text('Beth Davis'), findsOneWidget);
      expect(find.text('@bethd'), findsOneWidget);

      // Declined Charlie Brown should not appear
      expect(find.text('Charlie Brown'), findsNothing);

      // Tap Adam
      await tester.tap(find.text('Adam Smith'));
      await tester.pumpAndSettle();

      expect(selectedRecipient, isNotNull);
      expect(selectedRecipient!['uid'], equals('user-adam'));
    });

    testWidgets('Search query filters guests correctly', (tester) async {
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

      expect(find.text('Adam Smith'), findsOneWidget);
      expect(find.text('Beth Davis'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'beth');
      await tester.pumpAndSettle();

      expect(find.text('Adam Smith'), findsNothing);
      expect(find.text('Beth Davis'), findsOneWidget);
    });
  });
}
