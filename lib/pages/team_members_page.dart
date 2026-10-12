import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../components/shared/shared_sliver_app_bar.dart';
import '../components/shared/user_profile_sheet.dart';
import '../components/teams/add_team_members_sheet.dart';
import '../components/teams/team_member_tile.dart';
import '../services/team_service.dart';
import '../services/user_cache_repository.dart';

class TeamMembersPage extends StatefulWidget {
  final String circleId;
  final String circleName;
  final bool autoOpenAddMembers;

  const TeamMembersPage({
    super.key,
    required this.circleId,
    required this.circleName,
    this.autoOpenAddMembers = false,
  });

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  bool _sortByScore = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAddMembers) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showAddMembersBottomSheet(),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndSortMembers(
    List<DocumentSnapshot> friendDocs,
  ) async {
    final friendUids = friendDocs.map((doc) => doc.id).toList();
    final userMap = await UserCacheRepository.instance.getUsers(friendUids);

    List<Map<String, dynamic>> profiles = [];
    for (final doc in friendDocs) {
      final uid = doc.id;
      final friendData = doc.data() as Map<String, dynamic>? ?? {};
      final profile = userMap[uid];
      if (profile != null) {
        final data = profile.toMap();
        data['uid'] = uid;
        data['isGoated'] = friendData['isGoated'] ?? false;
        profiles.add(data);
      }
    }
    if (_sortByScore) {
      profiles.sort((a, b) {
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
      profiles.sort(
        (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
          (b['displayName'] ?? '').toString().toLowerCase(),
        ),
      );
    }
    return profiles;
  }

  Future<bool> _removeMember(String friendUid, String friendName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove from Team?"),
        content: Text("Remove $friendName from ${widget.circleName}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.redAccent : Colors.red,
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await TeamService.removeMemberFromTeam(
          uid: user.uid,
          circleId: widget.circleId,
          friendUid: friendUid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$friendName removed from team!")),
          );
        }
        return true;
      }
    }
    return false;
  }

  void _showAddMembersBottomSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    AddTeamMembersSheet.show(
      context,
      circleId: widget.circleId,
      circleName: widget.circleName,
      userUid: user.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('friends')
            .where('circles', arrayContains: widget.circleId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final friendDocs = snapshot.data!.docs;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchAndSortMembers(friendDocs),
            builder: (context, memberSnapshot) {
              if (memberSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final profiles = memberSnapshot.data ?? [];

              return CustomScrollView(
                slivers: [
                  SharedSliverAppBar(
                    title: widget.circleName,
                    collapsedTitle: widget.circleName,
                    expandedHeight: isLandscape ? 56.0 : 140.0,
                    hasBackButton: true,
                    actions: [
                      Padding(
                        padding: EdgeInsets.only(
                          right: isLandscape ? 4.0 : 16.0,
                        ),
                        child: Center(
                          child: InkWell(
                            onTap: _showAddMembersBottomSheet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add,
                                    color: primaryColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Add",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    bottomContent: Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: primaryColor.withValues(alpha: 0.8),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${profiles.length} Members",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (!isLandscape)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _sortByScore = !_sortByScore);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _sortByScore
                                        ? Icons.leaderboard
                                        : Icons.sort_by_alpha,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sortByScore ? "Ranked" : "A-Z",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
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

                  if (isLandscape)
                    SliverAppBar(
                      pinned: true,
                      toolbarHeight: 48,
                      primary: false,
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.95),
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
                              "Team Members (${profiles.length})",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _sortByScore = !_sortByScore);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _sortByScore
                                          ? Icons.leaderboard
                                          : Icons.sort_by_alpha,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _sortByScore ? "Ranked" : "A-Z",
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

                  if (profiles.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.group_off,
                                size: 64,
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "This team is empty.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap 'Add' to recruit some squadmates!",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (profiles.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final profile = profiles[index];
                          final String uid = profile['uid'];
                          final displayName =
                              profile['displayName'] ?? "Unknown";

                          return TeamMemberTile(
                            profile: profile,
                            index: index,
                            sortByScore: _sortByScore,
                            onConfirmDismiss: () =>
                                _removeMember(uid, displayName),
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
                                  userData: profile,
                                  currentUserId: user.uid,
                                  isGoated: profile['isGoated'] ?? false,
                                  isBlocked: false,
                                  onToggleGoated: (currentGoated) async {
                                    Navigator.pop(ctx);
                                    HapticFeedback.mediumImpact();
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .collection('friends')
                                        .doc(uid)
                                        .set({
                                          'isGoated': !currentGoated,
                                        }, SetOptions(merge: true));
                                  },
                                  onToggleBlocked: (currentBlocked) async {
                                    Navigator.pop(ctx);
                                    HapticFeedback.heavyImpact();
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .update({
                                          'blockedUids': FieldValue.arrayUnion([
                                            uid,
                                          ]),
                                        });
                                  },
                                ),
                              );
                            },
                          );
                        }, childCount: profiles.length),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
