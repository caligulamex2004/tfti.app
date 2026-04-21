import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/theme_provider.dart';
import 'hangout_details_page.dart';
import '../components/shared/user_profile_sheet.dart';
import '../components/shared/event_summary_card.dart';
import '../components/feed/feed_filter_bar.dart';
import '../components/feed/home_action_fab.dart';
import '../components/feed/empty_feed_states.dart';
import '../components/feed/feed_skeleton.dart';
import '../components/feed/contextual_empty_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedEventId;
  Map<String, dynamic>? _selectedEventData;
  bool _showHidden = false;
  FeedFilter _selectedFilter = FeedFilter.thisWeek;

  Future<void> _toggleHideStatus(String eventId, bool currentlyHidden) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final action = currentlyHidden ? "Unhide" : "Hide";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$action Event?"),
        content: Text(
          currentlyHidden
              ? "Put this event back in your active feed?"
              : "Move this event to your Past/Hidden tab?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: currentlyHidden ? Colors.green : Colors.orange,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('invitations')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'isHidden': !currentlyHidden,
          }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyHidden ? "Event unhidden." : "Event hidden.",
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleHostTap(
    String hostId,
    Map<String, dynamic> hostData,
    List<String> goatedUids,
    List<String> blockedUids,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    hostData['uid'] = hostId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => UserProfileSheet(
        userData: hostData,
        currentUserId: user.uid,
        isGoated: goatedUids.contains(hostId),
        isBlocked: blockedUids.contains(hostId),
        onToggleGoated: (currentGoated) async {
          Navigator.pop(ctx);
          HapticFeedback.mediumImpact();
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('friends')
              .doc(hostId)
              .set({'isGoated': !currentGoated}, SetOptions(merge: true));
        },
        onToggleBlocked: (currentBlocked) async {
          Navigator.pop(ctx);
          HapticFeedback.heavyImpact();
          if (currentBlocked) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
                  'blockedUids': FieldValue.arrayRemove([hostId]),
                });
          } else {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
                  'blockedUids': FieldValue.arrayUnion([hostId]),
                });
          }
        },
      ),
    );
  }

  Widget _buildEventSummaryCardWrapper(
    Map<String, dynamic> item,
    bool isLandscape,
    bool isHorizontal,
    List<String> goatedUids,
    List<String> blockedUids,
  ) {
    final String eventId = item['id'];
    final Map<String, dynamic> data = item['eventData'];
    final bool isHidden = item['inviteData']['isHidden'] ?? false;
    final bool isSelected = _selectedEventId == eventId;

    return EventSummaryCard(
      item: item,
      myUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      isLandscape: isLandscape,
      isHorizontal: isHorizontal,
      isSelected: isSelected,
      onTap: () {
        if (isLandscape) {
          setState(() {
            _selectedEventId = eventId;
            _selectedEventData = data;
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HangoutDetailsPage(eventId: eventId, eventData: data),
            ),
          );
        }
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _toggleHideStatus(eventId, isHidden);
      },
      onHostTap: (hostId, hostData) =>
          _handleHostTap(hostId, hostData, goatedUids, blockedUids),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    Widget feedContent = StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, userSnap) {
        List<String> blockedUids = [];
        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>?;
          if (userData != null && userData['blockedUids'] != null) {
            blockedUids = List<String>.from(userData['blockedUids']);
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('friends')
              .where('isGoated', isEqualTo: true)
              .snapshots(),
          builder: (context, friendsSnap) {
            List<String> goatedUids = [];
            if (friendsSnap.hasData) {
              goatedUids = friendsSnap.data!.docs.map((doc) => doc.id).toList();
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('invitations')
                  .where('uid', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, inviteSnapshot) {
                Map<String, Map<String, dynamic>> myInvitesMap = {};
                if (inviteSnapshot.hasData) {
                  for (var doc in inviteSnapshot.data!.docs) {
                    final eventId = doc.reference.parent.parent?.id;
                    if (eventId != null) {
                      myInvitesMap[eventId] =
                          doc.data() as Map<String, dynamic>;
                    }
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .where('visibleTo', arrayContains: user?.uid)
                      .snapshots(),
                  builder: (context, eventSnapshot) {
                    if (eventSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !eventSnapshot.hasData) {
                      return FeedSkeleton(isLandscape: isLandscape);
                    }
                    if (!eventSnapshot.hasData ||
                        eventSnapshot.data!.docs.isEmpty) {
                      return const EmptyFeedState();
                    }

                    final now = DateTime.now();
                    final int daysSinceMonday = now.weekday - 1;
                    final startOfThisWeek = DateTime(
                      now.year,
                      now.month,
                      now.day - daysSinceMonday,
                    );
                    final int daysToSunday = 7 - now.weekday;
                    final endOfThisWeek = DateTime(
                      now.year,
                      now.month,
                      now.day + daysToSunday,
                      23,
                      59,
                      59,
                    );

                    final startOfNextWeek = endOfThisWeek.add(
                      const Duration(seconds: 1),
                    );
                    final endOfNextWeek = startOfNextWeek.add(
                      const Duration(
                        days: 6,
                        hours: 23,
                        minutes: 59,
                        seconds: 59,
                      ),
                    );

                    final startOfThisMonth = DateTime(now.year, now.month, 1);
                    final endOfThisMonth = DateTime(
                      now.year,
                      now.month + 1,
                      0,
                      23,
                      59,
                      59,
                    );

                    final startOfNextMonth = DateTime(
                      now.year,
                      now.month + 1,
                      1,
                    );
                    final endOfNextMonth = DateTime(
                      now.year,
                      now.month + 2,
                      0,
                      23,
                      59,
                      59,
                    );

                    List<Map<String, dynamic>> actionNeededEvents = [];
                    List<Map<String, dynamic>> agendaEvents = [];
                    List<Map<String, dynamic>> declinedEvents = [];
                    List<Map<String, dynamic>> pastEvents = [];
                    List<Map<String, dynamic>> hiddenEvents = [];

                    for (var eventDoc in eventSnapshot.data!.docs) {
                      final eventId = eventDoc.id;
                      final eventData = eventDoc.data() as Map<String, dynamic>;
                      final String hostId = eventData['hostId'] ?? '';

                      if (blockedUids.contains(hostId)) continue;
                      if (_selectedFilter == FeedFilter.goated &&
                          !goatedUids.contains(hostId)) {
                        continue;
                      }

                      final Timestamp? ts = eventData['time'];
                      final DateTime eventTime = ts?.toDate() ?? now;

                      if (_selectedFilter == FeedFilter.thisWeek &&
                          (eventTime.isBefore(startOfThisWeek) ||
                              eventTime.isAfter(endOfThisWeek))) {
                        continue;
                      } else if (_selectedFilter == FeedFilter.nextWeek &&
                          (eventTime.isBefore(startOfNextWeek) ||
                              eventTime.isAfter(endOfNextWeek))) {
                        continue;
                      } else if (_selectedFilter == FeedFilter.thisMonth &&
                          (eventTime.isBefore(startOfThisMonth) ||
                              eventTime.isAfter(endOfThisMonth))) {
                        continue;
                      } else if (_selectedFilter == FeedFilter.nextMonth &&
                          (eventTime.isBefore(startOfNextMonth) ||
                              eventTime.isAfter(endOfNextMonth))) {
                        continue;
                      }

                      final bool isMyEvent = hostId == user?.uid;
                      final inviteData = myInvitesMap[eventId] ?? {};
                      String status =
                          inviteData['status'] ??
                          (isMyEvent ? 'going' : 'pending');
                      final bool isHidden = inviteData['isHidden'] ?? false;

                      final int deadlineOffset = eventData['rsvpDeadline'] ?? 0;
                      final DateTime deadlineTime = eventTime.add(
                        Duration(minutes: deadlineOffset),
                      );
                      if (status == 'pending' &&
                          now.isAfter(deadlineTime) &&
                          eventData['type'] != 'vibe_check') {
                        status = 'declined';
                      }

                      final Timestamp? endTs = eventData['endTime'];
                      DateTime endTime;
                      if (endTs != null) {
                        endTime = endTs.toDate();
                      } else {
                        final int keepAliveDays =
                            eventData['keepAliveDays'] ?? 0;
                        final int durationMinutes = keepAliveDays > 0
                            ? (keepAliveDays * 24 * 60)
                            : 240;
                        endTime = eventTime.add(
                          Duration(minutes: durationMinutes),
                        );
                      }

                      final bool isPast =
                          (eventData['isPast'] == true) || now.isAfter(endTime);
                      final bool isStartingSoon =
                          eventTime.isAfter(now) &&
                          eventTime.difference(now).inMinutes <= 60;
                      final bool isHappeningNow =
                          !eventTime.isAfter(now) && !now.isAfter(endTime);

                      final eventItem = {
                        'id': eventId,
                        'eventData': eventData,
                        'inviteData': inviteData,
                        'isPast': isPast,
                        'isStartingSoon': isStartingSoon,
                        'isHappeningNow': isHappeningNow,
                        'status': status,
                        'time': eventTime,
                      };

                      if (isHidden) {
                        hiddenEvents.add(eventItem);
                      } else if (isPast) {
                        pastEvents.add(eventItem);
                      } else if (status == 'pending') {
                        actionNeededEvents.add(eventItem);
                      } else if (status == 'going') {
                        agendaEvents.add(eventItem);
                      } else if (status == 'declined') {
                        declinedEvents.add(eventItem);
                      }
                    }

                    actionNeededEvents.sort(
                      (a, b) => (a['time'] as DateTime).compareTo(
                        b['time'] as DateTime,
                      ),
                    );
                    agendaEvents.sort(
                      (a, b) => (a['time'] as DateTime).compareTo(
                        b['time'] as DateTime,
                      ),
                    );
                    declinedEvents.sort(
                      (a, b) => (a['time'] as DateTime).compareTo(
                        b['time'] as DateTime,
                      ),
                    );
                    pastEvents.sort(
                      (a, b) => (b['time'] as DateTime).compareTo(
                        a['time'] as DateTime,
                      ),
                    );
                    hiddenEvents.sort(
                      (a, b) => (b['time'] as DateTime).compareTo(
                        a['time'] as DateTime,
                      ),
                    );

                    String filterText = "";
                    switch (_selectedFilter) {
                      case FeedFilter.thisWeek:
                        filterText = " this week";
                        break;
                      case FeedFilter.nextWeek:
                        filterText = " next week";
                        break;
                      case FeedFilter.thisMonth:
                        filterText = " this month";
                        break;
                      case FeedFilter.nextMonth:
                        filterText = " next month";
                        break;
                      case FeedFilter.goated:
                        filterText = " with your Goated friends";
                        break;
                      case FeedFilter.all:
                      default:
                        filterText = "";
                        break;
                    }

                    return Column(
                      children: [
                        FeedFilterBar(
                          selectedFilter: _selectedFilter,
                          onFilterChanged: (f) =>
                              setState(() => _selectedFilter = f),
                        ),
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    16,
                                  ),
                                  child: Text(
                                    "the i's",
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),

                              // --- ACTION NEEDED ---
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    bottom: 12,
                                  ),
                                  child: Text(
                                    "Action Needed",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              if (actionNeededEvents.isNotEmpty)
                                if (isLandscape)
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) =>
                                            _buildEventSummaryCardWrapper(
                                              actionNeededEvents[index],
                                              isLandscape,
                                              false,
                                              goatedUids,
                                              blockedUids,
                                            ),
                                        childCount: actionNeededEvents.length,
                                      ),
                                    ),
                                  )
                                else
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 310,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        itemCount: actionNeededEvents.length,
                                        itemBuilder: (context, index) =>
                                            _buildEventSummaryCardWrapper(
                                              actionNeededEvents[index],
                                              isLandscape,
                                              true,
                                              goatedUids,
                                              blockedUids,
                                            ),
                                      ),
                                    ),
                                  )
                              else
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 310,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      children: [
                                        ContextualEmptyCard(
                                          icon: Icons.check_circle_outline,
                                          title: "You're all caught up!",
                                          message: "You have no pending invites$filterText.",
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 24),
                              ),

                              // --- THE AGENDA ---
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    bottom: 12,
                                  ),
                                  child: Text(
                                    "The Agenda",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              if (agendaEvents.isNotEmpty)
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) =>
                                          _buildEventSummaryCardWrapper(
                                            agendaEvents[index],
                                            isLandscape,
                                            false,
                                            goatedUids,
                                            blockedUids,
                                          ),
                                      childCount: agendaEvents.length,
                                    ),
                                  ),
                                )
                              else
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 310,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      children: [
                                        ContextualEmptyCard(
                                          icon: Icons.celebration,
                                          title: "Nothing on the agenda.",
                                          message: "Your agenda is looking a bit empty$filterText... Tap the + to host a hangout!",
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 24),
                              ),

                              if (declinedEvents.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 20,
                                      top: 12,
                                      bottom: 12,
                                    ),
                                    child: Text(
                                      "Not Going",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isLandscape)
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) =>
                                            _buildEventSummaryCardWrapper(
                                              declinedEvents[index],
                                              isLandscape,
                                              false,
                                              goatedUids,
                                              blockedUids,
                                            ),
                                        childCount: declinedEvents.length,
                                      ),
                                    ),
                                  )
                                else
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 310,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        itemCount: declinedEvents.length,
                                        itemBuilder: (context, index) =>
                                            _buildEventSummaryCardWrapper(
                                              declinedEvents[index],
                                              isLandscape,
                                              true,
                                              goatedUids,
                                              blockedUids,
                                            ),
                                      ),
                                    ),
                                  ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 24),
                                ),
                              ],

                              if (pastEvents.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 20,
                                      top: 12,
                                      bottom: 12,
                                    ),
                                    child: Text(
                                      "Past Hangouts",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isLandscape)
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) =>
                                            _buildEventSummaryCardWrapper(
                                              pastEvents[index],
                                              isLandscape,
                                              false,
                                              goatedUids,
                                              blockedUids,
                                            ),
                                        childCount: pastEvents.length,
                                      ),
                                    ),
                                  )
                                else
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 310,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        itemCount: pastEvents.length,
                                        itemBuilder: (context, index) =>
                                            _buildEventSummaryCardWrapper(
                                              pastEvents[index],
                                              isLandscape,
                                              true,
                                              goatedUids,
                                              blockedUids,
                                            ),
                                      ),
                                    ),
                                  ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 24),
                                ),
                              ],

                              if (hiddenEvents.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () => setState(
                                        () => _showHidden = !_showHidden,
                                      ),
                                      icon: Icon(
                                        _showHidden
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey,
                                      ),
                                      label: Text(
                                        _showHidden
                                            ? "Hide Archived Events"
                                            : "View Hidden Events (${hiddenEvents.length})",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_showHidden)
                                  if (isLandscape)
                                    SliverPadding(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 100,
                                      ),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) =>
                                              _buildEventSummaryCardWrapper(
                                                hiddenEvents[index],
                                                isLandscape,
                                                false,
                                                goatedUids,
                                                blockedUids,
                                              ),
                                          childCount: hiddenEvents.length,
                                        ),
                                      ),
                                    )
                                  else
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 100,
                                        ),
                                        child: SizedBox(
                                          height: 310,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            itemCount: hiddenEvents.length,
                                            itemBuilder: (context, index) =>
                                                _buildEventSummaryCardWrapper(
                                                  hiddenEvents[index],
                                                  isLandscape,
                                                  true,
                                                  goatedUids,
                                                  blockedUids,
                                                ),
                                          ),
                                        ),
                                      ),
                                    )
                                else
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 100),
                                  ),
                              ] else ...[
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 100),
                                ),
                              ],
                            ],
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
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "thanks for the invite",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 35,
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: feedContent,
                    floatingActionButton: const HomeActionFab(),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                Expanded(
                  flex: 65,
                  child: _selectedEventId != null && _selectedEventData != null
                      ? HangoutDetailsPage(
                          key: ValueKey(_selectedEventId),
                          eventId: _selectedEventId!,
                          eventData: _selectedEventData!,
                        )
                      : const FeedDetailPlaceholder(),
                ),
              ],
            )
          : Scaffold(
              backgroundColor: Colors.transparent,
              body: feedContent,
              floatingActionButton: const HomeActionFab(),
            ),
    );
  }
}
