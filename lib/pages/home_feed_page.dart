import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/theme_provider.dart';
import 'hangout_details_page.dart';
import '../create_event_page.dart';
import '../create_vibecheck_page.dart';

enum FeedFilter { all, goated, thisWeek, nextWeek, thisMonth, nextMonth }

class HomeFeedTab extends StatefulWidget {
  const HomeFeedTab({super.key});

  @override
  State<HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<HomeFeedTab> {
  String? _selectedEventId;
  Map<String, dynamic>? _selectedEventData;
  bool _showHidden = false;

  // Phase 4: State variable
  FeedFilter _selectedFilter = FeedFilter.thisWeek;

  Future<void> _quickRSVP(String eventId, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('invitations')
        .doc(user.uid)
        .set({
          'uid': user.uid,
          'status': status,
          'respondedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (mounted) {
      final msg = status == 'going' ? "You're in! 🎉" : "You're missing out...";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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

  void _showHostBottomSheet(
    BuildContext context,
    Map<String, dynamic> hostData,
    bool isDark,
  ) {
    final String name = hostData['displayName'] ?? 'Unknown';
    final String? avatarUrl = hostData['avatarUrl'];
    final int avatarColor = hostData['avatarColor'] ?? Colors.blue.toARGB32();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
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
              const SizedBox(height: 16),
              const Text(
                "Invited by",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(avatarColor).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(avatarColor),
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: const Icon(
                  Symbols.crown,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFab(Color primaryColor, bool isDark) {
    return FloatingActionButton(
      backgroundColor: primaryColor,
      foregroundColor: themeProvider.onPrimaryColor,
      elevation: 4,
      shape: const CircleBorder(),
      heroTag: "btn_create_action",
      child: const Icon(Icons.add, size: 28),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(
                      Icons.how_to_vote,
                      size: 28,
                      color: primaryColor,
                    ),
                    title: const Text(
                      "Hangout",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      "Let the squad know what's happening.",
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateEventPage(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: Icon(
                      Symbols.earthquake,
                      size: 28,
                      color: primaryColor,
                    ),
                    title: const Text(
                      "Vibe Check",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      "Give options and let the squad decide.",
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateVibeCheckPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Tap an i to view details",
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // Phase 4: UI for the horizontal sliding filter chips
  Widget _buildFilterChips(bool isDark, Color primaryColor) {
    final filters = [
      {'label': 'All', 'value': FeedFilter.all},
      {'label': '🐐 Goated', 'value': FeedFilter.goated},
      {'label': 'This Week', 'value': FeedFilter.thisWeek},
      {'label': 'Next Week', 'value': FeedFilter.nextWeek},
      {'label': 'This Month', 'value': FeedFilter.thisMonth},
      {'label': 'Next Month', 'value': FeedFilter.nextMonth},
    ];

    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final bool isSelected = _selectedFilter == filter['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filter['label'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey.shade300 : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
              side: BorderSide(
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (bool selected) {
                if (selected) {
                  HapticFeedback.lightImpact();
                  setState(
                    () => _selectedFilter = filter['value'] as FeedFilter,
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // We build the feed content normally, but wrap it in the required block/goat streams
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
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!eventSnapshot.hasData ||
                        eventSnapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    // Pre-calculate date boundaries for Filter
                    final now = DateTime.now();

                    // THIS WEEK (Monday at 00:00:00 to Sunday at 23:59:59)
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

                    // NEXT WEEK
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

                    // THIS MONTH (1st day to Last day)
                    final startOfThisMonth = DateTime(now.year, now.month, 1);
                    final endOfThisMonth = DateTime(
                      now.year,
                      now.month + 1,
                      0,
                      23,
                      59,
                      59,
                    );

                    // NEXT MONTH
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

                      // --- Phase 4: Shadow Ban & Filter Pre-Checks ---
                      if (blockedUids.contains(hostId)) {
                        continue;
                      }

                      if (_selectedFilter == FeedFilter.goated &&
                          !goatedUids.contains(hostId)) {
                        continue;
                      }

                      final Timestamp? ts = eventData['time'];
                      final DateTime eventTime = ts?.toDate() ?? now;

                      if (_selectedFilter == FeedFilter.thisWeek) {
                        if (eventTime.isBefore(startOfThisWeek) ||
                            eventTime.isAfter(endOfThisWeek)) {
                          continue;
                        }
                      } else if (_selectedFilter == FeedFilter.nextWeek) {
                        if (eventTime.isBefore(startOfNextWeek) ||
                            eventTime.isAfter(endOfNextWeek)) {
                          continue;
                        }
                      } else if (_selectedFilter == FeedFilter.thisMonth) {
                        if (eventTime.isBefore(startOfThisMonth) ||
                            eventTime.isAfter(endOfThisMonth)) {
                          continue;
                        }
                      } else if (_selectedFilter == FeedFilter.nextMonth) {
                        if (eventTime.isBefore(startOfNextMonth) ||
                            eventTime.isAfter(endOfNextMonth)) {
                          continue;
                        }
                      }

                      // --- Original Bucketing Logic ---
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
                      final bool isPastDeadline = now.isAfter(deadlineTime);

                      if (status == 'pending' &&
                          isPastDeadline &&
                          eventData['type'] != 'vibe_check') {
                        status = 'declined';
                      }

                      // --- NEW: Optimized Time Logic using Firestore 'endTime' ---
                      final Timestamp? endTs = eventData['endTime'];
                      DateTime endTime;
                      if (endTs != null) {
                        endTime = endTs.toDate();
                      } else {
                        // Graceful fallback for older events created before Phase 1
                        final int keepAliveDays =
                            eventData['keepAliveDays'] ?? 0;
                        final int durationMinutes = keepAliveDays > 0
                            ? (keepAliveDays * 24 * 60)
                            : 240;
                        endTime = eventTime.add(
                          Duration(minutes: durationMinutes),
                        );
                      }

                      final bool dbIsPast = eventData['isPast'] == true;
                      final bool isPast = dbIsPast || now.isAfter(endTime);
                      final bool isStartingSoon =
                          eventTime.isAfter(now) &&
                          eventTime.difference(now).inMinutes <= 60;
                      // Happening now means 'now' is between the start time and the end time
                      final bool isHappeningNow =
                          !eventTime.isAfter(now) && !now.isAfter(endTime);
                      // -------------------------------------------------------------

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

                    // Sort logic
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

                    if (actionNeededEvents.isEmpty &&
                        agendaEvents.isEmpty &&
                        pastEvents.isEmpty &&
                        declinedEvents.isEmpty &&
                        hiddenEvents.isEmpty) {
                      return Column(
                        children: [
                          _buildFilterChips(isDark, primaryColor),
                          Expanded(child: _buildEmptyState(isDark)),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildFilterChips(
                          isDark,
                          primaryColor,
                        ), // Phase 4 Injection!
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              // 1. The Header
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

                              // 2. Action Needed Carousel
                              if (actionNeededEvents.isNotEmpty) ...[
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

                                if (isLandscape)
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _buildEventCard(
                                          context,
                                          actionNeededEvents[index],
                                          isDark,
                                          primaryColor,
                                          user?.uid,
                                          isLandscape,
                                          isHorizontal: false,
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
                                        itemBuilder: (context, index) {
                                          return _buildEventCard(
                                            context,
                                            actionNeededEvents[index],
                                            isDark,
                                            primaryColor,
                                            user?.uid,
                                            isLandscape,
                                            isHorizontal: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 24),
                                ),
                              ],

                              // 3. The Agenda Vertical List
                              if (agendaEvents.isNotEmpty) ...[
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
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _buildEventCard(
                                        context,
                                        agendaEvents[index],
                                        isDark,
                                        primaryColor,
                                        user?.uid,
                                        isLandscape,
                                        isHorizontal: false,
                                      ),
                                      childCount: agendaEvents.length,
                                    ),
                                  ),
                                ),
                              ],

                              // 4. Not Going (Declined) List
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
                                        (context, index) => _buildEventCard(
                                          context,
                                          declinedEvents[index],
                                          isDark,
                                          primaryColor,
                                          user?.uid,
                                          isLandscape,
                                          isHorizontal: false,
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
                                        itemBuilder: (context, index) {
                                          return _buildEventCard(
                                            context,
                                            declinedEvents[index],
                                            isDark,
                                            primaryColor,
                                            user?.uid,
                                            isLandscape,
                                            isHorizontal: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 24),
                                ),
                              ],

                              // 5. Past Events
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
                                        (context, index) => _buildEventCard(
                                          context,
                                          pastEvents[index],
                                          isDark,
                                          primaryColor,
                                          user?.uid,
                                          isLandscape,
                                          isHorizontal: false,
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
                                        itemBuilder: (context, index) {
                                          return _buildEventCard(
                                            context,
                                            pastEvents[index],
                                            isDark,
                                            primaryColor,
                                            user?.uid,
                                            isLandscape,
                                            isHorizontal: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 24),
                                ),
                              ],

                              // 6. Hidden Events Vault
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
                                          (context, index) => _buildEventCard(
                                            context,
                                            hiddenEvents[index],
                                            isDark,
                                            primaryColor,
                                            user?.uid,
                                            isLandscape,
                                            isHorizontal: false,
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
                                            itemBuilder: (context, index) {
                                              return _buildEventCard(
                                                context,
                                                hiddenEvents[index],
                                                isDark,
                                                primaryColor,
                                                user?.uid,
                                                isLandscape,
                                                isHorizontal: true,
                                              );
                                            },
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
                    floatingActionButton: _buildFab(primaryColor, isDark),
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
                      ? EventDetailsPage(
                          key: ValueKey(_selectedEventId),
                          eventId: _selectedEventId!,
                          eventData: _selectedEventData!,
                        )
                      : _buildPlaceholder(isDark),
                ),
              ],
            )
          : Scaffold(
              backgroundColor: Colors.transparent,
              body: feedContent,
              floatingActionButton: _buildFab(primaryColor, isDark),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "You're all caught up!",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap + to start something.",
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
    Color primaryColor,
    String? myUid,
    bool isLandscape, {
    bool isHorizontal = false,
  }) {
    final String eventId = item['id'];
    final Map<String, dynamic> data = item['eventData'];
    final Map<String, dynamic> inviteData = item['inviteData'];

    final bool isPast = item['isPast'];
    final bool isStartingSoon = item['isStartingSoon'] ?? false;
    final bool isHappeningNow = item['isHappeningNow'];
    final String status = item['status'];
    final bool isHidden = inviteData['isHidden'] ?? false;

    final bool isVibeCheck = data['type'] == 'vibe_check';
    final bool isPending = status == 'pending';

    final String? bannerUrl = data['bannerUrl'];
    final String? lastMessageSnippet = data['lastMessageSnippet'];

    final int keepAliveDays = data['keepAliveDays'] ?? 0;

    final DateTime dt = item['time'] as DateTime;
    final List<String> shortMonths = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final String month = shortMonths[dt.month - 1];
    final String day = dt.day.toString();

    int hour = dt.hour;
    final String period = hour >= 12 ? "PM" : "AM";
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final String timeString =
        "$hour:${dt.minute.toString().padLeft(2, '0')} $period";

    IconData statusIcon = Icons.check_circle;
    Color statusColor = Colors.greenAccent;
    String statusText = "You're going";

    if (isPast) {
      statusText = "Wrapped up";
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.history;
    } else if (status == 'declined') {
      statusText = "Missing out";
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel;
    } else if (isHappeningNow) {
      statusText = "Happening Now!";
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.whatshot;
    } else if (isStartingSoon) {
      statusText = "Starting Soon";
      statusColor = Colors.amberAccent;
      statusIcon = Icons.directions_run;
    } else if (isPending) {
      statusText = isVibeCheck ? "Vote Needed" : "Action Needed";
      statusColor = Colors.orangeAccent;
      statusIcon = isVibeCheck ? Icons.how_to_vote : Symbols.mail;
    }

    final Timestamp? lastMsgTime = data['lastMessageAt'];
    final Timestamp? lastReadTime = inviteData['lastReadChat'];
    bool hasUnreadChat =
        lastMsgTime != null &&
        (lastReadTime == null || lastMsgTime.seconds > lastReadTime.seconds);

    final double safeHorizontalWidth =
        (MediaQuery.of(context).size.width * 0.85).clamp(0.0, 340.0);

    Widget heroCard = Container(
      width: isHorizontal ? safeHorizontalWidth : double.infinity,
      margin: EdgeInsets.only(
        bottom: isHorizontal ? 0 : 24,
        right: isHorizontal ? 16 : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _toggleHideStatus(eventId, isHidden);
          },
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
                      EventDetailsPage(eventId: eventId, eventData: data),
                ),
              );
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- TOP HALF: THE 16:9 HERO IMAGE ---
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bannerUrl != null && bannerUrl.isNotEmpty)
                      CachedNetworkImage(imageUrl: bannerUrl, fit: BoxFit.cover)
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: themeProvider.appGradient,
                        ),
                      ),

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.4, 0.7, 1.0],
                        ),
                      ),
                    ),

                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              month,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              day,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              timeString,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPending
                              ? statusColor
                              : Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: isPending
                              ? null
                              : Border.all(
                                  color: statusColor.withValues(alpha: 0.5),
                                ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              color: isPending ? Colors.white : statusColor,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: isPending ? Colors.white : statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isVibeCheck)
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 6,
                                    right: 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Symbols.earthquake,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "VIBE CHECK",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (keepAliveDays > 0)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.timer,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        keepAliveDays == 1
                                            ? "1 DAY"
                                            : (keepAliveDays == 7
                                                  ? "1 WEEK"
                                                  : "$keepAliveDays DAYS"),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            data['title'] ?? "Untitled Event",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data['location'] ?? "TBD",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (data['hostId'] != null)
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(data['hostId'])
                                  .get(),
                              builder: (context, hostSnap) {
                                if (!hostSnap.hasData ||
                                    !hostSnap.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                final hostData =
                                    hostSnap.data!.data()
                                        as Map<String, dynamic>;
                                final hostName =
                                    hostData['displayName'] ?? 'Someone';
                                final avatarUrl = hostData['avatarUrl'];
                                final avatarColor = Color(
                                  hostData['avatarColor'] ??
                                      Colors.blue.toARGB32(),
                                );

                                return GestureDetector(
                                  onTap: () => _showHostBottomSheet(
                                    context,
                                    hostData,
                                    isDark,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: avatarColor,
                                        backgroundImage: avatarUrl != null
                                            ? CachedNetworkImageProvider(
                                                avatarUrl,
                                              )
                                            : null,
                                        child: avatarUrl == null
                                            ? Text(
                                                hostName.isNotEmpty
                                                    ? hostName[0].toUpperCase()
                                                    : "?",
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Led by $hostName",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- BOTTOM HALF: Quick Actions OR Pulse ---
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: isHorizontal && isPending
                    ? (isVibeCheck
                          ? Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EventDetailsPage(
                                                eventId: eventId,
                                                eventData: data,
                                              ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor:
                                          themeProvider.onPrimaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "Vote Now",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _quickRSVP(eventId, 'declined'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: Colors.red.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "Decline",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      _quickRSVP(eventId, 'going');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor:
                                          themeProvider.onPrimaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "I'm In!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ))
                    : Row(
                        children: [
                          if (hasUnreadChat)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: isDark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade400,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              lastMessageSnippet != null &&
                                      lastMessageSnippet.isNotEmpty
                                  ? lastMessageSnippet
                                  : "Tap to view details",
                              style: TextStyle(
                                color: hasUnreadChat
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600),
                                fontSize: 14,
                                fontWeight: hasUnreadChat
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontStyle: lastMessageSnippet != null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessageSnippet != null &&
                              lastMessageSnippet.isNotEmpty)
                            LastMessageSenderAvatar(
                              eventId: eventId,
                              lastMessageAt: data['lastMessageAt'] as Timestamp,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    // The Compact Landscape Card
    Widget cardToRender;
    if (isLandscape && !isHorizontal) {
      final bool isSelected = _selectedEventId == eventId;
      cardToRender = Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isDark && !isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedEventId = eventId;
              _selectedEventData = data;
            });
          },
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _toggleHideStatus(eventId, isHidden);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (bannerUrl != null && bannerUrl.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: bannerUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: themeProvider.appGradient,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (hasUnreadChat) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['title'] ?? "Untitled Event",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$month $day • $timeString",
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
                  ],
                ),
                if (isPending) ...[
                  const SizedBox(height: 12),
                  if (isVibeCheck)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          _selectedEventId = eventId;
                          _selectedEventData = data;
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: themeProvider.onPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          "Vote Now",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _quickRSVP(eventId, 'declined'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              "Decline",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _quickRSVP(eventId, 'going');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: themeProvider.onPrimaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              "I'm In!",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    } else {
      cardToRender = heroCard;
    }

    if (isHorizontal) return cardToRender;

    return Dismissible(
      key: Key(eventId),
      direction: isPast ? DismissDirection.none : DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24.0),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Symbols.thumb_up, color: Colors.white, size: 36),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Symbols.thumb_down, color: Colors.white, size: 36),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.startToEnd) {
          await _quickRSVP(eventId, 'going');
        } else if (direction == DismissDirection.endToStart) {
          await _quickRSVP(eventId, 'declined');
        }
        return false;
      },
      child: cardToRender,
    );
  }
}

class LastMessageSenderAvatar extends StatefulWidget {
  final String eventId;
  final Timestamp lastMessageAt;

  const LastMessageSenderAvatar({
    super.key,
    required this.eventId,
    required this.lastMessageAt,
  });

  @override
  State<LastMessageSenderAvatar> createState() =>
      _LastMessageSenderAvatarState();
}

class _LastMessageSenderAvatarState extends State<LastMessageSenderAvatar> {
  Map<String, dynamic>? _senderData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSender();
  }

  @override
  void didUpdateWidget(LastMessageSenderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMessageAt != widget.lastMessageAt ||
        oldWidget.eventId != widget.eventId) {
      _fetchSender();
    }
  }

  Future<void> _fetchSender() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final msgs = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (msgs.docs.isNotEmpty) {
        final senderId = msgs.docs.first.data()['senderId'];
        if (senderId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .get();
          if (userDoc.exists && mounted) {
            setState(() {
              _senderData = userDoc.data() as Map<String, dynamic>;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching last message sender: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _senderData == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final int avatarColor =
        _senderData!['avatarColor'] ?? const Color(0xFF2196F3).toARGB32();
    final String? avatarUrl = _senderData!['avatarUrl'];
    final String name = _senderData!['displayName'] ?? '?';

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: bgColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Color(avatarColor).withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 10,
          backgroundColor: Color(avatarColor),
          backgroundImage: avatarUrl != null
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
