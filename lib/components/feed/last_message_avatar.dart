import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/user_cache_repository.dart';

class LastMessageSenderAvatar extends StatefulWidget {
  final String eventId;
  final Timestamp? lastMessageAt;

  const LastMessageSenderAvatar({
    super.key,
    required this.eventId,
    required this.lastMessageAt,
  });

  @override
  State<LastMessageSenderAvatar> createState() =>
      _LastMessageSenderAvatarState();
}

class _LastMessageSenderAvatarState extends State<LastMessageSenderAvatar> {
  Map<String, dynamic>? _senderData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSender();
  }

  @override
  void didUpdateWidget(LastMessageSenderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMessageAt != widget.lastMessageAt ||
        oldWidget.eventId != widget.eventId) {
      _fetchSender();
    }
  }

  Future<void> _fetchSender() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final msgs = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (msgs.docs.isNotEmpty) {
        final senderId = msgs.docs.first.data()['senderId'] as String?;
        if (senderId != null) {
          final userDoc = await UserCacheRepository.instance.getUser(senderId);
          if (userDoc != null && mounted) {
            setState(() => _senderData = userDoc.toMap());
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching last message sender: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _senderData == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final int avatarColor =
        _senderData!['avatarColor'] ?? const Color(0xFF2196F3).toARGB32();
    final String? avatarUrl = _senderData!['avatarUrl'];
    final String name = _senderData!['displayName'] ?? '?';

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: bgColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Color(avatarColor).withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 10,
          backgroundColor: Color(avatarColor),
          backgroundImage: avatarUrl != null
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
