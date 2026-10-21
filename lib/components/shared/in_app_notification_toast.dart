import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/badge_service.dart';
import '../../services/notification_service.dart';

/// Wraps the application widget tree to present a polished, top-anchored toast
/// whenever a notification arrives in the foreground.
class InAppNotificationToastWrapper extends StatefulWidget {
  final Widget child;
  final void Function(Map<String, dynamic> data)? onNotificationTap;

  const InAppNotificationToastWrapper({
    super.key,
    required this.child,
    this.onNotificationTap,
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

  void _handleIncomingMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];

    if (title == null && body == null) return;

    _dismissTimer?.cancel();

    setState(() {
      _currentMessage = message;
    });

    _animController.forward(from: 0.0);

    // Auto-dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), _dismissToast);
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

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'chat':
      case 'chat_mention':
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
    final title =
        _currentMessage?.notification?.title ??
        _currentMessage?.data['title'] ??
        'TFTI Alert';
    final body =
        _currentMessage?.notification?.body ??
        _currentMessage?.data['body'] ??
        '';

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
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getIconForType(type),
                                      color: Theme.of(context).colorScheme.primary,
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
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
