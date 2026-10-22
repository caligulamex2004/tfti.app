import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

// --- UTILS & COMPONENTS ---
import '../utils/theme_provider.dart';
import '../utils/responsive_layout.dart';
import '../components/chat/pinned_context_card.dart';
import '../components/chat/chat_quick_actions.dart';
import '../components/chat/chat_input_field.dart';
import '../components/chat/mentions_overlay.dart';
import '../components/chat/whisper_recipient_sheet.dart';
import '../components/chat/chat_action_dialogs.dart';
import '../components/chat/chat_feed.dart';
import '../services/user_cache_repository.dart';
import '../services/badge_service.dart';
import '../services/notification_service.dart';

class ChatPage extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const ChatPage({super.key, required this.eventId, required this.eventTitle});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _mentionQuery;
  List<Map<String, dynamic>> _eventGuests = [];
  bool _isUploadingImage = false;
  bool _isMuted = false;
  List<String> _mutedSenderUids = [];
  Map<String, dynamic>? _whisperRecipient;

  StreamSubscription<QuerySnapshot>? _invitationsSub;
  StreamSubscription<DocumentSnapshot>? _eventSub;
  Map<String, dynamic>? _eventData;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.activeChatEventId = widget.eventId;
    BadgeService.instance.clearBadge();
    _listenToEventData();
    _listenToInvitations();
    _messageController.addListener(_onTextChanged);
    _markChatAsRead();
  }

  @override
  void dispose() {
    if (NotificationService.instance.activeChatEventId == widget.eventId) {
      NotificationService.instance.activeChatEventId = null;
    }
    _markChatAsRead();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _invitationsSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  // --- REAL-TIME LISTENERS ---

  void _listenToEventData() {
    _eventSub = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['lastMessageAt'] != null) {
              _markChatAsRead();
            }
            setState(() {
              _eventData = data;
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
          final currentUser = FirebaseAuth.instance.currentUser;
          final guestUids = snapshot.docs.map((doc) => doc.id).toList();
          final userMap = await UserCacheRepository.instance.getUsers(guestUids);

          List<Map<String, dynamic>> guests = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (currentUser != null && doc.id == currentUser.uid) {
              final rawMuted = data['mutedSenderUids'];
              final List<String> mutedList = rawMuted is List
                  ? List<String>.from(rawMuted)
                  : <String>[];
              if (mounted) {
                setState(() {
                  _isMuted = data['isMuted'] ?? false;
                  _mutedSenderUids = mutedList;
                });
              }
            }

            final profile = userMap[doc.id];
            if (profile != null) {
              final String displayName = profile.displayName.isNotEmpty
                  ? profile.displayName
                  : 'Unknown';
              final String realUsername = profile.username.isNotEmpty
                  ? profile.username
                  : displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '');

              guests.add({
                'uid': doc.id,
                'displayName': displayName,
                'tag': realUsername,
                'avatarUrl': profile.avatarUrl,
                'avatarColor': profile.avatarColor,
                'status': data['status'],
                'lastReadChat': data['lastReadChat'],
              });
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

  Future<void> _toggleMuteSender(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final isCurrentlyMuted = _mutedSenderUids.contains(targetUid);
    HapticFeedback.lightImpact();

    setState(() {
      if (isCurrentlyMuted) {
        _mutedSenderUids.remove(targetUid);
      } else {
        _mutedSenderUids.add(targetUid);
      }
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('invitations')
          .doc(user.uid);

      await docRef.set({
        'mutedSenderUids': isCurrentlyMuted
            ? FieldValue.arrayRemove([targetUid])
            : FieldValue.arrayUnion([targetUid]),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyMuted
                  ? "Sender unmuted in this chat."
                  : "Sender muted in this chat.",
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to toggle mute for sender: $e");
    }
  }

  void _openWhisperRecipientSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => WhisperRecipientSheet(
        eventGuests: _eventGuests,
        onSelectRecipient: (recipient) {
          setState(() {
            _whisperRecipient = recipient;
          });
          _focusNode.requestFocus();
        },
      ),
    );
  }

  void _cancelWhisper() {
    setState(() {
      _whisperRecipient = null;
    });
  }

  void _handleWhisperBack(Map<String, dynamic> senderGuest) {
    setState(() {
      _whisperRecipient = senderGuest;
    });
    _focusNode.requestFocus();
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
        .set(
          {'lastReadChat': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
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

    if (!mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final Uint8List bytes = await pickedFile.readAsBytes();
      Uint8List compressedBytes = bytes;
      try {
        compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 800,
          minHeight: 800,
          quality: 80,
        );
      } catch (compressionError) {
        debugPrint(
          "Chat image compression error (using raw bytes): $compressionError",
        );
      }

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

    final activeWhisper = _whisperRecipient;
    _messageController.clear();
    setState(() {
      _mentionQuery = null;
      _whisperRecipient = null; // one-shot mode reset
    });

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

      final Map<String, dynamic> messagePayload = {
        'senderId': user.uid,
        'senderName': userData['displayName'] ?? 'Unknown',
        'senderAvatarUrl': userData['avatarUrl'],
        'senderColor': userData['avatarColor'] ?? Colors.blue.toARGB32(),
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'mentionedUids': mentionedUids.toSet().toList(), // Unique IDs
      };

      if (activeWhisper != null) {
        final recipientUid = activeWhisper['uid'] as String;
        final recipientName =
            activeWhisper['displayName'] as String? ?? 'Guest';
        messagePayload['isWhisper'] = true;
        messagePayload['visibleTo'] = [user.uid, recipientUid];
        messagePayload['whisperRecipientId'] = recipientUid;
        messagePayload['whisperRecipientName'] = recipientName;
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .add(messagePayload);

      // Only update lastMessageSnippet if this is NOT a whisper!
      if (activeWhisper == null) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({
              'lastMessageAt': FieldValue.serverTimestamp(),
              'lastMessageSnippet': imageUrl != null
                  ? '📷 Image'
                  : text.substring(0, text.length > 30 ? 30 : text.length),
            });
      }

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
      body: CenteredContentColumn(
        maxWidth: 860,
        child: Column(
          children: [
            if (_eventData != null) PinnedContextCard(eventData: _eventData!),

            // THE NEW EXTRACTED CHAT FEED COMPONENT!
            Expanded(
              child: ChatFeed(
                eventId: widget.eventId,
                eventGuests: _eventGuests,
                scrollController: _scrollController,
                mutedSenderUids: _mutedSenderUids,
                onToggleMuteSender: _toggleMuteSender,
                onWhisperBack: _handleWhisperBack,
              ),
            ),

            MentionsOverlay(
              mentionQuery: _mentionQuery,
              eventGuests: _eventGuests,
              onMentionSelected: _insertMention,
            ),

            ChatQuickActions(
              onMention: _triggerMentionAction,
              onWhisper: _openWhisperRecipientSheet,
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
              whisperRecipient: _whisperRecipient,
              onCancelWhisper: _cancelWhisper,
            ),
          ],
        ),
      ),
    );
  }
}
