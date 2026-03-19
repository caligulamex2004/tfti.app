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
          final tag = name
              .replaceAll(' ', '')
              .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

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
          .update({'lastReadChat': FieldValue.serverTimestamp()});
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
    final emojis = ['❤️', '👍', '😂', '😲', '😢', '🔥'];

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
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: emojis.map((emoji) {
                    final isSelected =
                        currentReactions[FirebaseAuth
                            .instance
                            .currentUser
                            ?.uid] ==
                        emoji;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleReaction(messageId, emoji, currentReactions);
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
                  }).toList(),
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
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
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
                        final ref = FirebaseStorage.instance.refFromURL(
                          imageUrl,
                        );
                        await ref.delete();
                      } catch (e) {
                        debugPrint("❌ Failed to delete image from Storage: $e");
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
            ],
          ),
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

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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

      try {
        final guest = _eventGuests.firstWhere(
          (g) => (g['tag'] as String).toLowerCase() == tagWithoutAt,
        );
        if (mentionedUids.contains(guest['uid'])) {
          isRealMention = true;
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
                fullTag,
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
      // UPDATED: Dynamic max height to avoid overflow when keyboard is open in landscape
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
        title: Text(widget.eventTitle),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: Column(
        children: [
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

          if (_mentionQuery != null) _buildMentionList(),

          // UPDATED: Added SafeArea around the bottom input container to protect against the iOS home bar
          SafeArea(
            bottom: true,
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
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
                        onPressed: _pickAndUploadImage,
                      ),
                    ),

                  Expanded(
                    child: TextField(
                      controller: _messageController,
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
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
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

    // UPDATED: Dynamically cap the bubble width for ultra-wide screens (like iPads or Landscape phones)
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
                    // UPDATED: Use the new capped width
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
