import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../utils/phone_formatter.dart';
import '../../services/contact_resolver.dart';
import 'tcg_profile_card.dart';

class UserProfileSheet extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String currentUserId;
  final bool isGoated;
  final bool isBlocked;
  final bool showAddButton;

  final Function(String uid, String phone, String name)? onAddFriend;
  final Function(String uid, String name)? onReportUser;
  final Function(bool isCurrentlyGoated)? onToggleGoated;
  final Function(bool isCurrentlyBlocked)? onToggleBlocked;

  const UserProfileSheet({
    super.key,
    required this.userData,
    required this.currentUserId,
    this.isGoated = false,
    this.isBlocked = false,
    this.showAddButton = false,
    this.onAddFriend,
    this.onReportUser,
    this.onToggleGoated,
    this.onToggleBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final String targetUid = userData['uid'] ?? userData['id'] ?? "";
    final bool isSelf = targetUid.isNotEmpty && targetUid == currentUserId;
    final String displayName = userData['displayName'] ?? "No Name";
    final String rawPhone = userData['phoneNumber'] ?? "";
    final String? contactName =
        isSelf ? null : ContactResolver.instance.resolveName(rawPhone);

    final Timestamp? createdAt =
        userData['createdAt'] ?? userData['created_at'];
    String originDate = "";
    if (createdAt != null) {
      final DateTime dt = createdAt.toDate();
      originDate =
          "Joined ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1]} ${dt.year}";
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Inject the TCG Card!
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TcgProfileCard(
                    displayName: displayName,
                    username: userData['username'] ?? "",
                    statusText: userData['statusText'] ?? "",
                    hp: userData['hp'] ?? 0,
                    mana: userData['mana'] ?? 0,
                    originDate: originDate,
                    showPhone: (userData['showPhoneNumber'] ?? userData['isPhonePublic']) != false,
                    displayPhone: PhoneFormatter.beautify(rawPhone),
                    avatarUrl: userData['avatarUrl'],
                    avatarColor: userData['avatarColor'] is int
                        ? Color(userData['avatarColor'])
                        : Colors.blue.shade100,
                    isGoated: isGoated,
                    contactName: contactName,
                    isSelf: isSelf,
                  ),
                ),

                const SizedBox(height: 24),

                if (showAddButton && onAddFriend != null) ...[
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.person_add_alt_1,
                      color: primaryColor,
                      size: 28,
                    ),
                    title: const Text(
                      "Add to Squad",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("Invite them to your future hangouts"),
                    onTap: () => onAddFriend!(targetUid, rawPhone, displayName),
                  ),
                ],
                if (onToggleGoated != null) ...[
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: Icon(
                      Symbols.star,
                      fill: isGoated ? 1.0 : 0.0,
                      color: Colors.amber,
                      size: 28,
                    ),
                    title: Text(
                      isGoated ? "Remove from VIP" : "Add to VIP",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "Show their events first on your feed",
                    ),
                    onTap: () => onToggleGoated!(isGoated),
                  ),
                ],
                if (onToggleBlocked != null) ...[
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: Icon(
                      isBlocked ? Icons.notifications_active : Icons.block,
                      color: isBlocked ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    title: Text(
                      isBlocked ? "Unblock User" : "Block User (Shadow Ban)",
                      style: TextStyle(
                        color: isBlocked ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      isBlocked
                          ? "You will see their invites again"
                          : "Silently hide their invites & chats",
                    ),
                    onTap: () => onToggleBlocked!(isBlocked),
                  ),
                ],
                if (onReportUser != null && targetUid != currentUserId) ...[
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.flag,
                      color: Colors.red,
                      size: 28,
                    ),
                    title: const Text(
                      "Report User",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text("Flag for inappropriate behavior"),
                    onTap: () => onReportUser!(targetUid, displayName),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
