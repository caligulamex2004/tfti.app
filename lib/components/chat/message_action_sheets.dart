import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- SHARED REACTION NORMALIZER ---
Map<String, List<String>> normalizeReactions(Map<String, dynamic> raw) {
  Map<String, List<String>> normalized = {};
  raw.forEach((key, value) {
    if (value is List) {
      normalized[key] = List<String>.from(value);
    } else if (value is String) {
      final String emoji = value;
      final String uid = key;
      if (!normalized.containsKey(emoji)) {
        normalized[emoji] = [];
      }
      if (!normalized[emoji]!.contains(uid)) {
        normalized[emoji]!.add(uid);
      }
    }
  });
  return normalized;
}

// --- MESSAGE OPTIONS SHEET ---
class MessageOptionsSheet extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback onAddReaction;

  const MessageOptionsSheet({
    super.key,
    required this.doc,
    required this.onAddReaction,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.add_reaction_outlined),
            title: const Text("Add Reaction"),
            onTap: () {
              Navigator.pop(context); // Close this sheet
              onAddReaction(); // Open the Emoji Picker
            },
          ),
          if (data['text'] != null && (data['text'] as String).isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("Copy Text"),
              onTap: () {
                Clipboard.setData(ClipboardData(text: data['text']));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Copied to clipboard")),
                );
              },
            ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                "Delete Message",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await doc.reference.delete();
              },
            ),
        ],
      ),
    );
  }
}

// --- EMOJI PICKER SHEET ---
class MessageEmojiPickerSheet extends StatelessWidget {
  final DocumentSnapshot doc;
  final String eventId;

  const MessageEmojiPickerSheet({
    super.key,
    required this.doc,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 300,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) async {
            Navigator.pop(context); // Close picker
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              return;
            }

            final docRef = FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .collection('messages')
                .doc(doc.id);

            await FirebaseFirestore.instance.runTransaction((
              transaction,
            ) async {
              final freshDoc = await transaction.get(docRef);
              if (!freshDoc.exists) {
                return;
              }

              final data = freshDoc.data() as Map<String, dynamic>;
              final rawReactions = Map<String, dynamic>.from(
                data['reactions'] ?? {},
              );
              final normalized = normalizeReactions(rawReactions);

              bool userAlreadyHadThisEmoji = false;

              normalized.forEach((key, list) {
                if (key == emoji.emoji && list.contains(user.uid)) {
                  userAlreadyHadThisEmoji = true;
                }
                list.remove(user.uid);
              });

              normalized.removeWhere((key, list) => list.isEmpty);

              if (!userAlreadyHadThisEmoji) {
                if (!normalized.containsKey(emoji.emoji)) {
                  normalized[emoji.emoji] = [];
                }
                normalized[emoji.emoji]!.add(user.uid);
              }

              transaction.update(docRef, {'reactions': normalized});
            });
          },
        ),
      ),
    );
  }
}

// --- REACTIONS DETAILS SHEET ---
class MessageReactionsSheet extends StatelessWidget {
  final DocumentSnapshot doc;
  final List<Map<String, dynamic>> eventGuests;

  const MessageReactionsSheet({
    super.key,
    required this.doc,
    required this.eventGuests,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final rawReactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final reactions = normalizeReactions(rawReactions);

    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Reactions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: reactions.entries.expand((entry) {
                final emoji = entry.key;
                final uids = entry.value;

                return uids.map((uid) {
                  final guest = eventGuests.firstWhere(
                    (g) => g['uid'] == uid,
                    orElse: () => {
                      'displayName': 'Unknown',
                      'tag': '',
                      'avatarColor': Colors.blue.toARGB32(),
                    },
                  );
                  final name = guest['displayName'];
                  final tag = guest['tag'];
                  final String? avatarUrl = guest['avatarUrl'];
                  final color = Color(
                    guest['avatarColor'] ?? Colors.blue.toARGB32(),
                  );

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: color,
                      backgroundImage: avatarUrl != null
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: tag.isNotEmpty
                        ? Text(
                            "@$tag",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: Text(emoji, style: const TextStyle(fontSize: 24)),
                  );
                }).toList();
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- READ BY SHEET ---
class MessageReadBySheet extends StatelessWidget {
  final DocumentSnapshot doc;
  final List<Map<String, dynamic>> eventGuests;

  const MessageReadBySheet({
    super.key,
    required this.doc,
    required this.eventGuests,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final msgTime = data['timestamp'] as Timestamp?;
    if (msgTime == null) {
      return const SizedBox.shrink();
    }

    List<Map<String, dynamic>> readBy = [];
    for (var guest in eventGuests) {
      if (guest['uid'] != data['senderId']) {
        final lastRead = guest['lastReadChat'] as Timestamp?;
        if (lastRead != null && lastRead.seconds >= msgTime.seconds) {
          readBy.add(guest);
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Read by",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          if (readBy.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No one has read this yet."),
            ),
          ...readBy.map((guest) {
            final String? avatarUrl = guest['avatarUrl'];
            final color = Color(guest['avatarColor'] ?? Colors.blue.toARGB32());
            final name = guest['displayName'];
            final tag = guest['tag'];

            return ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: tag != null && tag.isNotEmpty
                  ? Text(
                      "@$tag",
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    )
                  : null,
            );
          }),
        ],
      ),
    );
  }
}
