import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/chat/message_bubble.dart';
import 'package:tftiapp/services/contact_resolver.dart';

void main() {
  group('MessageBubble Contact First Name Tests', () {
    final guests = [
      {
        'uid': 'user-adam',
        'displayName': 'Adam Smith',
        'tag': 'adams',
        'phoneNumber': '+15551112222',
      },
      {
        'uid': 'user-beth',
        'displayName': 'Beth Davis',
        'tag': 'bethd',
        'phoneNumber': '+15553334444',
      },
      {
        'uid': 'user-charlie',
        'displayName': 'Charles Brown',
        'tag': 'charlieb',
        'phoneNumber': '+15557778888',
      },
    ];

    tearDown(() {
      ContactResolver.instance.clearForTest();
    });

    Widget buildTestBubble({
      required String messageId,
      required String text,
      required String senderId,
      required String senderName,
      int? senderColor,
      bool isMe = false,
      bool isWhisper = false,
      String? whisperRecipientId,
      String? whisperRecipientName,
      List<Map<String, dynamic>> eventGuests = const [],
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            messageId: messageId,
            text: text,
            senderName: senderName,
            senderColor: senderColor ?? Colors.blue.toARGB32(),
            senderId: senderId,
            mentionedUids: const [],
            currentMsgTime:
                Timestamp.fromMillisecondsSinceEpoch(1700000000000),
            isMe: isMe,
            myUid: 'user-me',
            reactions: const <String, List<String>>{},
            readBy: const <Map<String, dynamic>>[],
            eventGuests: eventGuests,
            isWhisper: isWhisper,
            whisperRecipientId: whisperRecipientId,
            whisperRecipientName: whisperRecipientName,
            onOptionsTap: () {},
            onReadByTap: () {},
            onReactionsTap: (_) {},
          ),
        ),
      );
    }

    testWidgets(
      'Renders resolved contact first name for received group chat message header',
      (tester) async {
        ContactResolver.instance.seedForTest({
          '+15551112222': 'Alexander Hamilton',
        });

        await tester.pumpWidget(
          buildTestBubble(
            messageId: 'msg-1',
            text: 'See you all there!',
            senderId: 'user-adam',
            senderName: 'Adam Smith',
            eventGuests: guests,
          ),
        );

        // Header shows contact first name "Alexander" instead of "Adam Smith"
        expect(find.text('Alexander'), findsOneWidget);
        expect(find.text('Adam Smith'), findsNothing);
      },
    );

    testWidgets(
      'Whisper pill renders recipient contact first name when isMe is true',
      (tester) async {
        ContactResolver.instance.seedForTest({
          '+15553334444': 'Elizabeth Davis',
        });

        await tester.pumpWidget(
          buildTestBubble(
            messageId: 'msg-2',
            text: 'Can you bring napkins?',
            senderId: 'user-charlie',
            senderName: 'Charlie',
            isMe: true,
            isWhisper: true,
            whisperRecipientId: 'user-beth',
            whisperRecipientName: 'Beth Davis',
            eventGuests: guests,
          ),
        );

        expect(find.text('Whispered to Elizabeth'), findsOneWidget);
        expect(find.byIcon(Icons.hearing_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Whisper pill renders sender contact first name when isMe is false',
      (tester) async {
        ContactResolver.instance.seedForTest({
          '+15551112222': 'Alexander Hamilton',
        });

        await tester.pumpWidget(
          buildTestBubble(
            messageId: 'msg-3',
            text: 'Got your back!',
            senderId: 'user-adam',
            senderName: 'Adam Smith',
            isWhisper: true,
            whisperRecipientId: 'user-charlie',
            whisperRecipientName: 'Charles Brown',
            eventGuests: guests,
          ),
        );

        expect(find.text('Alexander Whispered'), findsOneWidget);
        expect(find.byIcon(Icons.hearing_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Falls back to space-split first name when contact is not in address book',
      (tester) async {
        await tester.pumpWidget(
          buildTestBubble(
            messageId: 'msg-4',
            text: 'Hey everyone!',
            senderId: 'user-chris',
            senderName: 'Christopher Columbus',
          ),
        );

        // Extracts "Christopher" from "Christopher Columbus"
        expect(find.text('Christopher'), findsOneWidget);
        expect(find.text('Christopher Columbus'), findsNothing);
      },
    );
  });
}
