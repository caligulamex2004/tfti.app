import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/chat/chat_input_field.dart';

void main() {
  group('ChatInputField Whisper Mode Tests', () {
    testWidgets('Normal mode renders default hint and send icon', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputField(
              controller: controller,
              focusNode: focusNode,
              isUploadingImage: false,
              onSend: () {},
            ),
          ),
        ),
      );

      expect(find.text('Type a message...'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.textContaining('Whispering to'), findsNothing);
    });

    testWidgets(
        'Whisper mode renders recipient chip, hearing icon, and cancel callback',
        (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool cancelTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputField(
              controller: controller,
              focusNode: focusNode,
              isUploadingImage: false,
              onSend: () {},
              whisperRecipient: {
                'uid': 'user-adam',
                'displayName': 'Adam',
              },
              onCancelWhisper: () {
                cancelTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Whispering to Adam'), findsOneWidget);
      expect(find.text('Whisper to Adam...'), findsOneWidget);
      expect(find.byIcon(Icons.hearing_outlined), findsNWidgets(2)); // Chip + Send button

      // Tap close icon on the chip
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(cancelTapped, isTrue);
    });
  });
}
