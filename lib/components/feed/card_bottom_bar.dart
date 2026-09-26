import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'last_message_avatar.dart';

/// The bottom bar of the EventSummaryCard showing RSVP actions or the chat snippet.
class CardBottomBar extends StatelessWidget {
  final bool isPending;
  final bool isVibeCheck;
  final bool hasUnreadChat;
  final String? lastMessageSnippet;
  final String eventId;
  final Timestamp? lastMessageAt;

  const CardBottomBar({
    super.key,
    required this.isPending,
    required this.isVibeCheck,
    required this.hasUnreadChat,
    required this.lastMessageSnippet,
    required this.eventId,
    required this.lastMessageAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: isPending
          ? Row(
              children: [
                Icon(
                  isVibeCheck ? Icons.how_to_vote : Symbols.mail,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isVibeCheck ? "Tap to cast your vote" : "Tap to RSVP",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward,
                  color: primaryColor,
                  size: 16,
                ),
              ],
            )
          : Row(
              children: [
                if (hasUnreadChat)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                Expanded(
                  child: Text(
                    lastMessageSnippet != null && lastMessageSnippet!.isNotEmpty
                        ? lastMessageSnippet!
                        : "Tap to view details",
                    style: TextStyle(
                      color: hasUnreadChat
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                      fontSize: 14,
                      fontWeight: hasUnreadChat
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontStyle: lastMessageSnippet != null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (lastMessageSnippet != null &&
                    lastMessageSnippet!.isNotEmpty)
                  LastMessageSenderAvatar(
                    eventId: eventId,
                    lastMessageAt: lastMessageAt,
                  ),
              ],
            ),
    );
  }
}
