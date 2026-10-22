import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/badge_service.dart';
import '../../services/notification_service.dart';

/// Wraps the application widget tree to present a polished, top-anchored toast
/// whenever an authorized notification arrives in the foreground.
///
/// Automatically enforces privacy rules:
/// - Suppresses redundant banners for active on-screen chats.
/// - Blocks notifications from being shown to the message sender.
/// - Validates whisper and visibleTo privacy restrictions so uninvited users never see them.
/// - Verifies sender mute status.
class InAppNotificationToastWrapper extends StatefulWidget {
  final Widget child;
  final void Function(Map<String, dynamic> data)? onNotificationTap;
  final Future<bool> Function(RemoteMessage message)? privacyFilter;

  const InAppNotificationToastWrapper({
    super.key,
    required this.child,
    this.onNotificationTap,
    this.privacyFilter,
  });

  @override
  State<InAppNotificationToastWrapper> createState() =>
      _InAppNotificationToastWrapperState();
}

class _InAppNotificationToastWrapperState
    extends State<InAppNotificationToastWrapper>
    with SingleTickerProviderStateMixin {
  StreamSubscription<RemoteMessage>? _messageSub;
  RemoteMessage? _currentMessage;
  Timer? _dismissTimer;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _messageSub = NotificationService.instance.onForegroundMessage.listen(
      _handleIncomingMessage,
    );
  }

  Future<void> _handleIncomingMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];

    if (title == null && body == null) return;

    // Enforce privacy and suppression checks before presenting toast
    final allowed = await _isNotificationAllowed(message);
    if (!allowed || !mounted) return;

    _dismissTimer?.cancel();

    setState(() {
      _currentMessage = message;
    });

    _animController.forward(from: 0.0);

    // Auto-dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), _dismissToast);
  }

  Future<bool> _isNotificationAllowed(RemoteMessage message) async {
    if (widget.privacyFilter != null) {
      return widget.privacyFilter!(message);
    }

    final data = message.data;
    final type = data['type'] as String?;
    final eventId = data['eventId'] as String?;
    final senderId = data['senderId'] as String?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // 1. Never show a toast banner to the sender for their own message
    if (currentUid != null && senderId != null && senderId == currentUid) {
      return false;
    }

    // 2. Suppress chat toast if user is actively viewing this specific chat screen
    if (eventId != null &&
        (type == 'chat' || type == 'chat_mention' || type == 'whisper') &&
        NotificationService.instance.activeChatEventId == eventId) {
      return false;
    }

    // 3. Fast-path check from payload data (whisper and visibleTo)
    final isWhisper = data['isWhisper'] == 'true' || type == 'whisper';
    final whisperRecipientId = data['whisperRecipientId'] as String?;
    final rawVisibleTo = data['visibleTo'];

    if (isWhisper ||
        (whisperRecipientId != null && whisperRecipientId.isNotEmpty)) {
      if (currentUid == null) return false;
      // Only the recipient (or sender) is allowed to see the whisper toast
      if (whisperRecipientId != null &&
          whisperRecipientId.isNotEmpty &&
          whisperRecipientId != currentUid &&
          senderId != currentUid) {
        return false;
      }
    }

    if (rawVisibleTo != null) {
      if (currentUid == null) return false;
      List<String> visibleList = [];
      if (rawVisibleTo is List) {
        visibleList = List<String>.from(rawVisibleTo);
      } else if (rawVisibleTo is String) {
        try {
          final decoded = jsonDecode(rawVisibleTo);
          if (decoded is List) {
            visibleList = List<String>.from(decoded);
          }
        } catch (_) {
          visibleList = rawVisibleTo
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
      if (visibleList.isNotEmpty && !visibleList.contains(currentUid)) {
        return false; // User not in visibleTo audience
      }
    }

    // 4. Fallback verification against Firestore for chat messages
    // (Handles legacy backend push where privacy flags were omitted from payload)
    if ((type == 'chat' || type == 'chat_mention') &&
        eventId != null &&
        currentUid != null) {
      try {
        final messageId = data['messageId'] as String?;
        DocumentSnapshot<Map<String, dynamic>>? msgDoc;

        if (messageId != null && messageId.isNotEmpty) {
          msgDoc = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('messages')
              .doc(messageId)
              .get();
        } else {
          // Query the newest message in this chat
          final snap = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            msgDoc = snap.docs.first;
          }
        }

        if (msgDoc != null && msgDoc.exists) {
          final msgData = msgDoc.data();
          if (msgData != null) {
            // Check visibleTo on document
            final docVisibleTo = msgData['visibleTo'] as List?;
            if (docVisibleTo != null && !docVisibleTo.contains(currentUid)) {
              return false;
            }

            // Check isWhisper on document
            if (msgData['isWhisper'] == true) {
              final recipient = msgData['whisperRecipientId'];
              final sender = msgData['senderId'];
              if (recipient != currentUid && sender != currentUid) {
                return false;
              }
            }

            // Check if sender is current user
            if (msgData['senderId'] == currentUid) {
              return false;
            }

            // Check if the current user muted this sender in this event chat
            final inviteDoc = await FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .collection('invitations')
                .doc(currentUid)
                .get();
            if (inviteDoc.exists) {
              final inviteData = inviteDoc.data();
              final isMuted = inviteData?['isMuted'] ?? false;
              if (isMuted) return false;
              final mutedSenders =
                  List<String>.from(inviteData?['mutedSenderUids'] ?? []);
              final sender = msgData['senderId'] as String?;
              if (sender != null && mutedSenders.contains(sender)) {
                return false;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Privacy verification error: $e');
      }
    }

    return true;
  }

  void _dismissToast() {
    _dismissTimer?.cancel();
    BadgeService.instance.clearBadge();
    if (!mounted) return;
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentMessage = null;
        });
      }
    });
  }

  void _onToastTap() {
    if (_currentMessage != null) {
      final data = _currentMessage!.data;
      BadgeService.instance.clearBadge();
      _dismissToast();
      if (widget.onNotificationTap != null) {
        widget.onNotificationTap!(data);
      }
    }
  }

  IconData _getIconForType(String? type, {bool isWhisper = false}) {
    if (isWhisper) {
      return Icons.hearing_outlined;
    }
    switch (type) {
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'chat':
      case 'chat_mention':
      case 'whisper':
        return Icons.chat_bubble_outline_rounded;
      case 'invite':
        return Icons.mail_outline_rounded;
      case 'points':
        return Icons.star_rounded;
      case 'event_reminder':
      case 'event_start':
        return Icons.schedule_rounded;
      case 'event_update':
        return Icons.event_note_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _messageSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = _currentMessage?.data['type'] as String?;
    final isWhisper = _currentMessage?.data['isWhisper'] == 'true' ||
        type == 'whisper' ||
        (_currentMessage?.data['whisperRecipientId'] != null &&
            _currentMessage!.data['whisperRecipientId']!
                .toString()
                .isNotEmpty);

    final title =
        _currentMessage?.notification?.title ??
        _currentMessage?.data['title'] ??
        'TFTI Alert';
    final body =
        _currentMessage?.notification?.body ??
        _currentMessage?.data['body'] ??
        '';

    final Color accentColor = isWhisper
        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))
        : Theme.of(context).colorScheme.primary;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_currentMessage != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Dismissible(
                        key: ValueKey(_currentMessage!.messageId ?? title),
                        direction: DismissDirection.up,
                        onDismissed: (_) => _dismissToast(),
                        child: Material(
                          elevation: 10,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          color: isDark ? const Color(0xFF1E222A) : Colors.white,
                          child: InkWell(
                            onTap: _onToastTap,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 480),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? (isWhisper
                                          ? const Color(0xFF475569).withValues(
                                              alpha: 0.6,
                                            )
                                          : Colors.white.withValues(alpha: 0.1))
                                      : (isWhisper
                                          ? const Color(0xFFCBD5E1)
                                          : Colors.black.withValues(
                                              alpha: 0.08,
                                            )),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getIconForType(
                                        type,
                                        isWhisper: isWhisper,
                                      ),
                                      color: accentColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isWhisper) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF1E293B)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(0xFF475569)
                                                        : const Color(0xFFCBD5E1),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.hearing_outlined,
                                                      size: 10,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8,
                                                            )
                                                          : const Color(
                                                              0xFF334155,
                                                            ),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Whisper',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF94A3B8,
                                                              )
                                                            : const Color(
                                                                0xFF334155,
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (body.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            body,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade700,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    onPressed: _dismissToast,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
