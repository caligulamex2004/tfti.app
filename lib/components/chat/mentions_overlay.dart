import 'package:flutter/material.dart';
import '../../services/contact_resolver.dart';
import '../shared/app_avatar.dart';

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
      final phone = (g['phoneNumber'] ?? '').toString();
      final contactName = ContactResolver.instance.resolveMiniProfileName(phone);
      final rawName = (g['displayName'] as String? ?? '').toLowerCase();
      final resolvedName = (contactName ??
              ContactResolver.instance.formatMiniProfileFallback(rawName))
          .toLowerCase();
      final tag = (g['tag'] as String? ?? '').toLowerCase();
      return (rawName.contains(mentionQuery!) ||
              resolvedName.contains(mentionQuery!) ||
              tag.contains(mentionQuery!)) &&
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: filteredGuests.length,
          itemBuilder: (context, index) {
            final guest = filteredGuests[index];
            final String displayName = guest['displayName'] ?? '';
            final String phone = (guest['phoneNumber'] ?? '').toString();
            final String name =
                ContactResolver.instance.resolveMiniProfileName(
                      phone,
                      fallbackName: displayName,
                    ) ??
                    ContactResolver.instance.formatMiniProfileFallback(
                      displayName,
                    );
            final String tag = guest['tag'];
            final String? avatarUrl = guest['avatarUrl'];
            final Color avatarColor = Color(guest['avatarColor']);

            return ListTile(
              leading: AppAvatar(
                radius: 16,
                avatarColor: avatarColor,
                avatarUrl: avatarUrl,
                displayName: name,
                fontSize: 12,
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
      ),
    );
  }
}
