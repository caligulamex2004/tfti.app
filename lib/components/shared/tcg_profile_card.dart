import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TcgProfileCard extends StatelessWidget {
  final String displayName;
  final String username;
  final String statusText;
  final int hp;
  final int mana;
  final String originDate;
  final bool showPhone;
  final String displayPhone;
  final String? avatarUrl;
  final Color avatarColor;
  final bool isGoated;

  // Account Page Edit Features
  final VoidCallback? onAvatarTap;
  final bool isUploadingAvatar;

  const TcgProfileCard({
    super.key,
    required this.displayName,
    required this.username,
    required this.statusText,
    required this.hp,
    required this.mana,
    required this.originDate,
    required this.showPhone,
    required this.displayPhone,
    this.avatarUrl,
    required this.avatarColor,
    this.isGoated = false,
    this.onAvatarTap,
    this.isUploadingAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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

    Widget avatarWidget = Container(
      width: isLandscape ? 120 : 160,
      height: isLandscape ? 120 : 160,
      decoration: BoxDecoration(
        color: avatarColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 3,
        ),
        image: avatarUrl != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: isUploadingAvatar
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : (avatarUrl == null
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
                : null),
    );

    // Add camera overlay if it's editable (Account Page)
    if (onAvatarTap != null) {
      avatarWidget = GestureDetector(
        onTap: onAvatarTap,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            avatarWidget,
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      );
    }

    Widget titleWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        fontSize: isLandscape ? 15 : 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  TextSpan(
                    text: displayName,
                    style: TextStyle(
                      fontSize: isLandscape ? 20 : 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isGoated) const Text("🐐", style: TextStyle(fontSize: 22)),
        ],
      ),
    );

    Widget statusWidget = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: plateDecoration,
      child: Text(
        statusText.isNotEmpty
            ? '"$statusText"'
            : (onAvatarTap != null ? '"Tap below to set a mood..."' : ""),
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
    );

    Widget metaWidget = Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: originDate.isNotEmpty
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
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
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
    );

    Widget hpManaPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
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
        ),
      ),
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isLandscape ? 24 : 0),
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
                      avatarWidget,
                      if (statusText.isNotEmpty || onAvatarTap != null)
                        statusWidget,
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 20),
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: plateDecoration,
                            child: metaWidget,
                          ),
                          Positioned(bottom: -28, child: hpManaPill),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                titleWidget,
                const SizedBox(height: 20),
                avatarWidget,
                if (statusText.isNotEmpty || onAvatarTap != null) statusWidget,
                if (statusText.isEmpty && onAvatarTap == null)
                  const SizedBox(height: 24),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: plateDecoration,
                      child: metaWidget,
                    ),
                    Positioned(bottom: -28, child: hpManaPill),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
