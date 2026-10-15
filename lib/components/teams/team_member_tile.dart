import 'package:flutter/material.dart';
import '../shared/app_avatar.dart';

class TeamMemberTile extends StatelessWidget {
  final Map<String, dynamic> profile;
  final int index;
  final bool sortByScore;
  final Future<bool> Function() onConfirmDismiss;
  final VoidCallback onTap;

  const TeamMemberTile({
    super.key,
    required this.profile,
    required this.index,
    required this.sortByScore,
    required this.onConfirmDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final String uid = profile['uid'];
    final displayName = profile['displayName'] ?? "Unknown";
    final String username = profile['username'] ?? "";
    final String statusText = profile['statusText'] ?? "";
    final String? avatarUrl = profile['avatarUrl'];
    final Color avatarColor = profile['avatarColor'] is int
        ? Color(profile['avatarColor'])
        : Colors.blue;

    Widget? rankIcon;
    if (sortByScore) {
      if (index == 0) {
        rankIcon = const Padding(
          padding: EdgeInsets.only(right: 6.0),
          child: Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
        );
      } else if (index == 1) {
        rankIcon = Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: Icon(
            Icons.workspace_premium,
            color: Colors.grey.shade400,
            size: 22,
          ),
        );
      } else if (index == 2) {
        rankIcon = const Padding(
          padding: EdgeInsets.only(right: 6.0),
          child: Icon(
            Icons.workspace_premium,
            color: Color(0xFFCD7F32),
            size: 22,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Dismissible(
        key: Key(uid),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24.0),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.person_remove, color: Colors.white, size: 32),
        ),
        confirmDismiss: (direction) async => await onConfirmDismiss(),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: avatarColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AppAvatar(
                      avatarColor: avatarColor,
                      radius: 26,
                      avatarUrl: avatarUrl,
                      displayName: displayName,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ?rankIcon,
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (username.isNotEmpty || statusText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (username.isNotEmpty) ...[
                                  Flexible(
                                    child: Text(
                                      "@$username",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (statusText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0,
                                      ),
                                      child: Text(
                                        "•",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade600
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                ],
                                if (statusText.isNotEmpty)
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: primaryColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
