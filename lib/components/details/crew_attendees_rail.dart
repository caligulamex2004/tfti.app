import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../shared/app_avatar.dart';
import '../shared/user_profile_sheet.dart';
import '../../services/contact_resolver.dart';

/// Horizontal carousel displaying attendees with filter pills and a "View All" toggle.
/// In rail mode, it breaks up vertical scrolling with interactive attendee cards.
/// Tapping "View All" smoothly reveals the comprehensive vertical list.
class CrewAttendeesRail extends StatefulWidget {
  final List<Map<String, dynamic>> guests;
  final String currentUserId;
  final String hostId;
  final String? coHostId;
  final Function(String uid, String phone, String name) onAddFriend;
  final Function(String uid, String name) onReportUser;
  final Stream<DocumentSnapshot> Function(String guestUid)? friendStreamProvider;

  const CrewAttendeesRail({
    super.key,
    required this.guests,
    required this.currentUserId,
    required this.hostId,
    required this.coHostId,
    required this.onAddFriend,
    required this.onReportUser,
    this.friendStreamProvider,
  });

  @override
  State<CrewAttendeesRail> createState() => _CrewAttendeesRailState();
}

class _CrewAttendeesRailState extends State<CrewAttendeesRail> {
  String _selectedFilter = 'all'; // 'all', 'going', 'pending', 'declined'
  bool _isFullListView = false;

  void _openUserProfile(
    BuildContext context,
    Map<String, dynamic> guest,
    bool showAddButton,
    bool isGoated,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => UserProfileSheet(
        userData: guest,
        showAddButton: showAddButton,
        isGoated: isGoated,
        currentUserId: widget.currentUserId,
        onAddFriend: (uid, phone, name) =>
            widget.onAddFriend(uid, phone, name),
        onReportUser: (uid, name) => widget.onReportUser(uid, name),
      ),
    );
  }

  Stream<DocumentSnapshot>? _getFriendStream(String guestUid) {
    if (widget.friendStreamProvider != null) {
      return widget.friendStreamProvider!(guestUid);
    }
    if (Firebase.apps.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('friends')
          .doc(guestUid)
          .snapshots();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final goingCount =
        widget.guests.where((g) => g['status'] == 'going').length;
    final pendingCount =
        widget.guests.where((g) => g['status'] == 'pending').length;
    final declinedCount =
        widget.guests.where((g) => g['status'] == 'declined').length;

    List<Map<String, dynamic>> filteredGuests = widget.guests;
    if (_selectedFilter != 'all') {
      filteredGuests = widget.guests
          .where((g) => g['status'] == _selectedFilter)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-Header: Filter Chips & View All Toggle
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: "All (${widget.guests.length})",
                      value: 'all',
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: "Going ($goingCount) 🔥",
                      value: 'going',
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: "Pending ($pendingCount) ⏳",
                      value: 'pending',
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    if (declinedCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: "Declined ($declinedCount)",
                        value: 'declined',
                        primaryColor: primaryColor,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // View All / Rail View Toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isFullListView = !_isFullListView);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isFullListView ? "Rail" : "List",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _isFullListView
                          ? Icons.view_carousel_outlined
                          : Icons.list_alt_rounded,
                      size: 14,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Body: Rail vs Full List View
        if (_isFullListView)
          _buildFullListView(filteredGuests, isDark, primaryColor)
        else
          _buildHorizontalRail(filteredGuests, isDark, primaryColor),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required Color primaryColor,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalRail(
    List<Map<String, dynamic>> guests,
    bool isDark,
    Color primaryColor,
  ) {
    if (guests.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          "No attendees found in this filter.",
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      );
    }

    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: guests.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final guest = guests[index];
          final String guestUid = guest['uid'];
          final String status = guest['status'] ?? 'pending';
          final String displayName = guest['displayName'] ?? 'Attendee';
          final String username = guest['username'] ?? '';
          final int avatarColor = guest['avatarColor'] ?? 0xFF9E9E9E;
          final String? avatarUrl = guest['avatarUrl'];

          final guestPhone = (guest['phoneNumber'] ?? '').toString();
          final contactName =
              ContactResolver.instance.resolveName(guestPhone);
          final bool hasContact =
              contactName != null && contactName.trim().isNotEmpty;
          final String primaryName =
              hasContact ? contactName.trim() : displayName;

          final bool isHost = guestUid == widget.hostId;
          final bool isCoHost = guestUid == widget.coHostId;

          return StreamBuilder<DocumentSnapshot>(
            stream: _getFriendStream(guestUid),
            builder: (context, friendSnap) {
              final bool isFriend =
                  friendSnap.hasData && friendSnap.data!.exists;
              final bool showAddButton =
                  (guestUid != widget.currentUserId) && !isFriend;
              final bool isGoated = isFriend
                  ? (friendSnap.data!.data()
                            as Map<String, dynamic>)['isGoated'] ==
                        true
                  : false;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openUserProfile(
                  context,
                  guest,
                  showAddButton,
                  isGoated,
                ),
                child: Container(
                  width: 122,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.04,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Avatar with glow & status indicator
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(
                                    avatarColor,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 8,
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
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: _buildStatusMiniIcon(status, isDark),
                          ),
                          if (isHost || isCoHost || isGoated)
                            Positioned(
                              top: -4,
                              left: -4,
                              child: _buildRoleMiniBadge(
                                isHost: isHost,
                                isCoHost: isCoHost,
                                isGoated: isGoated,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Name & Username
                      Column(
                        children: [
                          Text(
                            primaryName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (hasContact &&
                              displayName.trim() != primaryName.trim())
                            Text(
                              "~ $displayName",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            )
                          else if (username.isNotEmpty)
                            Text(
                              "@$username",
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Status Pill
                      _buildStatusPill(status, isDark),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusMiniIcon(String status, bool isDark) {
    IconData icon;
    Color color;
    if (status == 'going') {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (status == 'declined') {
      icon = Icons.cancel;
      color = Colors.red;
    } else {
      icon = Icons.hourglass_empty;
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Widget _buildRoleMiniBadge({
    required bool isHost,
    required bool isCoHost,
    required bool isGoated,
  }) {
    String emoji = isHost ? "👑" : (isCoHost ? "⭐" : "🛡️");
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  Widget _buildStatusPill(String status, bool isDark) {
    Color bg;
    Color fg;
    String text;

    if (status == 'going') {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green;
      text = "Going";
    } else if (status == 'declined') {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.red;
      text = "Can't";
    } else {
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = Colors.orange;
      text = "Pending";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildFullListView(
    List<Map<String, dynamic>> guests,
    bool isDark,
    Color primaryColor,
  ) {
    if (guests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            "No attendees in this filter.",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: guests.length,
      itemBuilder: (context, index) {
        final guest = guests[index];
        final String status = guest['status'];
        final String guestUid = guest['uid'];

        IconData badgeIcon = status == 'going'
            ? Icons.check_circle
            : (status == 'declined'
                  ? Icons.cancel
                  : Icons.hourglass_empty);
        Color badgeColor = status == 'going'
            ? Colors.green
            : (status == 'declined'
                  ? Colors.red
                  : (isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade700));

        return StreamBuilder<DocumentSnapshot>(
          stream: _getFriendStream(guestUid),
          builder: (context, friendSnap) {
            bool showAddButton =
                (guestUid != widget.currentUserId) &&
                !(friendSnap.hasData && friendSnap.data!.exists);
            bool isGoated = friendSnap.hasData && friendSnap.data!.exists
                ? (friendSnap.data!.data()
                          as Map<String, dynamic>)['isGoated'] ==
                      true
                : false;

            final guestPhone = (guest['phoneNumber'] ?? '').toString();
            final contactName =
                ContactResolver.instance.resolveName(guestPhone);
            final bool hasContact =
                contactName != null && contactName.trim().isNotEmpty;
            final String primaryName =
                hasContact ? contactName.trim() : guest['displayName'];

            return InkWell(
              onTap: () => _openUserProfile(
                context,
                guest,
                showAddButton,
                isGoated,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  guest['avatarColor'],
                                ).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: AppAvatar.fromColorValue(
                            radius: 20,
                            avatarColor: guest['avatarColor'],
                            avatarUrl: guest['avatarUrl'],
                            displayName: primaryName,
                            fontSize: 14,
                          ),
                        ),
                        if (isGoated)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield,
                                size: 12,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  primaryName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasContact) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: "From your contacts",
                                  child: Icon(
                                    Icons.contact_phone_outlined,
                                    size: 14,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (guestUid == widget.hostId) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Host",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ] else if (guestUid == widget.coHostId) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "Co-Capt",
                                    style: TextStyle(
                                      color: Colors.teal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (hasContact &&
                              guest['displayName'] != null &&
                              guest['displayName'] != primaryName)
                            Text(
                              "~ ${guest['displayName']}${(guest['username'] ?? '').toString().isNotEmpty ? ' (@${guest['username']})' : ''}",
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (guest['username'] != null &&
                              guest['username'].toString().isNotEmpty)
                            Text(
                              "@${guest['username']}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(badgeIcon, color: badgeColor, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
