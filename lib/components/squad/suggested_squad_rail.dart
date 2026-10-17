import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/app_avatar.dart';

class SuggestedSquadRail extends StatelessWidget {
  final bool isDark;
  final Color primaryColor;
  final bool isLandscape;
  final List<Map<String, dynamic>> suggestions;
  final bool hasContactsPermission;
  final Set<String> addedUids;
  final VoidCallback onRequestContacts;
  final Function(Map<String, dynamic>) onSquadUp;

  const SuggestedSquadRail({
    super.key,
    required this.isDark,
    required this.primaryColor,
    required this.isLandscape,
    required this.suggestions,
    required this.hasContactsPermission,
    required this.addedUids,
    required this.onRequestContacts,
    required this.onSquadUp,
  });

  @override
  Widget build(BuildContext context) {
    // On Web, if no suggestions exist, collapse cleanly
    if (kIsWeb && suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    // On mobile, if no suggestions and contacts permission is already granted, collapse cleanly
    if (!kIsWeb && suggestions.isEmpty && hasContactsPermission) {
      return const SizedBox.shrink();
    }

    // On mobile, if permission not yet granted, show the invitation banner
    if (!kIsWeb && suggestions.isEmpty && !hasContactsPermission) {
      return _buildSyncContactsBanner(context);
    }

    final double cardWidth = isLandscape ? 116.0 : 132.0;
    final double railHeight = isLandscape ? 172.0 : 182.0;

    return Container(
      margin: EdgeInsets.only(
        top: 8.0,
        bottom: isLandscape ? 8.0 : 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 16.0 : 20.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "SUGGESTED SQUAD",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (!kIsWeb)
                  GestureDetector(
                    onTap: onRequestContacts,
                    child: Text(
                      "View All",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 16.0 : 20.0,
              ),
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final user = suggestions[index];
                final uid = user['uid'] as String? ?? '';
                final profileName = user['displayName'] as String? ?? '';
                final contactName = user['contactName'] as String?;
                final hasContactName =
                    contactName != null && contactName.trim().isNotEmpty;
                final primaryName =
                    hasContactName ? contactName.trim() : (profileName.isNotEmpty ? profileName : "Friend");
                final username = user['username'] as String? ?? '';
                final avatarUrl = user['avatarUrl'] as String?;
                final avatarColor = user['avatarColor'] as int? ?? Colors.blue.toARGB32();
                final isAdded = addedUids.contains(uid);

                return Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Avatar with subtle glow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(avatarColor).withValues(alpha: 0.25),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: AppAvatar.fromColorValue(
                          radius: 24,
                          avatarColor: avatarColor,
                          avatarUrl: avatarUrl,
                          displayName: primaryName,
                          fontSize: 16,
                        ),
                      ),

                      // Name and handle
                      Column(
                        children: [
                          Text(
                            primaryName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            username.isNotEmpty ? "@$username" : "TFTI Member",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: isAdded
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text(
                                      "Sent",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  onSquadUp(user);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "+ Add",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncContactsBanner(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isLandscape ? 16.0 : 20.0,
        vertical: 10.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.contacts_rounded, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Find friends on TFTI",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Sync your contacts to see who is already here.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onRequestContacts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Sync",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
