import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import 'theme_provider.dart';

class EventChatPage extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventChatPage({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventChatPage> createState() => _EventChatPageState();
}

class _EventChatPageState extends State<EventChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _focusNode =
      FocusNode(); // NEW: To control keyboard focus from Quick Actions

  String? _mentionQuery;
  List<Map<String, dynamic>> _eventGuests = [];
  bool _isUploadingImage = false;

  StreamSubscription<QuerySnapshot>? _invitationsSub;
  StreamSubscription<QuerySnapshot>? _messagesSub;
  Map<String, Timestamp> _readReceipts = {};

  @override
  void initState() {
    super.initState();
    _markAsRead();
    _loadGuests();
    _listenToReadReceipts();
    _listenToIncomingMessages();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _markAsRead();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _invitationsSub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }

  void _listenToReadReceipts() {
    _invitationsSub = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          Map<String, Timestamp> receipts = {};
          for (var doc in snap.docs) {
            final data = doc.data();
            if (data['lastReadChat'] != null) {
              receipts[doc.id] = data['lastReadChat'] as Timestamp;
            }
          }
          setState(() => _readReceipts = receipts);
        });
  }

  void _listenToIncomingMessages() {
    _messagesSub = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          if (snap.docs.isNotEmpty) {
            final data = snap.docs.first.data();
            final senderId = data['senderId'];
            final user = FirebaseAuth.instance.currentUser;

            if (user != null && senderId != user.uid) {
              _markAsRead();
            }
          }
        });
  }

  Future<void> _loadGuests() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('invitations')
          .get();

      List<Map<String, dynamic>> guests = [];
      for (var doc in snap.docs) {
        final uid = doc.id;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final name = userDoc.data()?['displayName'] ?? 'User';

          // Prioritize actual username, fallback to stripped display name safely
          final String rawUsername = userDoc.data()?['username'] ?? name;
          final tag = rawUsername
              .replaceAll(' ', '')
              .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
              .toLowerCase(); // Lowercase ensures search matching works flawlessly

          guests.add({
            'uid': uid,
            'name': name,
            'tag': tag,
            'color': userDoc.data()?['avatarColor'] ?? Colors.blue.toARGB32(),
            'avatarUrl': userDoc.data()?['avatarUrl'],
          });
        }
      }
      if (mounted) setState(() => _eventGuests = guests);
    } catch (e) {
      debugPrint("Error loading guests: $e");
    }
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final selection = _messageController.selection;

    if (selection.baseOffset == -1) return;

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtSignIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtSignIndex != -1) {
      final textAfterAt = textBeforeCursor.substring(lastAtSignIndex + 1);
      if (!textAfterAt.contains(' ')) {
        setState(() => _mentionQuery = textAfterAt.toLowerCase());
        return;
      }
    }

    if (_mentionQuery != null) {
      setState(() => _mentionQuery = null);
    }
  }

  void _insertMention(String mentionTag) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtSignIndex = textBeforeCursor.lastIndexOf('@');

    final textBeforeMention = text.substring(0, lastAtSignIndex);
    final textAfterCursor = text.substring(selection.baseOffset);

    final newText = '$textBeforeMention@$mentionTag $textAfterCursor';

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: lastAtSignIndex + mentionTag.length + 2,
      ),
    );

    setState(() => _mentionQuery = null);
    _focusNode.requestFocus();
  }

  Future<void> _markAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('invitations')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'lastReadChat': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error marking read: $e");
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final dt = timestamp.toDate();
    final int hour = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final String period = dt.hour >= 12 ? "PM" : "AM";
    final String minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }

  String? _extractUrl(String text) {
    final RegExp urlRegex = RegExp(
      r'((https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,4}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*))',
      caseSensitive: false,
    );

    final match = urlRegex.firstMatch(text);
    if (match != null) {
      String url = match.group(0)!;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }
    return null;
  }

  Future<void> _toggleReaction(
    String messageId,
    String emoji,
    Map<String, dynamic> currentReactions,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final myCurrentReaction = currentReactions[user.uid];
    Map<String, dynamic> updatedReactions = Map.from(currentReactions);

    if (myCurrentReaction == emoji) {
      updatedReactions.remove(user.uid);
    } else {
      updatedReactions[user.uid] = emoji;
    }

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions': updatedReactions});

    _markAsRead();
  }

  void _showMessageOptions(
    String messageId,
    String text,
    String? imageUrl,
    String senderId,
    bool isMe,
    Map<String, dynamic> currentReactions,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final quickEmojis = ['❤️', '👍', '😂', '😲', '🔥'];
    bool showFullPicker = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    if (!showFullPicker) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 16.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ...quickEmojis.map((emoji) {
                              final isSelected =
                                  currentReactions[FirebaseAuth
                                      .instance
                                      .currentUser
                                      ?.uid] ==
                                  emoji;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _toggleReaction(
                                    messageId,
                                    emoji,
                                    currentReactions,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              );
                            }),
                            GestureDetector(
                              onTap: () {
                                setSheetState(() => showFullPicker = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: isDark ? Colors.white : Colors.black87,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (!isMe)
                        ListTile(
                          leading: const Icon(Icons.flag, color: Colors.red),
                          title: const Text(
                            'Report Message',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _reportMessage(messageId, text, senderId);
                          },
                        )
                      else
                        ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                          title: Text(
                            'Delete Message',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (imageUrl != null && imageUrl.isNotEmpty) {
                              try {
                                await FirebaseStorage.instance
                                    .refFromURL(imageUrl)
                                    .delete();
                              } catch (e) {
                                debugPrint(
                                  "❌ Failed to delete image from Storage: $e",
                                );
                              }
                            }
                            await FirebaseFirestore.instance
                                .collection('events')
                                .doc(widget.eventId)
                                .collection('messages')
                                .doc(messageId)
                                .delete();
                          },
                        ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Pick a Reaction",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setSheetState(() => showFullPicker = false),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 300,
                        child: EmojiPicker(
                          onEmojiSelected: (category, emoji) {
                            Navigator.pop(ctx);
                            _toggleReaction(
                              messageId,
                              emoji.emoji,
                              currentReactions,
                            );
                          },
                          config: Config(
                            height: 300,
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              backgroundColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              columns: 7,
                              emojiSizeMax: 28 * (Platform.isIOS ? 1.30 : 1.0),
                            ),
                            categoryViewConfig: CategoryViewConfig(
                              backgroundColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              indicatorColor: primaryColor,
                              iconColorSelected: primaryColor,
                              iconColor: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                            ),
                            bottomActionBarConfig: BottomActionBarConfig(
                              backgroundColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              buttonColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              buttonIconColor: isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            searchViewConfig: SearchViewConfig(
                              backgroundColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              buttonIconColor: isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReactionDetails(Map<String, dynamic> reactions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
              const Text(
                "Reactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final String uid = reactions.keys.elementAt(index);
                    final String emoji = reactions.values.elementAt(index);

                    Map<String, dynamic>? guest;
                    try {
                      guest = _eventGuests.firstWhere((g) => g['uid'] == uid);
                    } catch (_) {}

                    final String name = guest != null
                        ? guest['name']
                        : 'Someone';
                    final int color = guest != null
                        ? guest['color']
                        : Colors.blue.toARGB32();

                    final String? avatarUrl = guest?['avatarUrl'];

                    return ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(color),
                            backgroundImage: avatarUrl != null
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      trailing: uid == myUid
                          ? Text(
                              "You",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reportMessage(
    String messageId,
    String text,
    String senderId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              foregroundColor: isDark ? Colors.redAccent : Colors.red,
            ),
            child: const Text("Report"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'eventId': widget.eventId,
        'messageId': messageId,
        'messageText': text,
        'offenderId': senderId,
        'reportedBy': user.uid,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Report sent. Thank you for keeping TFTI safe.",
            ),
            backgroundColor: isDark ? Colors.green.shade700 : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error sending report.")));
      }
    }
  }

  void _showAttachmentOptions() {
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
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take a Photo"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final File file = File(pickedFile.path);
      final Uint8List bytes = await file.readAsBytes();

      final Uint8List compressedBytes =
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 1024,
            minHeight: 1024,
            quality: 75,
          );

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(
        'chat_images/${widget.eventId}/$fileName',
      );

      final UploadTask uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _sendMessage(imageUrl: downloadUrl);
    } catch (e) {
      debugPrint("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to send image.")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _messageController.clear();
    setState(() => _mentionQuery = null);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final int avatarColor =
        userDoc.data()?['avatarColor'] ?? Colors.blue.toARGB32();
    final String displayName = userDoc.data()?['displayName'] ?? "User";

    final String? avatarUrl = userDoc.data()?['avatarUrl'];
    final now = FieldValue.serverTimestamp();

    List<String> mentionedUids = [];
    if (text.isNotEmpty) {
      final RegExp mentionRegex = RegExp(r"\B@[a-zA-Z0-9_]+");
      final matches = mentionRegex.allMatches(text);

      for (var match in matches) {
        final tag = match.group(0)!.substring(1).toLowerCase();
        try {
          final guest = _eventGuests.firstWhere(
            (g) => (g['tag'] as String).toLowerCase() == tag,
          );
          if (!mentionedUids.contains(guest['uid'])) {
            mentionedUids.add(guest['uid']);
          }
        } catch (e) {
          // Ignore fake tags
        }
      }
    }

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('messages')
        .add({
          'text': text,
          'imageUrl': imageUrl,
          'senderId': user.uid,
          'senderName': displayName,
          'senderColor': avatarColor,
          'senderAvatarUrl': avatarUrl,
          'timestamp': now,
          'mentionedUids': mentionedUids,
          'reactions': {},
        });

    final String snippet = imageUrl != null ? "📷 Image" : text;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .update({
          'lastMessageAt': now,
          'lastMessageSnippet': snippet,
          'lastMessageMentions': mentionedUids,
        });

    _markAsRead();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showDibsOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
              const Text(
                "Unclaimed Squad Needs",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              // Safe constraints for the bottom sheet list
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .doc(widget.eventId)
                      .collection('roles')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          "No Squad Needs were added for this event.",
                        ),
                      );
                    }

                    // Filter out items that are already claimed
                    final unclaimedDocs = docs
                        .where(
                          (d) =>
                              (d.data()
                                  as Map<String, dynamic>)['claimedByUid'] ==
                              null,
                        )
                        .toList();

                    if (unclaimedDocs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          "Everything has been claimed! 🎉",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: unclaimedDocs.length,
                      itemBuilder: (context, index) {
                        final doc = unclaimedDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Something';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(
                              Icons.pan_tool,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Tap to claim this item",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _claimRoleAndAnnounce(doc.id, title, user);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _claimRoleAndAnnounce(
    String roleId,
    String roleTitle,
    User user,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final displayName = userDoc.data()?['displayName'] ?? "Someone";

      // 1. Lock the role in the database
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('roles')
          .doc(roleId)
          .update({'claimedByUid': user.uid, 'claimedByName': displayName});

      // 2. Draft the announcement message and fire it off
      _messageController.text = "I got dibs on $roleTitle! ✋";
      await _sendMessage();
    } catch (e) {
      debugPrint("Error claiming role: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Failed to claim that item. Someone might have beat you to it!",
            ),
          ),
        );
      }
    }
  }

  // --- NEW: THE PINNED CONTEXT CARD ---
  Widget _buildPinnedContextCard(
    Map<String, dynamic> data,
    bool isDark,
    Color primaryColor,
  ) {
    final Timestamp ts = data['time'];
    final DateTime dt = ts.toDate();
    final int keepAliveDays = data['keepAliveDays'] ?? 0;

    final List<String> shortMonths = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final String shortMonth = shortMonths[dt.month - 1];
    final String day = dt.day.toString();

    int hour = dt.hour;
    final String period = hour >= 12 ? "PM" : "AM";
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String timeString = "$hour:$minute $period";

    String keepAliveLabel = "";
    if (keepAliveDays == 1) {
      keepAliveLabel = "1 Day";
    } else if (keepAliveDays == 7) {
      keepAliveLabel = "1 Week";
    } else if (keepAliveDays > 0) {
      keepAliveLabel = "$keepAliveDays Days";
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Date Block
          Container(
            width: 45,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    shortMonth,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Details Stack
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                      ),
                    ),
                    if (keepAliveDays > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          keepAliveLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data['location'] ?? 'TBD',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: THE TACTILE QUICK ACTION CHIPS ---
  Widget _buildQuickActions(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ActionChip(
            avatar: Icon(Icons.alternate_email, size: 16, color: primaryColor),
            label: Text(
              "Mention",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: () {
              _messageController.text += "@";
              _focusNode.requestFocus();
              _onTextChanged();
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.camera_alt,
              size: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            label: Text(
              "Photo",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: _showAttachmentOptions,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.directions_car,
              size: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            label: Text(
              "On my way",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: () {
              _messageController.text = "On my way! 🚗";
              _focusNode.requestFocus();
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.pan_tool,
              size: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            label: Text(
              "I got dibs on...",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed:
                _showDibsOptions, // 👇 FIX: Now launches the database selection sheet!
          ),
        ],
      ),
    );
  }

  Widget _buildMessageText(
    String text,
    List<dynamic> mentionedUids,
    String? myUid,
    bool isMe,
    bool isDark,
    Color primaryColor,
  ) {
    final defaultColor = isMe
        ? themeProvider.onPrimaryColor
        : (isDark ? Colors.white : Colors.black87);

    final RegExp mentionRegex = RegExp(r"\B@[a-zA-Z0-9_]+");
    final Iterable<RegExpMatch> matches = mentionRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: TextStyle(fontSize: 16, color: defaultColor));
    }

    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final String fullTag = match.group(0)!;
      final String tagWithoutAt = fullTag.substring(1).toLowerCase();

      bool isRealMention = false;
      bool isMentioningMe = false;

      String displayText = fullTag;

      try {
        final guest = _eventGuests.firstWhere(
          (g) => (g['tag'] as String).toLowerCase() == tagWithoutAt,
        );
        if (mentionedUids.contains(guest['uid'])) {
          isRealMention = true;

          displayText = "@${guest['name']}";

          if (guest['uid'] == myUid) {
            isMentioningMe = true;
          }
        }
      } catch (_) {}

      if (isRealMention) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                color: isMentioningMe
                    ? Colors.amber.withValues(alpha: isMe ? 0.9 : 0.4)
                    : (isDark ? Colors.white24 : Colors.black12),
                borderRadius: BorderRadius.circular(8),
                border: isMentioningMe
                    ? Border.all(color: Colors.amber, width: 1)
                    : null,
              ),
              child: Text(
                displayText, // Render the friendly name instead of the tag
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMentioningMe
                      ? (isDark || isMe ? Colors.white : Colors.black87)
                      : defaultColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: fullTag,
            style: TextStyle(color: defaultColor),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 16, color: defaultColor, height: 1.3),
        children: spans,
      ),
    );
  }

  Widget _buildMentionList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final filteredGuests = _eventGuests.where((g) {
      final tag = g['tag'] as String;
      return tag.toLowerCase().contains(_mentionQuery!);
    }).toList();

    if (filteredGuests.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(maxHeight: isLandscape ? 120 : 180),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filteredGuests.length,
        itemBuilder: (ctx, i) {
          final guest = filteredGuests[i];
          final String? avatarUrl = guest['avatarUrl'];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(guest['color']),
              radius: 16,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      guest['name'][0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              guest['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              "@${guest['tag']}",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () => _insertMention(guest['tag']),
          );
        },
      ),
    );
  }

  Widget _buildReactionsWidget(Map<String, dynamic> reactions, bool isDark) {
    Map<String, int> counts = {};
    for (var emoji in reactions.values) {
      counts[emoji as String] = (counts[emoji] ?? 0) + 1;
    }

    List<String> displayEmojis = counts.keys.toList();
    int total = reactions.length;

    return GestureDetector(
      onTap: () => _showReactionDetails(reactions),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayEmojis.join(""), style: const TextStyle(fontSize: 12)),
            if (total > 1) ...[
              const SizedBox(width: 4),
              Text(
                total.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadReceipts(List<Map<String, dynamic>> readBy, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: readBy.map((guest) {
        final String? avatarUrl = guest['avatarUrl'];

        return Container(
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 1.5,
            ),
          ),
          child: CircleAvatar(
            radius: 7,
            backgroundColor: Color(guest['color']),
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(
                    guest['name'][0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.grey[200],
      appBar: AppBar(
        title: Text(
          widget.eventTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, height: 1.2),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: Column(
        children: [
          // --- NEW: THE PINNED CONTEXT CARD ---
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(widget.eventId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }
              final eventData = snapshot.data!.data() as Map<String, dynamic>;
              return _buildPinnedContextCard(eventData, isDark, primaryColor);
            },
          ),

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

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: isDark ? Colors.grey[700] : Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "No messages yet.\nStart the conversation!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 20,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(
                      context,
                      docs,
                      index,
                      myUid ==
                          (docs[index].data()
                              as Map<String, dynamic>)['senderId'],
                      isDark,
                      primaryColor,
                    );
                  },
                );
              },
            ),
          ),

          if (_mentionQuery != null) Flexible(child: _buildMentionList()),

          SafeArea(
            bottom: true,
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  if (!isDark)
                    const BoxShadow(
                      color: Colors.black12,
                      offset: Offset(0, -2),
                      blurRadius: 4,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- NEW: QUICK ACTIONS ROW ---
                  _buildQuickActions(isDark, primaryColor),

                  // --- MODERNIZED INPUT ROW ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_isUploadingImage)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 14.0,
                            ),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: IconButton(
                              icon: Icon(
                                Icons.add_photo_alternate,
                                color: primaryColor,
                              ),
                              onPressed: _showAttachmentOptions,
                            ),
                          ),

                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 1000,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: "Say something...",
                              counterText: "",
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: primaryColor.withValues(alpha: 0.6),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: CircleAvatar(
                            backgroundColor: primaryColor,
                            radius: 24,
                            child: IconButton(
                              icon: Icon(
                                Icons.send,
                                color: themeProvider.onPrimaryColor,
                                size: 20,
                              ),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    int index,
    bool isMe,
    bool isDark,
    Color primaryColor,
  ) {
    final data = docs[index].data() as Map<String, dynamic>;
    final String messageId = docs[index].id;
    final String text = data['text'] ?? "";
    final String? imageUrl = data['imageUrl'];
    final String senderName = data['senderName'] ?? "Unknown";
    final int senderColor = data['senderColor'] ?? Colors.blue.toARGB32();
    final String senderId = data['senderId'] ?? "";

    final List<dynamic> mentionedUids = data['mentionedUids'] ?? [];

    Timestamp currentMsgTime =
        data['timestamp'] as Timestamp? ?? Timestamp.now();
    final Timestamp? nextNewerMsgTime = index > 0
        ? (docs[index - 1].data() as Map<String, dynamic>)['timestamp']
              as Timestamp?
        : null;

    final Map<String, dynamic> reactions = Map<String, dynamic>.from(
      data['reactions'] ?? {},
    );

    List<Map<String, dynamic>> readBy = [];
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    _readReceipts.forEach((uid, readTime) {
      if (uid == myUid) return;

      if (readTime.compareTo(currentMsgTime) >= 0) {
        if (nextNewerMsgTime == null ||
            readTime.compareTo(nextNewerMsgTime) < 0) {
          try {
            final guest = _eventGuests.firstWhere((g) => g['uid'] == uid);
            readBy.add(guest);
          } catch (_) {}
        }
      }
    });

    final bool hasReactions = reactions.isNotEmpty;
    final bool hasReceipts = readBy.isNotEmpty;
    final bool needsExtraPadding = hasReactions || hasReceipts;

    final String? extractedUrl = _extractUrl(text);

    final Color myTextColor = themeProvider.onPrimaryColor;
    final Color myTimeColor = myTextColor.withValues(alpha: 0.7);

    String? displayAvatarUrl = data['senderAvatarUrl'];
    try {
      final guest = _eventGuests.firstWhere((g) => g['uid'] == senderId);
      if (guest['avatarUrl'] != null) {
        displayAvatarUrl = guest['avatarUrl'];
      }
    } catch (_) {}

    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    double maxBubbleWidth = screenWidth * (isLandscape ? 0.6 : 0.75);
    maxBubbleWidth = min(maxBubbleWidth, 450); // Hard cap at 450 pixels

    return GestureDetector(
      onLongPress: () => _showMessageOptions(
        messageId,
        text,
        imageUrl,
        senderId,
        isMe,
        reactions,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: needsExtraPadding ? 22 : 12),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(senderColor),
                backgroundImage: displayAvatarUrl != null
                    ? CachedNetworkImageProvider(displayAvatarUrl)
                    : null,
                child: displayAvatarUrl == null
                    ? Text(
                        senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],

            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? primaryColor : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe
                            ? const Radius.circular(16)
                            : const Radius.circular(2),
                        bottomRight: isMe
                            ? const Radius.circular(2)
                            : const Radius.circular(16),
                      ),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              senderName,
                              style: TextStyle(
                                color: isDark
                                    ? Color(senderColor).withValues(alpha: 0.8)
                                    : Color(senderColor),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),

                        if (imageUrl != null)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: text.isNotEmpty ? 8 : 4,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 200,
                                        width: 250,
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade300,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                              ),
                            ),
                          ),

                        if (text.isNotEmpty)
                          _buildMessageText(
                            text,
                            mentionedUids,
                            myUid,
                            isMe,
                            isDark,
                            primaryColor,
                          ),

                        if (extractedUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 8.0,
                              bottom: 4.0,
                            ),
                            child: AnyLinkPreview(
                              link: extractedUrl,
                              displayDirection:
                                  UIDirection.uiDirectionHorizontal,
                              cache: const Duration(days: 7),
                              backgroundColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                              errorWidget: const SizedBox.shrink(),
                              titleStyle: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              bodyStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 11,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.transparent),
                              ],
                              borderRadius: 12,
                            ),
                          ),

                        const SizedBox(height: 4),

                        Align(
                          alignment: Alignment.bottomRight,
                          widthFactor: 1.0,
                          child: Text(
                            _formatTime(currentMsgTime),
                            style: TextStyle(
                              color: isMe
                                  ? myTimeColor
                                  : (isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade500),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (needsExtraPadding)
                    Positioned(
                      bottom: -12,
                      right: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasReactions)
                            _buildReactionsWidget(reactions, isDark),

                          if (hasReactions && hasReceipts)
                            const SizedBox(width: 4),

                          if (hasReceipts) _buildReadReceipts(readBy, isDark),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
