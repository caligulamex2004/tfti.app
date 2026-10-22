import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'message_bubble.dart';
import 'message_action_sheets.dart';

class ChatFeed extends StatelessWidget {
  final String eventId;
  final List<Map<String, dynamic>> eventGuests;
  final ScrollController scrollController;
  final List<String> mutedSenderUids;
  final Future<void> Function(String senderId)? onToggleMuteSender;
  final void Function(Map<String, dynamic> senderGuest)? onWhisperBack;

  const ChatFeed({
    super.key,
    required this.eventId,
    required this.eventGuests,
    required this.scrollController,
    this.mutedSenderUids = const [],
    this.onToggleMuteSender,
    this.onWhisperBack,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawMessages = snapshot.data!.docs;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        // Filter out whispers that aren't intended for the current user
        final messages = rawMessages.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isWhisper = data['isWhisper'] == true;
          if (!isWhisper) return true;
          final visibleTo = data['visibleTo'] as List?;
          if (visibleTo != null) {
            return visibleTo.contains(currentUid);
          }
          return data['senderId'] == currentUid ||
              data['whisperRecipientId'] == currentUid;
        }).toList();

        // --- PRE-CALCULATE FACE PILES ---
        Map<String, List<Map<String, dynamic>>> latestReadReceipts = {};

        for (var guest in eventGuests) {
          final lastRead = guest['lastReadChat'] as Timestamp?;
          if (lastRead != null) {
            for (var doc in messages) {
              final data = doc.data() as Map<String, dynamic>;
              final msgTime = data['timestamp'] as Timestamp?;

              if (msgTime != null && lastRead.seconds >= msgTime.seconds) {
                if (guest['uid'] != data['senderId']) {
                  latestReadReceipts[doc.id] ??= [];
                  latestReadReceipts[doc.id]!.add(guest);
                }
                break;
              }
            }
          }
        }

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final doc = messages[index];
            final data = doc.data() as Map<String, dynamic>;
            final isMe =
                data['senderId'] == FirebaseAuth.instance.currentUser?.uid;

            // NORMALIZER HELPER IMPORTED FROM message_action_sheets.dart
            final rawReactions = Map<String, dynamic>.from(
              data['reactions'] ?? {},
            );
            final normalizedReactions = normalizeReactions(rawReactions);

            final readBy = latestReadReceipts[doc.id] ?? [];

            return MessageBubble(
              messageId: doc.id,
              text: data['text'] ?? '',
              imageUrl: data['imageUrl'],
              senderName: data['senderName'] ?? 'Unknown',
              senderColor: data['senderColor'] ?? Colors.blue.toARGB32(),
              senderId: data['senderId'],
              senderAvatarUrl: data['senderAvatarUrl'],
              mentionedUids: List<String>.from(data['mentionedUids'] ?? []),
              currentMsgTime: data['timestamp'] ?? Timestamp.now(),
              isMe: isMe,
              myUid: FirebaseAuth.instance.currentUser?.uid,
              reactions: normalizedReactions,
              readBy: readBy,
              eventGuests: eventGuests,
              isWhisper: data['isWhisper'] == true,
              whisperRecipientName: data['whisperRecipientName'],
              whisperRecipientId: data['whisperRecipientId'],

              // DELEGATING ALL ACTIONS TO OUR BOTTOM SHEETS
              onOptionsTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (ctx) => MessageOptionsSheet(
                    doc: doc,
                    eventId: eventId,
                    eventGuests: eventGuests,
                    currentUserId: currentUid,
                    isSenderMuted: mutedSenderUids.contains(data['senderId']),
                    onToggleMuteSender: onToggleMuteSender,
                    onWhisperBack: onWhisperBack,
                    onAddReaction: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Theme.of(
                          context,
                        ).scaffoldBackgroundColor,
                        builder: (ctx2) =>
                            MessageEmojiPickerSheet(doc: doc, eventId: eventId),
                      );
                    },
                  ),
                );
              },
              onReadByTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (ctx) =>
                      MessageReadBySheet(doc: doc, eventGuests: eventGuests),
                );
              },
              onReactionsTap: (reactions) {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (ctx) =>
                      MessageReactionsSheet(doc: doc, eventGuests: eventGuests),
                );
              },
            );
          },
        );
      },
    );
  }
}
