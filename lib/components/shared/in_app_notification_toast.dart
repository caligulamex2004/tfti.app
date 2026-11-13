import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/app_toast.dart';
import '../../services/badge_service.dart';
import '../../services/notification_service.dart';

class _ToastBannerData {
  final String keyId;
  final String? title;
  final String body;
  final String? pushType;
  final AppToastType? toastType;
  final bool isWhisper;
  final bool isPushNotification;
  final Map<String, dynamic>? pushData;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  const _ToastBannerData({
    required this.keyId,
    required this.title,
    required this.body,
    this.pushType,
    this.toastType,
    this.isWhisper = false,
    this.isPushNotification = false,
    this.pushData,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(milliseconds: 4500),
  });
}

/// Wraps the application widget tree to present a polished, top-anchored toast
/// whenever an authorized push notification or [AppToast] feedback event arrives.
///
/// Automatically enforces privacy rules for incoming push notifications:
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
  StreamSubscription<AppToastMessage>? _toastSub;
  _ToastBannerData? _currentBanner;
  Timer? _dismissTimer;
  int _pushCounter = 0;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
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
    _toastSub = AppToast.onToast.listen(_handleAppToast);
  }

  void _handleAppToast(AppToastMessage toast) {
    if (!mounted) return;
    _presentBanner(
      _ToastBannerData(
        keyId: toast.id,
        title: toast.title,
        body: toast.message,
        toastType: toast.type,
        isPushNotification: false,
        actionLabel: toast.actionLabel,
        onAction: toast.onAction,
        duration: toast.duration,
      ),
    );
  }

  Future<void> _handleIncomingMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];

    if (title == null && body == null) return;

    final isLocal = message.data['isLocal'] == 'true';

    // Enforce privacy and suppression checks for incoming push notifications
    if (!isLocal) {
      final allowed = await _isNotificationAllowed(message);
      if (!allowed || !mounted) return;
    } else if (!mounted) {
      return;
    }

    final type = message.data['type'] as String?;
    final isWhisper =
        message.data['isWhisper'] == 'true' ||
        type == 'whisper' ||
        (message.data['whisperRecipientId'] != null &&
            message.data['whisperRecipientId'].toString().isNotEmpty);

    _pushCounter++;
    _presentBanner(
      _ToastBannerData(
        keyId: message.messageId ?? 'push_$_pushCounter',
        title: title?.toString() ?? 'TFTI Alert',
        body: body?.toString() ?? '',
        pushType: type,
        toastType: isLocal && type == 'success' ? AppToastType.success : null,
        isWhisper: isWhisper,
        isPushNotification: !isLocal,
        pushData: message.data,
        duration: isLocal
            ? const Duration(seconds: 3)
            : const Duration(milliseconds: 4500),
      ),
    );
  }

  void _presentBanner(_ToastBannerData banner) {
    _dismissTimer?.cancel();
    final wasVisible = _currentBanner != null &&
        (_animController.status == AnimationStatus.completed ||
            _animController.status == AnimationStatus.forward);

    setState(() {
      _currentBanner = banner;
    });

    if (wasVisible) {
      _animController.forward(from: 0.65);
    } else {
      _animController.forward(from: 0.0);
    }

    _dismissTimer = Timer(banner.duration, _dismissToast);
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
              final mutedSenders = List<String>.from(
                inviteData?['mutedSenderUids'] ?? [],
              );
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

  void _dismissToast({bool immediate = false}) {
    _dismissTimer?.cancel();
    if (_currentBanner?.isPushNotification == true) {
      BadgeService.instance.clearBadge();
    }
    if (!mounted) return;
    if (immediate) {
      _animController.reset();
      setState(() {
        _currentBanner = null;
      });
      return;
    }
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentBanner = null;
        });
      }
    });
  }

  void _onToastTap() {
    final banner = _currentBanner;
    if (banner == null) return;

    if (banner.isPushNotification &&
        banner.pushData != null &&
        widget.onNotificationTap != null) {
      final data = banner.pushData!;
      _dismissToast();
      widget.onNotificationTap!(data);
    } else if (banner.onAction != null && banner.actionLabel == null) {
      final callback = banner.onAction!;
      _dismissToast();
      callback();
    } else {
      _dismissToast();
    }
  }

  IconData _resolveIcon(_ToastBannerData banner) {
    if (banner.isWhisper) {
      return Icons.hearing_outlined;
    }
    if (banner.toastType != null) {
      return switch (banner.toastType!) {
        AppToastType.success => Icons.check_circle_outline_rounded,
        AppToastType.error => Icons.error_outline_rounded,
        AppToastType.warning => Icons.warning_amber_rounded,
        AppToastType.info => Icons.info_outline_rounded,
      };
    }
    switch (banner.pushType) {
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

  Color _resolveAccentColor(BuildContext context, _ToastBannerData banner, bool isDark) {
    if (banner.isWhisper) {
      return isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    }
    if (banner.toastType != null) {
      return switch (banner.toastType!) {
        AppToastType.success =>
          isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
        AppToastType.error =>
          isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
        AppToastType.warning =>
          isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        AppToastType.info => Theme.of(context).colorScheme.primary,
      };
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _messageSub?.cancel();
    _toastSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _currentBanner;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = banner != null
        ? _resolveAccentColor(context, banner, isDark)
        : Theme.of(context).colorScheme.primary;
    final hasTitle = banner?.title != null && banner!.title!.isNotEmpty;

    final Color borderColor;
    if (banner != null && banner.isWhisper) {
      borderColor = isDark
          ? const Color(0xFF475569).withValues(alpha: 0.6)
          : const Color(0xFFCBD5E1);
    } else if (banner?.toastType == AppToastType.error ||
        banner?.toastType == AppToastType.warning ||
        banner?.toastType == AppToastType.success) {
      borderColor = accentColor.withValues(alpha: isDark ? 0.4 : 0.25);
    } else {
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08);
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (banner != null)
            SafeArea(
              bottom: false,
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
                        key: ValueKey(banner.keyId),
                        direction: DismissDirection.up,
                        onDismissed: (_) => _dismissToast(immediate: true),
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
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
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
                                      _resolveIcon(banner),
                                      color: accentColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (hasTitle) ...[
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  banner.title!,
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
                                              if (banner.isWhisper) ...[
                                                const SizedBox(width: 6),
                                                _WhisperChip(isDark: isDark),
                                              ],
                                            ],
                                          ),
                                          if (banner.body.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              banner.body,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade700,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ] else
                                          Text(
                                            banner.body,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (banner.actionLabel != null &&
                                      banner.onAction != null) ...[
                                    const SizedBox(width: 8),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: accentColor,
                                        backgroundColor: accentColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        final callback = banner.onAction!;
                                        _dismissToast();
                                        callback();
                                      },
                                      child: Text(
                                        banner.actionLabel!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 28,
                                    ),
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    onPressed: () => _dismissToast(),
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

class _WhisperChip extends StatelessWidget {
  final bool isDark;

  const _WhisperChip({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hearing_outlined,
            size: 10,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
          ),
          const SizedBox(width: 3),
          Text(
            'Whisper',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
