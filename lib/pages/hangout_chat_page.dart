import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

// --- UTILS & COMPONENTS ---
import '../utils/theme_provider.dart';
import '../components/chat/pinned_context_card.dart';
import '../components/chat/chat_quick_actions.dart';
import '../components/chat/message_bubble.dart';

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

  bool _isUploadingImage = false;
  Map<String, dynamic>? _eventData;
  List<Map<String, dynamic>> _eventGuests = [];

  @override
  void initState() {
    super.initState();
    _loadEventData();
    _loadGuests();
    _markChatAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- DATABASE SYNC METHODS ---

  Future<void> _loadEventData() async {
    final doc = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .get();
    if (doc.exists && mounted) {
      setState(() => _eventData = doc.data());
    }
  }

  Future<void> _loadGuests() async {
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
        final userData = userDoc.data()!;
        guests.add({
          'uid': uid,
          'name': userData['displayName'] ?? 'Unknown',
          'tag': userData['username'] ?? '',
          'avatarUrl': userData['avatarUrl'],
          'color': userData['avatarColor'] ?? Colors.blue.toARGB32(),
        });
      }
    }
    if (mounted) setState(() => _eventGuests = guests);
  }

  Future<void> _markChatAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .doc(user.uid)
        .set({
          'lastReadChat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // --- ACTION METHODS ---

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _messageController.clear();

    // Find Mentions
    final RegExp mentionRegex = RegExp(r"\B@[a-zA-Z0-9_]+");
    final matches = mentionRegex.allMatches(text);
    List<String> mentionedUids = [];

    for (var match in matches) {
      final tagWithoutAt = match.group(0)!.substring(1).toLowerCase();
      try {
        final guest = _eventGuests.firstWhere(
          (g) => (g['tag'] as String).toLowerCase() == tagWithoutAt,
        );
        mentionedUids.add(guest['uid']);
      } catch (_) {}
    }

    final batch = FirebaseFirestore.instance.batch();
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId);
    final msgRef = eventRef.collection('messages').doc();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? {};

    batch.set(msgRef, {
      'text': text,
      'imageUrl': imageUrl,
      'senderId': user.uid,
      'senderName': userData['displayName'] ?? 'Someone',
      'senderColor': userData['avatarColor'] ?? Colors.blue.toARGB32(),
      'senderAvatarUrl': userData['avatarUrl'],
      'timestamp': FieldValue.serverTimestamp(),
      'mentionedUids': mentionedUids,
      'reactions': {},
      'readBy': [user.uid],
    });

    batch.update(eventRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSnippet': imageUrl != null ? '📷 Image' : text,
      'lastMessageMentions': mentionedUids,
    });

    await batch.commit();
    _markChatAsRead();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final File file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 800,
        minHeight: 800,
        quality: 75,
      );

      final String fileName =
          'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'chat_images/${widget.eventId}/$fileName',
      );

      await ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();

      await _sendMessage(imageUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // --- QUICK ACTION HANDLERS ---

  void _insertText(String textToInsert) {
    final currentText = _messageController.text;
    _messageController.text = currentText.isEmpty
        ? textToInsert
        : "$currentText $textToInsert";
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = FirebaseAuth.instance.currentUser;

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
      ),
      body: Column(
        children: [
          // 1. Pinned Header
          if (_eventData != null) PinnedContextCard(eventData: _eventData!),

          // 2. Chat Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(widget.eventId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading chat."));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;

                    // Decode Read Receipts
                    List<String> readByUids = List<String>.from(
                      msg['readBy'] ?? [],
                    );
                    List<Map<String, dynamic>> readByProfiles = [];
                    for (String uid in readByUids) {
                      if (uid == msg['senderId'] || uid == user?.uid) continue;
                      try {
                        final g = _eventGuests.firstWhere(
                          (g) => g['uid'] == uid,
                        );
                        readByProfiles.add(g);
                      } catch (_) {}
                    }

                    return MessageBubble(
                      messageId: messages[index].id,
                      text: msg['text'] ?? '',
                      imageUrl: msg['imageUrl'],
                      senderName: msg['senderName'] ?? 'Unknown',
                      senderColor: msg['senderColor'] ?? Colors.blue.toARGB32(),
                      senderId: msg['senderId'] ?? '',
                      senderAvatarUrl: msg['senderAvatarUrl'],
                      mentionedUids: List<dynamic>.from(
                        msg['mentionedUids'] ?? [],
                      ),
                      currentMsgTime: msg['timestamp'] ?? Timestamp.now(),
                      isMe: msg['senderId'] == user?.uid,
                      myUid: user?.uid,
                      reactions: msg['reactions'] ?? {},
                      readBy: readByProfiles,
                      eventGuests: _eventGuests,
                      onOptionsTap: () {
                        // TODO: Implement Delete/Copy dialog
                      },
                      onReadByTap: () {
                        // TODO: Implement Mark as unread/Read list
                      },
                      onReactionsTap: (reactions) {
                        // TODO: Implement Reaction Viewer
                      },
                    );
                  },
                );
              },
            ),
          ),

          // 3. Quick Actions
          ChatQuickActions(
            onMention: () => _insertText("@"),
            onPhoto: _pickAndUploadImage,
            onOmw: () => _insertText("I'm on my way! 🚗"),
            onDibs: () => _insertText("I call dibs on "),
            onBringItem: () => _insertText("I'm bringing "),
          ),

          // 4. Input Field
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_photo_alternate,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: "Send a message...",
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isUploadingImage
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _sendMessage(),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
