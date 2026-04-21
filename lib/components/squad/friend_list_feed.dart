import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'friend_list_tile.dart';

class FriendListFeed extends StatelessWidget {
  final String myUid;
  final bool isDark;
  final Color primaryColor;
  final bool sortByScore;
  final Set<String> removedFriendUids;
  final VoidCallback onToggleSort;
  final Function(String) onFriendRemoved;
  final List<Widget> headerSlivers;

  const FriendListFeed({
    super.key,
    required this.myUid,
    required this.isDark,
    required this.primaryColor,
    required this.sortByScore,
    required this.removedFriendUids,
    required this.onToggleSort,
    required this.onFriendRemoved,
    this.headerSlivers = const [],
  });

  Future<List<Map<String, dynamic>>> _fetchAndSortFriends(
    List<DocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> list = [];
    await Future.wait(
      docs.map((doc) async {
        final uid = doc.id;
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userSnap.exists) {
          final data = userSnap.data() as Map<String, dynamic>;
          data['uid'] = uid;
          data['isGoated'] =
              (doc.data() as Map<String, dynamic>? ?? {})['isGoated'] ?? false;
          list.add(data);
        }
      }),
    );

    if (sortByScore) {
      list.sort((a, b) {
        final double scoreA = ((a['hp'] ?? 0) * 0.6) + ((a['mana'] ?? 0) * 0.4);
        final double scoreB = ((b['hp'] ?? 0) * 0.6) + ((b['mana'] ?? 0) * 0.4);
        int result = scoreB.compareTo(scoreA);
        if (result == 0) {
          return (a['displayName'] ?? '').toString().toLowerCase().compareTo(
            (b['displayName'] ?? '').toString().toLowerCase(),
          );
        }
        return result;
      });
    } else {
      list.sort(
        (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
          (b['displayName'] ?? '').toString().toLowerCase(),
        ),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .snapshots(),
      builder: (context, myUserSnap) {
        List<String> blockedUids = [];
        if (myUserSnap.hasData && myUserSnap.data!.exists) {
          final data = myUserSnap.data!.data() as Map<String, dynamic>?;
          if (data != null && data['blockedUids'] != null) {
            blockedUids = List<String>.from(data['blockedUids']);
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(myUid)
              .collection('friends')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchAndSortFriends(snapshot.data!.docs),
              builder: (context, friendsSnap) {
                if (!friendsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<Map<String, dynamic>> friends = friendsSnap.data!
                    .where(
                      (friend) => !removedFriendUids.contains(friend['uid']),
                    )
                    .toList();

                if (friends.isEmpty) {
                  return CustomScrollView(
                    slivers: [
                      ...headerSlivers,
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add_alt_1,
                                size: 60,
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Your squad is empty.",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return CustomScrollView(
                  slivers: [
                    ...headerSlivers,
                    SliverAppBar(
                      pinned: true,
                      toolbarHeight: 48,
                      primary: false,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
                      automaticallyImplyLeading: false,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      flexibleSpace: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Squad List (${friends.length})",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: onToggleSort,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      sortByScore
                                          ? Icons.leaderboard
                                          : Icons.sort_by_alpha,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sortByScore ? "Ranked" : "A-Z",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 12),
                      sliver: SliverList.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final Map<String, dynamic> friendInitData =
                              friends[index];
                          final String uid = friendInitData['uid'] as String;

                          Widget? rankIcon;
                          if (sortByScore) {
                            if (index == 0) {
                              rankIcon = const Padding(
                                padding: EdgeInsets.only(right: 6.0),
                                child: Icon(
                                  Icons.workspace_premium,
                                  color: Colors.amber,
                                  size: 22,
                                ),
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

                          return StreamBuilder<DocumentSnapshot>(
                            key: ValueKey(uid),
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .snapshots(),
                            builder: (context, userSnap) {
                              Map<String, dynamic> userData = Map.from(
                                friendInitData,
                              );
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final snapData =
                                    userSnap.data!.data()
                                        as Map<String, dynamic>?;
                                if (snapData != null) {
                                  userData.addAll(snapData);
                                }
                              }

                              final String displayName =
                                  userData['displayName'] ?? "No Name";

                              return FriendListTile(
                                userData: userData,
                                currentUserId: myUid,
                                isGoated: friendInitData['isGoated'] == true,
                                isBlocked: blockedUids.contains(uid),
                                sortByScore: sortByScore,
                                rankIcon: rankIcon,
                                confirmDismiss: (direction) async {
                                  HapticFeedback.mediumImpact();
                                  return await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            "Remove Squad Mate?",
                                          ),
                                          content: Text(
                                            "Are you sure you want to remove $displayName from your squad?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: const Text(
                                                "Remove",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                },
                                onDismissed: (direction) {
                                  onFriendRemoved(uid);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );

                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(myUid)
                                      .collection('friends')
                                      .doc(uid)
                                      .delete()
                                      .then((_) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "$displayName was removed from your squad.",
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
