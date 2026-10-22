// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/chat/message_action_sheets.dart';

class FakeDocumentReference implements DocumentReference {
  bool deleted = false;
  Map<String, dynamic>? updatedData;

  @override
  Future<void> delete() async {
    deleted = true;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    updatedData = Map<String, dynamic>.from(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentSnapshot implements DocumentSnapshot {
  @override
  final String id;
  final Map<String, dynamic> _data;
  final FakeDocumentReference _reference;

  FakeDocumentSnapshot(
    this._data, {
    this.id = 'msg-123',
    FakeDocumentReference? reference,
  }) : _reference = reference ?? FakeDocumentReference();

  @override
  Map<String, dynamic> data() => _data;

  @override
  bool get exists => true;

  @override
  dynamic get(Object field) => _data[field];

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  FakeDocumentReference get reference => _reference;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const currentUserId = 'my-user-id';
  const otherUserId = 'other-user-id';

  Widget buildTestWidget({
    required DocumentSnapshot doc,
    required String currentUid,
    VoidCallback? onAddReaction,
    Future<void> Function(String)? onEditMessage,
    bool isSenderMuted = false,
    Future<void> Function(String)? onToggleMuteSender,
    void Function(Map<String, dynamic>)? onWhisperBack,
    List<Map<String, dynamic>>? eventGuests,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MessageOptionsSheet(
          doc: doc,
          eventId: 'event-123',
          currentUserId: currentUid,
          onAddReaction: onAddReaction ?? () {},
          onEditMessage: onEditMessage,
          isSenderMuted: isSenderMuted,
          onToggleMuteSender: onToggleMuteSender,
          onWhisperBack: onWhisperBack,
          eventGuests: eventGuests,
        ),
      ),
    );
  }

  group('MessageOptionsSheet Regression Tests', () {
    testWidgets(
      'User own message renders 4 actions: React, Copy Text, Edit Message, Delete Message',
      (tester) async {
        final doc = FakeDocumentSnapshot({
          'senderId': currentUserId,
          'text': 'Hey squad, meeting at 7!',
          'reactions': {},
        });

        await tester.pumpWidget(
          buildTestWidget(doc: doc, currentUid: currentUserId),
        );

        // 1. React with emoji (Quick reaction row)
        expect(find.text('❤️'), findsOneWidget);
        expect(find.text('👍'), findsOneWidget);
        expect(find.text('🔥'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);

        // 2. Copy Text
        expect(find.text('Copy Text'), findsOneWidget);
        expect(find.byIcon(Icons.copy), findsOneWidget);

        // 3. Edit Message
        expect(find.text('Edit Message'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        // 4. Delete Message
        expect(find.text('Delete Message'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // Report Message must NOT be shown on user's own message
        expect(find.text('Report Message'), findsNothing);
      },
    );

    testWidgets(
      'Other user message renders: React, Copy Text, Mute This Sender, Report Message',
      (tester) async {
        final doc = FakeDocumentSnapshot({
          'senderId': otherUserId,
          'text': 'See you guys there!',
          'reactions': {},
        });

        await tester.pumpWidget(
          buildTestWidget(doc: doc, currentUid: currentUserId),
        );

        // 1. React with emoji
        expect(find.text('❤️'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);

        // 2. Copy Text
        expect(find.text('Copy Text'), findsOneWidget);
        expect(find.byIcon(Icons.copy), findsOneWidget);

        // 3. Mute This Sender
        expect(find.text('Mute This Sender'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

        // 4. Report Message
        expect(find.text('Report Message'), findsOneWidget);
        expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

        // Edit and Delete must NOT be shown on other user's message
        expect(find.text('Edit Message'), findsNothing);
        expect(find.text('Delete Message'), findsNothing);
      },
    );

    testWidgets(
      'Other user message renders "Unmute This Sender" when isSenderMuted is true and triggers callback',
      (tester) async {
        String? toggledSender;
        final doc = FakeDocumentSnapshot({
          'senderId': otherUserId,
          'text': 'Too many messages!',
          'reactions': {},
        });

        await tester.pumpWidget(
          buildTestWidget(
            doc: doc,
            currentUid: currentUserId,
            isSenderMuted: true,
            onToggleMuteSender: (senderId) async {
              toggledSender = senderId;
            },
          ),
        );

        expect(find.text('Unmute This Sender'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);

        await tester.tap(find.text('Unmute This Sender'));
        await tester.pumpAndSettle();

        expect(toggledSender, equals(otherUserId));
      },
    );

    testWidgets(
      'Whispered message from other user renders "Whisper Back" and triggers callback',
      (tester) async {
        Map<String, dynamic>? whisperBackRecipient;
        final doc = FakeDocumentSnapshot({
          'senderId': otherUserId,
          'senderName': 'Adam',
          'text': 'This is top secret',
          'isWhisper': true,
          'reactions': {},
        });

        await tester.pumpWidget(
          buildTestWidget(
            doc: doc,
            currentUid: currentUserId,
            eventGuests: [
              {'uid': otherUserId, 'displayName': 'Adam', 'tag': 'adamb'},
            ],
            onWhisperBack: (recipient) {
              whisperBackRecipient = recipient;
            },
          ),
        );

        expect(find.text('Whisper Back to Adam'), findsOneWidget);
        expect(find.byIcon(Icons.hearing_outlined), findsOneWidget);

        await tester.tap(find.text('Whisper Back to Adam'));
        await tester.pumpAndSettle();

        expect(whisperBackRecipient, isNotNull);
        expect(whisperBackRecipient!['uid'], equals(otherUserId));
      },
    );

    testWidgets(
      'Tapping Edit Message opens dialog pre-populated with current text and saves update',
      (tester) async {
        String? editedResult;
        final doc = FakeDocumentSnapshot({
          'senderId': currentUserId,
          'text': 'Initial message text',
          'reactions': {},
        });

        await tester.pumpWidget(
          buildTestWidget(
            doc: doc,
            currentUid: currentUserId,
            onEditMessage: (newText) async {
              editedResult = newText;
            },
          ),
        );

        // Tap Edit Message
        await tester.tap(find.text('Edit Message'));
        await tester.pumpAndSettle();

        // Dialog should be visible
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Edit Message'), findsNWidgets(2)); // Title and original tile
        expect(find.text('Initial message text'), findsOneWidget);

        // Edit the text in the dialog
        await tester.enterText(find.byType(TextField), 'Updated message text');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Callback was invoked with updated text
        expect(editedResult, equals('Updated message text'));
      },
    );

    testWidgets(
      'Tapping Cancel in Edit Message dialog dismisses without saving',
      (tester) async {
        bool editedCalled = false;
        final doc = FakeDocumentSnapshot({
          'senderId': currentUserId,
          'text': 'Never edited text',
          'reactions': {},
        });

        await tester.pumpWidget(
          buildTestWidget(
            doc: doc,
            currentUid: currentUserId,
            onEditMessage: (newText) async {
              editedCalled = true;
            },
          ),
        );

        // Tap Edit Message
        await tester.tap(find.text('Edit Message'));
        await tester.pumpAndSettle();

        // Change text but tap Cancel
        await tester.enterText(find.byType(TextField), 'Discard this change');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog closed and callback was never called
        expect(find.byType(AlertDialog), findsNothing);
        expect(editedCalled, isFalse);
      },
    );
  });
}
