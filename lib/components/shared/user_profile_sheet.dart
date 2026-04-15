import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../utils/phone_formatter.dart';

class UserProfileSheet extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String currentUserId;
  final bool isGoated;
  final bool isBlocked;
  final bool showAddButton;

  // Dynamic Callbacks - if provided, the respective button will appear!
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final String targetUid = userData['uid'] ?? userData['id'] ?? "";
    final String displayName = userData['displayName'] ?? "No Name";
    final String username = userData['username'] ?? "";
    final String rawPhone = userData['phoneNumber'] ?? userData['phone'] ?? "";
    final bool showPhone = userData['showPhoneNumber'] == true;
    final String statusText = userData['statusText'] ?? "";
    final String displayPhone = showPhone
        ? PhoneFormatter.beautify(rawPhone)
        : "";

    final String? avatarUrl = userData['avatarUrl'];
    Color avatarColor = Colors.blue.shade100;
    if (userData['avatarColor'] is int) {
      avatarColor = Color(userData['avatarColor']);
    }

    final int hp = userData['hp'] ?? 0;
    final int mana = userData['mana'] ?? 0;
    final Timestamp? createdAt =
        userData['createdAt'] ?? userData['created_at'];

    String originDate = "";
    if (createdAt != null) {
      final DateTime dt = createdAt.toDate();
      final List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      originDate = "Joined ${months[dt.month - 1]} ${dt.year}";
    }

    final plateDecoration = BoxDecoration(
      color: isDark
          ? Colors.black.withValues(alpha: 0.25)
          : Colors.white.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        width: 1,
      ),
    );

    Widget buildStatBar(
      String label,
      int totalValue,
      Color color,
      IconData icon,
    ) {
      int level = (totalValue ~/ 100) + 1;
      int progress = totalValue % 100;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              Text(
                "Lvl. $level",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress / 100.0,
              minHeight: 10,
              backgroundColor: isDark ? Colors.black38 : Colors.white60,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: Text(
              "$progress / 100",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      );
    }

    Widget tcgCard = Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: avatarColor.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: avatarColor.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: avatarColor.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: isLandscape
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: avatarColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                            width: 3,
                          ),
                          image: avatarUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(avatarUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: avatarUrl == null
                            ? Center(
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 60,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildStatBar(
                        "HP (Hangouts)",
                        hp,
                        Colors.redAccent,
                        Icons.whatshot,
                      ),
                      const SizedBox(height: 12),
                      buildStatBar(
                        "Mana (Invites)",
                        mana,
                        Colors.blueAccent,
                        Icons.water_drop,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: plateDecoration,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              if (username.isNotEmpty)
                                TextSpan(
                                  text: "@$username, ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              TextSpan(
                                text: displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isGoated)
                        const Text("🐐", style: TextStyle(fontSize: 22)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                      width: 3,
                    ),
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 60,
                            ),
                          ),
                        )
                      : null,
                ),
                if (statusText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 24.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: plateDecoration,
                    child: Text(
                      '"$statusText"',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                buildStatBar(
                  "HP (Hangouts)",
                  hp,
                  Colors.redAccent,
                  Icons.whatshot,
                ),
                const SizedBox(height: 12),
                buildStatBar(
                  "Mana (Invites)",
                  mana,
                  Colors.blueAccent,
                  Icons.water_drop,
                ),
                const SizedBox(height: 16),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: originDate.isNotEmpty
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      originDate,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: showPhone
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.phone_iphone,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          displayPhone,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: -46,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          "🔥 $hp / $mana 💧",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );

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
                tcgCard,
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
                      isGoated ? "Remove from Goated" : "Mark as Goated",
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
