import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../shared/user_profile_sheet.dart';
import '../shared/app_avatar.dart';
import '../../services/contact_resolver.dart';
import '../../services/contact_service.dart';

class FriendListTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String currentUserId;
  final bool isGoated;
  final bool isBlocked;
  final bool sortByScore;
  final Widget? rankIcon;
  final Future<bool> Function(DismissDirection) confirmDismiss;
  final Function(DismissDirection) onDismissed;

  const FriendListTile({
    super.key,
    required this.userData,
    required this.currentUserId,
    required this.isGoated,
    required this.isBlocked,
    required this.sortByScore,
    this.rankIcon,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final String uid = userData['uid'];
    final bool isMe = uid == currentUserId;
    final String displayName = userData['displayName'] ?? "No Name";
    final String username = userData['username'] ?? "";
    final String rawPhone = userData['phoneNumber'] ?? "";
    final String? contactName =
        isMe ? null : ContactResolver.instance.resolveName(rawPhone);
    final bool hasContactName =
        contactName != null && contactName.trim().isNotEmpty;
    final String? contactFirstName = isMe
        ? ContactHelper.extractFirstName(displayName)
        : ContactResolver.instance.resolveFirstName(
            rawPhone,
            fallbackName: displayName,
          );
    final String primaryName =
        contactFirstName ?? ContactHelper.extractFirstName(displayName);
    final String? avatarUrl = userData['avatarUrl'];
    final Color avatarColor = userData['avatarColor'] is int
        ? Color(userData['avatarColor'])
        : Colors.blue.shade100;
    final int hp = userData['hp'] ?? 0;
    final int mana = userData['mana'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Dismissible(
        key: ValueKey(uid),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_remove, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text(
                "Remove",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: confirmDismiss,
        onDismissed: onDismissed,
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (ctx) => UserProfileSheet(
                    userData: userData,
                    currentUserId: currentUserId,
                    isGoated: isGoated,
                    isBlocked: isBlocked,
                    onToggleGoated: (currentGoated) async {
                      Navigator.pop(ctx);
                      HapticFeedback.mediumImpact();
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUserId)
                          .collection('friends')
                          .doc(uid)
                          .set({
                            'isGoated': !currentGoated,
                          }, SetOptions(merge: true));
                    },
                    onToggleBlocked: (currentBlocked) async {
                      Navigator.pop(ctx);
                      HapticFeedback.heavyImpact();
                      if (currentBlocked) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .update({
                              'blockedUids': FieldValue.arrayRemove([uid]),
                            });
                      } else {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .update({
                              'blockedUids': FieldValue.arrayUnion([uid]),
                            });
                      }
                    },
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
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
                        radius: 26,
                        avatarColor: avatarColor,
                        avatarUrl: avatarUrl,
                        displayName: primaryName,
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
                                  primaryName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: -0.3,
                                    color: isBlocked
                                        ? Colors.grey
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasContactName)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Tooltip(
                                    message: "From your contacts",
                                    child: Icon(
                                      Icons.contact_phone_outlined,
                                      size: 14,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              if (isGoated && !isBlocked)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6.0),
                                  child: Icon(
                                    Symbols.star,
                                    fill: 1.0,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                ),
                              if (isBlocked)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6.0),
                                  child: Icon(
                                    Icons.block,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          if (hasContactName) ...[
                            if (displayName.isNotEmpty &&
                                displayName != primaryName)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "~ $displayName${username.isNotEmpty ? ' (@$username)' : ''}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isBlocked ? Colors.grey : primaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else if (username.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "@$username",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isBlocked ? Colors.grey : primaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ] else if (username.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "@$username",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isBlocked ? Colors.grey : primaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    sortByScore
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$hp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.whatshot,
                                    color: Colors.redAccent,
                                    size: 14,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$mana',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.water_drop,
                                    color: Colors.blueAccent,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Icon(
                            Icons.chevron_right,
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
