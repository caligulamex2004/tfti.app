import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../services/contact_resolver.dart';
import '../../services/contact_service.dart';
import '../shared/app_avatar.dart';

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
  final String eventId;
  final VoidCallback onAddReaction;
  final List<Map<String, dynamic>>? eventGuests;
  final Future<void> Function(String newText)? onEditMessage;
  final String? currentUserId;
  final bool isSenderMuted;
  final Future<void> Function(String senderId)? onToggleMuteSender;
  final void Function(Map<String, dynamic> senderGuest)? onWhisperBack;

  const MessageOptionsSheet({
    super.key,
    required this.doc,
    required this.eventId,
    required this.onAddReaction,
    this.eventGuests,
    this.onEditMessage,
    this.currentUserId,
    this.isSenderMuted = false,
    this.onToggleMuteSender,
    this.onWhisperBack,
  });

  Future<void> _handleQuickReaction(
    BuildContext context,
    String emojiString,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    Navigator.pop(context); // Close the sheet immediately for snappy UX

    final docRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('messages')
        .doc(doc.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final freshDoc = await transaction.get(docRef);
      if (!freshDoc.exists) {
        return;
      }

      final data = freshDoc.data() as Map<String, dynamic>;
      final rawReactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      final normalized = normalizeReactions(rawReactions);

      bool userAlreadyHadThisEmoji = false;

      // Remove user from all existing reactions (enforcing 1 reaction per user per message)
      normalized.forEach((key, list) {
        if (key == emojiString && list.contains(user.uid)) {
          userAlreadyHadThisEmoji = true;
        }
        list.remove(user.uid);
      });

      normalized.removeWhere((key, list) => list.isEmpty);

      // If they tapped a new emoji (or one they didn't already have), add it
      if (!userAlreadyHadThisEmoji) {
        if (!normalized.containsKey(emojiString)) {
          normalized[emojiString] = [];
        }
        normalized[emojiString]!.add(user.uid);
      }

      transaction.update(docRef, {'reactions': normalized});
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    String? effectiveUid = currentUserId;
    if (effectiveUid == null) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        effectiveUid = null;
      }
    }
    final isMe = effectiveUid != null && data['senderId'] == effectiveUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final quickEmojis = ['❤️', '👍', '😂', '😲', '🔥'];

    // Determine user's current reaction to highlight it
    final rawReactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final normalized = normalizeReactions(rawReactions);
    String? myCurrentEmoji;

    if (effectiveUid != null) {
      normalized.forEach((key, list) {
        if (list.contains(effectiveUid)) {
          myCurrentEmoji = key;
        }
      });
    }

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

          // --- QUICK EMOJIS ROW ---
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ...quickEmojis.map((emoji) {
                  final isSelected = myCurrentEmoji == emoji;
                  return GestureDetector(
                    onTap: () => _handleQuickReaction(context, emoji),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Close options sheet
                    onAddReaction(); // Open full emoji picker
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- STANDARD OPTIONS ---
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

          if (isMe) ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("Edit Message"),
              onTap: () async {
                final currentText = (data['text'] as String?) ?? '';
                final editController = TextEditingController(text: currentText);

                final updatedText = await showDialog<String>(
                  context: context,
                  builder: (dialogCtx) {
                    final isDark =
                        Theme.of(dialogCtx).brightness == Brightness.dark;
                    final primaryColor =
                        Theme.of(dialogCtx).colorScheme.primary;

                    return AlertDialog(
                      backgroundColor: Theme.of(dialogCtx).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text("Edit Message"),
                      content: TextField(
                        controller: editController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 5,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: "Edit your message...",
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, null),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final text = editController.text.trim();
                            final hasImage = data['imageUrl'] != null &&
                                (data['imageUrl'] as String).isNotEmpty;
                            if (text.isEmpty && !hasImage) {
                              return;
                            }
                            Navigator.pop(dialogCtx, text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Save"),
                        ),
                      ],
                    );
                  },
                );

                if (context.mounted) {
                  Navigator.pop(context);
                }

                if (updatedText != null && updatedText != currentText) {
                  if (onEditMessage != null) {
                    await onEditMessage!(updatedText);
                  } else {
                    try {
                      Map<String, dynamic> updateData = {
                        'text': updatedText,
                        'isEdited': true,
                        'editedAt': FieldValue.serverTimestamp(),
                      };

                      if (eventGuests != null && eventGuests!.isNotEmpty) {
                        List<String> mentionedUids = [];
                        final words = updatedText.split(RegExp(r'\s+'));
                        for (var word in words) {
                          if (word.startsWith('@')) {
                            final queryName = word
                                .substring(1)
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^\w\s]'), '');
                            for (var guest in eventGuests!) {
                              final tag =
                                  (guest['tag'] as String?)?.toLowerCase();
                              if (tag == queryName) {
                                mentionedUids.add(guest['uid']);
                              }
                            }
                          }
                        }
                        updateData['mentionedUids'] =
                            mentionedUids.toSet().toList();
                      }

                      await doc.reference.update(updateData);
                    } catch (e) {
                      debugPrint("Failed to edit message: $e");
                    }
                  }
                }
              },
            ),
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

          if (!isMe) ...[
            Builder(
              builder: (context) {
                final senderUid = data['senderId'];
                final senderGuest = eventGuests?.firstWhere(
                  (g) => g['uid'] == senderUid,
                  orElse: () => {
                    'uid': senderUid,
                    'displayName': data['senderName'] ?? 'Unknown',
                    'tag': '',
                  },
                );
                final phone = (senderGuest?['phoneNumber'] ?? '').toString();
                final displayName = data['senderName'] ?? 'Unknown';
                final senderFirstName =
                    ContactResolver.instance.resolveFirstName(
                          phone,
                          fallbackName: displayName,
                        ) ??
                        ContactHelper.extractFirstName(displayName);

                final hasName =
                    senderFirstName.isNotEmpty && senderFirstName != 'Unknown';
                final whisperBackTitle = hasName
                    ? "Whisper Back to $senderFirstName"
                    : "Whisper Back";
                final muteTitle = isSenderMuted
                    ? (hasName
                        ? "Unmute $senderFirstName"
                        : "Unmute This Sender")
                    : (hasName ? "Mute $senderFirstName" : "Mute This Sender");

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data['isWhisper'] == true && onWhisperBack != null)
                      ListTile(
                        leading:
                            Icon(Icons.hearing_outlined, color: primaryColor),
                        title: Text(whisperBackTitle),
                        onTap: () {
                          Navigator.pop(context);
                          if (senderGuest != null) {
                            onWhisperBack!(senderGuest);
                          }
                        },
                      ),
                    ListTile(
                      leading: Icon(
                        isSenderMuted
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: isSenderMuted
                            ? primaryColor
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700),
                      ),
                      title: Text(muteTitle),
                      onTap: () async {
                        Navigator.pop(context);
                        if (senderUid != null && onToggleMuteSender != null) {
                          await onToggleMuteSender!(senderUid);
                        }
                      },
                    ),
                  ],
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text(
                "Report Message",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Report Message?"),
                    content: const Text(
                      "Flag this content as offensive or inappropriate? Our team will review it.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.redAccent
                              : Colors.red,
                        ),
                        child: const Text("Report"),
                      ),
                    ],
                  ),
                );

                if (confirm != true) {
                  return;
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }

                try {
                  final reporterUid = effectiveUid;
                  if (reporterUid == null) {
                    return;
                  }

                  await FirebaseFirestore.instance.collection('reports').add({
                    'eventId': eventId,
                    'messageId': doc.id,
                    'messageText': data['text'] ?? '',
                    'offenderId': data['senderId'],
                    'reportedBy': reporterUid,
                    'reportedAt': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "Report sent. Thank you for keeping tfti safe.",
                        ),
                        backgroundColor: isDark
                            ? Colors.green.shade700
                            : Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error sending report.")),
                    );
                  }
                }
              },
            ),
          ],
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
                    leading: AppAvatar(
                      radius: 16,
                      avatarColor: color,
                      avatarUrl: avatarUrl,
                      displayName: name,
                      fontSize: 12,
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
              leading: AppAvatar(
                radius: 16,
                avatarColor: color,
                avatarUrl: avatarUrl,
                displayName: name,
                fontSize: 12,
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
