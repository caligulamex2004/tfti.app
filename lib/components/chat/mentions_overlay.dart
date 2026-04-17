import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MentionsOverlay extends StatelessWidget {
  final String? mentionQuery;
  final List<Map<String, dynamic>> eventGuests;
  final Function(String) onMentionSelected;

  const MentionsOverlay({
    super.key,
    required this.mentionQuery,
    required this.eventGuests,
    required this.onMentionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (mentionQuery == null) {
      return const SizedBox.shrink();
    }

    final filteredGuests = eventGuests.where((g) {
      final name = (g['displayName'] as String).toLowerCase();
      final tag = (g['tag'] as String).toLowerCase();
      return (name.contains(mentionQuery!) || tag.contains(mentionQuery!)) &&
          g['status'] != 'declined';
    }).toList();

    if (filteredGuests.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filteredGuests.length,
        itemBuilder: (context, index) {
          final guest = filteredGuests[index];
          final String name = guest['displayName'];
          final String tag = guest['tag'];
          final String? avatarUrl = guest['avatarUrl'];
          final Color avatarColor = Color(guest['avatarColor']);

          return ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: avatarColor,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "@$tag",
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            onTap: () => onMentionSelected(tag),
          );
        },
      ),
    );
  }
}
