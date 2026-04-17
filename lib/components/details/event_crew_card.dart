import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../shared/info_card.dart';
import '../shared/user_profile_sheet.dart';
import 'details_bottom_sheets.dart';

class EventCrewCard extends StatelessWidget {
  final bool inviteDocsEmpty;
  final Future<List<Map<String, dynamic>>>? cachedCrewFuture;
  final String currentUserId;
  final String hostId;
  final String? coHostId;
  final Function(String uid, String phone, String name) onAddFriend;
  final Function(String uid, String name) onReportUser;

  const EventCrewCard({
    super.key,
    required this.inviteDocsEmpty,
    required this.cachedCrewFuture,
    required this.currentUserId,
    required this.hostId,
    required this.coHostId,
    required this.onAddFriend,
    required this.onReportUser,
  });

  @override
  Widget build(BuildContext context) {
    if (inviteDocsEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text("No invitations found."),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: cachedCrewFuture,
      builder: (context, sortedSnap) {
        if (sortedSnap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                "Connection lost. Please reopen the event.",
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!sortedSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final guests = sortedSnap.data!;
        final seenGuests = guests.where((g) {
          return g['hasSeen'] == true && g['uid'] != currentUserId;
        }).toList();

        return InfoCard(
          title: "The Crew",
          icon: Icons.group,
          onIconTap: seenGuests.isNotEmpty
              ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (ctx) => SeenBySheet(seenGuests: seenGuests),
                  );
                }
              : null,
          child: ListView.builder(
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
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .collection('friends')
                    .doc(guestUid)
                    .snapshots(),
                builder: (context, friendSnap) {
                  bool showAddButton =
                      (guestUid != currentUserId) &&
                      !(friendSnap.hasData && friendSnap.data!.exists);
                  bool isGoated = friendSnap.hasData && friendSnap.data!.exists
                      ? (friendSnap.data!.data()
                                as Map<String, dynamic>)['isGoated'] ==
                            true
                      : false;

                  return InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Theme.of(
                          context,
                        ).scaffoldBackgroundColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (ctx) => UserProfileSheet(
                          userData: guest,
                          showAddButton: showAddButton,
                          isGoated: isGoated,
                          currentUserId: currentUserId,
                          onAddFriend: (uid, phone, name) =>
                              onAddFriend(uid, phone, name),
                          onReportUser: (uid, name) => onReportUser(uid, name),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
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
                                child: CircleAvatar(
                                  backgroundColor: Color(guest['avatarColor']),
                                  radius: 22,
                                  backgroundImage: guest['avatarUrl'] != null
                                      ? CachedNetworkImageProvider(
                                          guest['avatarUrl'],
                                        )
                                      : null,
                                  child: guest['avatarUrl'] == null
                                      ? Text(
                                          guest['displayName'][0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                top: -5,
                                right: -10,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    badgeIcon,
                                    size: 18,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        guest['displayName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (guestUid == hostId)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(
                                          Symbols.crown,
                                          size: 18,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    if (guestUid == coHostId)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(
                                          Symbols.military_tech,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                      ),
                                  ],
                                ),
                                if ((guest['username'] ?? "").isNotEmpty)
                                  Text(
                                    "@${guest['username']}",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (showAddButton)
                            IconButton(
                              icon: Icon(
                                Icons.person_add_alt_1,
                                color: primaryColor,
                              ),
                              onPressed: () => onAddFriend(
                                guestUid,
                                guest['phone'],
                                guest['displayName'],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
