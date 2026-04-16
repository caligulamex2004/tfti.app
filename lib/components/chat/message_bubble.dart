import 'dart:math';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/theme_provider.dart';

class MessageBubble extends StatelessWidget {
  final String messageId;
  final String text;
  final String? imageUrl;
  final String senderName;
  final int senderColor;
  final String senderId;
  final String? senderAvatarUrl;
  final List<dynamic> mentionedUids;
  final Timestamp currentMsgTime;
  final bool isMe;
  final String? myUid;
  final Map<String, List<String>> reactions;
  final List<Map<String, dynamic>> readBy;
  final List<Map<String, dynamic>> eventGuests;

  final VoidCallback onOptionsTap;
  final VoidCallback onReadByTap;
  final Function(Map<String, List<String>>) onReactionsTap;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.text,
    this.imageUrl,
    required this.senderName,
    required this.senderColor,
    required this.senderId,
    this.senderAvatarUrl,
    required this.mentionedUids,
    required this.currentMsgTime,
    required this.isMe,
    required this.myUid,
    required this.reactions,
    required this.readBy,
    required this.eventGuests,
    required this.onOptionsTap,
    required this.onReadByTap,
    required this.onReactionsTap,
  });

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
      if (!url.startsWith('http')) url = 'https://$url';
      return url;
    }
    return null;
  }

  Widget _buildMessageText(
    BuildContext context,
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
        // FIX: Cross reference against the REAL username/tag
        final guest = eventGuests.firstWhere((g) {
          final String realTag = g['tag'] ?? '';
          return realTag.toLowerCase() == tagWithoutAt;
        });

        if (mentionedUids.contains(guest['uid'])) {
          isRealMention = true;
          displayText = "@${guest['displayName']}";
          if (guest['uid'] == myUid) isMentioningMe = true;
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
                displayText,
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

  Widget _buildReactionsWidget(BuildContext context, bool isDark) {
    List<String> displayEmojis = [];
    int total = 0;

    reactions.forEach((emoji, usersList) {
      if (usersList.isNotEmpty) {
        displayEmojis.add(emoji);
        total += usersList.length;
      }
    });

    if (displayEmojis.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => onReactionsTap(reactions),
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

  Widget _buildReadReceipts(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: readBy.map((guest) {
        final String? avatarUrl = guest['avatarUrl'];
        final int colorValue = guest['avatarColor'] ?? Colors.blue.toARGB32();
        final String name = guest['displayName'] ?? '?';

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
            backgroundColor: Color(colorValue),
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final bool hasReactions = reactions.isNotEmpty;
    final bool hasReceipts = readBy.isNotEmpty;
    final bool needsExtraPadding = hasReactions || hasReceipts;

    final String? extractedUrl = _extractUrl(text);
    final Color myTextColor = themeProvider.onPrimaryColor;
    final Color myTimeColor = myTextColor.withValues(alpha: 0.7);

    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    double maxBubbleWidth = screenWidth * (isLandscape ? 0.6 : 0.75);
    maxBubbleWidth = min(maxBubbleWidth, 450);

    return GestureDetector(
      onLongPress: onOptionsTap,
      onTap: onReadByTap,
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
                backgroundImage: senderAvatarUrl != null
                    ? CachedNetworkImageProvider(senderAvatarUrl!)
                    : null,
                child: senderAvatarUrl == null
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
                                imageUrl!,
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
                          _buildMessageText(context, isDark, primaryColor),

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
                            _buildReactionsWidget(context, isDark),
                          if (hasReactions && hasReceipts)
                            const SizedBox(width: 4),
                          if (hasReceipts) _buildReadReceipts(context, isDark),
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
