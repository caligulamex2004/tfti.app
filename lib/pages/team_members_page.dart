import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/theme_provider.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import '../components/shared/user_profile_sheet.dart';

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
    List<Map<String, dynamic>> profiles = [];
    await Future.wait(
      friendDocs.map((doc) async {
        final uid = doc.id;
        final friendData = doc.data() as Map<String, dynamic>? ?? {};
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          data['uid'] = uid;
          data['isGoated'] = friendData['isGoated'] ?? false;
          profiles.add(data);
        }
      }),
    );
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('friends')
          .doc(friendUid)
          .update({
            'circles': FieldValue.arrayRemove([widget.circleId]),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$friendName removed from team!")),
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _showAddMembersBottomSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final allFriendsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('friends')
        .get();
    final availableFriendDocs = allFriendsSnapshot.docs
        .where(
          (doc) => !List<String>.from(
            doc.data()['circles'] ?? [],
          ).contains(widget.circleId),
        )
        .toList();

    if (!mounted) {
      return;
    }
    final sortedAvailable = await _fetchAndSortMembers(availableFriendDocs);

    if (!mounted) {
      return;
    }
    if (sortedAvailable.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Everyone is already in here!")),
      );
      return;
    }

    final Set<String> selectedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Add to ${widget.circleName}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: sortedAvailable.length,
                        itemBuilder: (context, index) {
                          final profile = sortedAvailable[index];
                          final uid = profile['uid'];
                          final isSelected = selectedIds.contains(uid);
                          final name = profile['displayName'] ?? "Unknown";
                          final username = profile['username'] ?? "";
                          final avatarUrl = profile['avatarUrl'];
                          final avatarColor = Color(
                            profile['avatarColor'] is int
                                ? profile['avatarColor']
                                : Colors.grey.toARGB32(),
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: avatarColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: avatarColor,
                                radius: 20,
                                backgroundImage: avatarUrl != null
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: username.isNotEmpty
                                ? Text(
                                    "@$username",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: primaryColor,
                                    size: 28,
                                  )
                                : Icon(
                                    Icons.circle_outlined,
                                    color: isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                    size: 28,
                                  ),
                            onTap: () => setDialogState(
                              () => isSelected
                                  ? selectedIds.remove(uid)
                                  : selectedIds.add(uid),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(innerContext);
                                  final batch = FirebaseFirestore.instance
                                      .batch();
                                  final userFriendsRef = FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('friends');
                                  for (final friendId in selectedIds) {
                                    batch.update(userFriendsRef.doc(friendId), {
                                      'circles': FieldValue.arrayUnion([
                                        widget.circleId,
                                      ]),
                                    });
                                  }
                                  await batch.commit();
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Added ${selectedIds.length} friends!",
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: themeProvider.onPrimaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            selectedIds.isEmpty
                                ? "Select Friends"
                                : "Add ${selectedIds.length} to Team",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchAndSortMembers(snapshot.data!.docs),
            builder: (context, profileSnap) {
              if (!profileSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final profiles = profileSnap.data!;
              return CustomScrollView(
                slivers: [
                  SharedSliverAppBar(
                    title: widget.circleName,
                    collapsedTitle: widget.circleName,
                    expandedHeight: isLandscape ? 56.0 : 200.0,
                    hasBackButton: ModalRoute.of(context)?.canPop ?? false,
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
                                  Icon(Icons.person_add, color: primaryColor, size: 16),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _sortByScore ? Icons.leaderboard : Icons.sort_by_alpha,
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
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
                      automaticallyImplyLeading: false,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      flexibleSpace: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Team Members (${profiles.length})",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _sortByScore = !_sortByScore);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      _sortByScore ? Icons.leaderboard : Icons.sort_by_alpha,
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
                          final String username = profile['username'] ?? "";
                          final String statusText = profile['statusText'] ?? "";
                          final String? avatarUrl = profile['avatarUrl'];
                          final Color avatarColor =
                              profile['avatarColor'] is int
                              ? Color(profile['avatarColor'])
                              : Colors.blue;

                          Widget? rankIcon;
                          if (_sortByScore) {
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

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
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
                                child: const Icon(
                                  Icons.person_remove,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              confirmDismiss: (direction) async =>
                                  await _removeMember(uid, displayName),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
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
                                        // Because a team only shows friends, they can't be blocked!
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
                                        onToggleBlocked:
                                            (currentBlocked) async {
                                              Navigator.pop(ctx);
                                              HapticFeedback.heavyImpact();
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .update({
                                                    'blockedUids':
                                                        FieldValue.arrayUnion([
                                                          uid,
                                                        ]),
                                                  });
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
                                                color: avatarColor.withValues(
                                                  alpha: 0.4,
                                                ),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            backgroundColor: avatarColor,
                                            radius: 26,
                                            backgroundImage: avatarUrl != null
                                                ? CachedNetworkImageProvider(
                                                    avatarUrl,
                                                  )
                                                : null,
                                            child: avatarUrl == null
                                                ? Text(
                                                    displayName.isNotEmpty
                                                        ? displayName[0]
                                                              .toUpperCase()
                                                        : "?",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (rankIcon != null) rankIcon,
                                                  Flexible(
                                                    child: Text(
                                                      displayName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 17,
                                                        letterSpacing: -0.3,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (username.isNotEmpty ||
                                                  statusText.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4.0,
                                                      ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      if (username
                                                          .isNotEmpty) ...[
                                                        Flexible(
                                                          child: Text(
                                                            "@$username",
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  primaryColor,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (statusText
                                                            .isNotEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      6.0,
                                                                ),
                                                            child: Text(
                                                              "•",
                                                              style: TextStyle(
                                                                color: isDark
                                                                    ? Colors
                                                                          .grey
                                                                          .shade600
                                                                    : Colors
                                                                          .grey
                                                                          .shade400,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                      if (statusText.isNotEmpty)
                                                        Flexible(
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .secondaryContainer,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color: primaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              statusText,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    primaryColor,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
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
