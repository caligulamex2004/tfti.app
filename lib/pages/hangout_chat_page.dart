import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

// --- UTILS & COMPONENTS ---
import '../utils/theme_provider.dart';
import '../components/chat/pinned_context_card.dart';
import '../components/chat/chat_quick_actions.dart';
import '../components/chat/message_bubble.dart';
import '../components/chat/chat_input_field.dart';
import '../components/chat/mentions_overlay.dart';
import '../components/chat/chat_action_dialogs.dart';

class HangoutChatPage extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const HangoutChatPage({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<HangoutChatPage> createState() => _HangoutChatPageState();
}

class _HangoutChatPageState extends State<HangoutChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _mentionQuery;
  List<Map<String, dynamic>> _eventGuests = [];
  bool _isUploadingImage = false;
  bool _isMuted = false;

  StreamSubscription<QuerySnapshot>? _invitationsSub;
  StreamSubscription<DocumentSnapshot>? _eventSub;
  Map<String, dynamic>? _eventData;

  @override
  void initState() {
    super.initState();
    _listenToEventData();
    _listenToInvitations();
    _messageController.addListener(_onTextChanged);
    _markChatAsRead();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _invitationsSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  // --- DATA NORMALIZER (SELF-HEALS OLD FIRESTORE BUGS) ---
  Map<String, List<String>> _normalizeReactions(Map<String, dynamic> raw) {
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

  // --- REAL-TIME LISTENERS ---

  void _listenToEventData() {
    _eventSub = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            setState(() {
              _eventData = doc.data() as Map<String, dynamic>;
            });
          }
        });
  }

  void _listenToInvitations() {
    _invitationsSub = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .snapshots()
        .listen((snapshot) async {
          List<Map<String, dynamic>> guests = [];
          final currentUser = FirebaseAuth.instance.currentUser;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (currentUser != null && doc.id == currentUser.uid) {
              if (mounted) {
                setState(() {
                  _isMuted = data['isMuted'] ?? false;
                });
              }
            }
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(doc.id)
                  .get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                final String displayName = userData['displayName'] ?? 'Unknown';

                final String realUsername =
                    userData['username'] ??
                    displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '');

                guests.add({
                  'uid': doc.id,
                  'displayName': displayName,
                  'tag': realUsername,
                  'avatarUrl': userData['avatarUrl'],
                  'avatarColor':
                      userData['avatarColor'] ?? Colors.blue.toARGB32(),
                  'status': data['status'],
                  'lastReadChat': data['lastReadChat'],
                });
              }
            } catch (e) {
              debugPrint("Error fetching user data for chat guest: $e");
            }
          }

          if (mounted) {
            setState(() {
              _eventGuests = guests;
            });
          }
        });
  }

  // --- MUTE & READ RECEIPTS ---

  Future<void> _toggleMute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isMuted = !_isMuted);

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .doc(user.uid)
        .update({'isMuted': _isMuted});
  }

  Future<void> _markChatAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .doc(user.uid)
        .update({'lastReadChat': FieldValue.serverTimestamp()});
  }

  // --- MENTIONS LOGIC ---

  void _onTextChanged() {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.base.offset;

    if (cursorPosition >= 0 && cursorPosition <= text.length) {
      final textBeforeCursor = text.substring(0, cursorPosition);
      final words = textBeforeCursor.split(RegExp(r'\s+'));
      final lastWord = words.isNotEmpty ? words.last : '';

      if (lastWord.startsWith('@')) {
        setState(() {
          _mentionQuery = lastWord.substring(1).toLowerCase();
        });
        return;
      }
    }

    if (_mentionQuery != null) {
      setState(() => _mentionQuery = null);
    }
  }

  void _insertMention(String usernameTag) {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.base.offset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final textAfterCursor = text.substring(cursorPosition);

    final words = textBeforeCursor.split(RegExp(r'\s+'));
    words.removeLast();

    final newTextBeforeCursor = words.isEmpty
        ? '@$usernameTag '
        : '${words.join(' ')} @$usernameTag ';

    _messageController.text = newTextBeforeCursor + textAfterCursor;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: newTextBeforeCursor.length),
    );

    setState(() => _mentionQuery = null);
    _focusNode.requestFocus();
  }

  // --- QUICK ACTIONS LOGIC ---

  void _triggerMentionAction() {
    final text = _messageController.text;
    if (!text.endsWith('@')) {
      _messageController.text = text.isEmpty ? '@' : '$text @';
    }
    _focusNode.requestFocus();
  }

  void _sendOmw() {
    _messageController.text = "On my way! 🏃‍♂️💨";
    _sendMessage();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      final File file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 800,
        minHeight: 800,
        quality: 80,
      );

      final String fileName =
          'chat_images/${widget.eventId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final String downloadUrl = await ref.getDownloadURL();

      await _sendMessage(imageUrl: downloadUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showDibsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SquadDibsSheet(
        eventId: widget.eventId,
        onClaimed: (title) {
          _messageController.text = "I call dibs on $title! 🙋";
          _sendMessage();
        },
      ),
    );
  }

  void _showBringItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BringItemDialog(
        eventId: widget.eventId,
        onAnnounce: (title) {
          _messageController.text = "I'm bringing $title! 🛒";
          _sendMessage();
        },
      ),
    );
  }

  // --- CHAT LOGIC ---

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    _messageController.clear();
    setState(() => _mentionQuery = null);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>;

      List<String> mentionedUids = [];
      final words = text.split(RegExp(r'\s+'));
      for (var word in words) {
        if (word.startsWith('@')) {
          final queryName = word
              .substring(1)
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '');
          for (var guest in _eventGuests) {
            final tag = (guest['tag'] as String).toLowerCase();
            if (tag == queryName) {
              mentionedUids.add(guest['uid']);
            }
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'senderName': userData['displayName'] ?? 'Unknown',
            'senderAvatarUrl': userData['avatarUrl'],
            'senderColor': userData['avatarColor'] ?? Colors.blue.toARGB32(),
            'text': text,
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'mentionedUids': mentionedUids.toSet().toList(), // Unique IDs
          });

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
            'lastMessageAt': FieldValue.serverTimestamp(),
            'lastMessageSnippet': imageUrl != null
                ? '📷 Image'
                : text.substring(0, text.length > 30 ? 30 : text.length),
          });

      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      _markChatAsRead();
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  // --- MESSAGE OPTIONS & REACTIONS ---

  void _showMessageOptions(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                Navigator.pop(ctx);
                _showEmojiPicker(doc);
              },
            ),
            if (data['text'] != null && (data['text'] as String).isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("Copy Text"),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: data['text']));
                  Navigator.pop(ctx);
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
                  Navigator.pop(ctx);
                  await doc.reference.delete();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) async {
                Navigator.pop(ctx);
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  return;
                }

                final docRef = FirebaseFirestore.instance
                    .collection('events')
                    .doc(widget.eventId)
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
                  final normalized = _normalizeReactions(rawReactions);

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
      },
    );
  }

  void _showReactionsDetailsSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawReactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final reactions = _normalizeReactions(rawReactions);

    if (reactions.isEmpty) {
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                    final guest = _eventGuests.firstWhere(
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
                      trailing: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    );
                  }).toList();
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReadBySheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final msgTime = data['timestamp'] as Timestamp?;
    if (msgTime == null) {
      return;
    }

    List<Map<String, dynamic>> readBy = [];
    for (var guest in _eventGuests) {
      if (guest['uid'] != data['senderId']) {
        final lastRead = guest['lastReadChat'] as Timestamp?;
        if (lastRead != null && lastRead.seconds >= msgTime.seconds) {
          readBy.add(guest);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                final color = Color(
                  guest['avatarColor'] ?? Colors.blue.toARGB32(),
                );
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.eventTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMuted ? Icons.notifications_off : Icons.notifications,
            ),
            onPressed: _toggleMute,
            tooltip: _isMuted ? "Unmute Chat" : "Mute Chat",
          ),
        ],
      ),
      body: Column(
        children: [
          if (_eventData != null) PinnedContextCard(eventData: _eventData!),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(widget.eventId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                // --- PRE-CALCULATE FACE PILES ---
                Map<String, List<Map<String, dynamic>>> latestReadReceipts = {};

                for (var guest in _eventGuests) {
                  final lastRead = guest['lastReadChat'] as Timestamp?;
                  if (lastRead != null) {
                    for (var doc in messages) {
                      final data = doc.data() as Map<String, dynamic>;
                      final msgTime = data['timestamp'] as Timestamp?;

                      if (msgTime != null &&
                          lastRead.seconds >= msgTime.seconds) {
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
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe =
                        data['senderId'] ==
                        FirebaseAuth.instance.currentUser?.uid;

                    // NORMALIZER
                    final rawReactions = Map<String, dynamic>.from(
                      data['reactions'] ?? {},
                    );
                    final normalizedReactions = _normalizeReactions(
                      rawReactions,
                    );

                    final readBy = latestReadReceipts[doc.id] ?? [];

                    return MessageBubble(
                      messageId: doc.id,
                      text: data['text'] ?? '',
                      imageUrl: data['imageUrl'],
                      senderName: data['senderName'] ?? 'Unknown',
                      senderColor:
                          data['senderColor'] ?? Colors.blue.toARGB32(),
                      senderId: data['senderId'],
                      senderAvatarUrl: data['senderAvatarUrl'],
                      mentionedUids: List<String>.from(
                        data['mentionedUids'] ?? [],
                      ),
                      currentMsgTime: data['timestamp'] ?? Timestamp.now(),
                      isMe: isMe,
                      myUid: FirebaseAuth.instance.currentUser?.uid,
                      reactions: normalizedReactions,
                      readBy: readBy,
                      eventGuests: _eventGuests,
                      onOptionsTap: () => _showMessageOptions(doc),
                      onReadByTap: () => _showReadBySheet(doc),
                      onReactionsTap: (reactions) =>
                          _showReactionsDetailsSheet(doc),
                    );
                  },
                );
              },
            ),
          ),

          MentionsOverlay(
            mentionQuery: _mentionQuery,
            eventGuests: _eventGuests,
            onMentionSelected: _insertMention,
          ),

          ChatQuickActions(
            onMention: _triggerMentionAction,
            onPhoto: _pickImage,
            onOmw: _sendOmw,
            onDibs: _showDibsSheet,
            onBringItem: _showBringItemDialog,
          ),

          ChatInputField(
            controller: _messageController,
            focusNode: _focusNode,
            isUploadingImage: _isUploadingImage,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
