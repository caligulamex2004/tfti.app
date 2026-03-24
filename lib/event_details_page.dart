import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'event_chat_page.dart';
import 'event_roles_page.dart';
import 'edit_event_page.dart';
import 'edit_vibecheck_page.dart';
import 'theme_provider.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventDetailsPage({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  @override
  void initState() {
    super.initState();
    _markDetailsAsViewed();
  }

  Future<void> _markDetailsAsViewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .doc(user.uid)
        .set({
          'lastViewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _openMap(String locationName) async {
    final query = Uri.encodeComponent(locationName);
    Uri url;

    if (Platform.isAndroid) {
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    } else {
      url = Uri.parse("https://maps.apple.com/?q=$query");
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _rsvp(String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .doc(user.uid)
        .set({
          'status': status,
          'respondedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _addFriend(
    BuildContext context,
    String guestUid,
    String guestPhone,
    String guestName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .doc(guestUid)
          .set({
            'uid': guestUid,
            'phone': guestPhone,
            'addedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$guestName joined your squad!")),
        );
      }
    } catch (e) {
      debugPrint("Error adding friend: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndSortGuests(
    List<DocumentSnapshot> inviteDocs,
    DateTime eventTime,
    int deadlineOffset,
  ) async {
    final now = DateTime.now();
    final deadlineTime = eventTime.add(Duration(minutes: deadlineOffset));

    final futures = inviteDocs.map((doc) async {
      final inviteData = doc.data() as Map<String, dynamic>;
      final uid = inviteData['uid'] ?? doc.id;

      String status = inviteData['status'] ?? 'pending';

      if (status == 'pending' && now.isAfter(deadlineTime)) {
        status = 'declined';
      }

      final bool hasSeen =
          inviteData['lastViewedAt'] != null ||
          inviteData['respondedAt'] != null;

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userData = userSnap.exists
          ? (userSnap.data() as Map<String, dynamic>)
          : <String, dynamic>{};

      return {
        'uid': uid,
        'status': status,
        'hasSeen': hasSeen,
        'displayName': userData['displayName'] ?? 'Unknown',
        'phone': userData['phoneNumber'] ?? userData['phone'] ?? '',
        'avatarColor': userData['avatarColor'] ?? 0xFF9E9E9E,
        'avatarUrl': userData['avatarUrl'],
      };
    });

    final results = await Future.wait(futures);

    results.sort((a, b) {
      final nameA = (a['displayName'] as String).toLowerCase();
      final nameB = (b['displayName'] as String).toLowerCase();
      return nameA.compareTo(nameB);
    });

    return results;
  }

  Widget _buildAlertBanner(BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('latestCriticalChange')) {
      return const SizedBox.shrink();
    }

    final changeMap = data['latestCriticalChange'] as Map<String, dynamic>;
    final Timestamp? ts = changeMap['timestamp'];

    if (ts == null) return const SizedBox.shrink();
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inHours > 48) return const SizedBox.shrink();

    final String field = changeMap['field'] ?? 'Details';
    final String original = changeMap['original'] ?? 'Unknown';
    final String newValue = changeMap['new'] ?? 'Unknown';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withValues(alpha: 0.1)
            : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.amber.withValues(alpha: 0.5)
              : Colors.amber.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? Colors.amber.shade400 : Colors.amber.shade900,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update: $field Changed",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.amber.shade400
                        : Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Was: $original\nNow: $newValue",
                  style: TextStyle(
                    color: isDark
                        ? Colors.amber.shade200
                        : Colors.amber.shade900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullDetails(BuildContext context, String details) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
                "Event Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    details,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacepile(
    List<Map<String, dynamic>> guests,
    String myUid,
    bool isDark,
  ) {
    final seenGuests = guests
        .where((g) => g['hasSeen'] == true && g['uid'] != myUid)
        .toList();

    if (seenGuests.isEmpty) return const SizedBox.shrink();

    final displayGuests = seenGuests.take(3).toList();
    final int extraCount = seenGuests.length - 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Seen by ",
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: displayGuests.map((reader) {
            final String? avatarUrl = reader['avatarUrl'];

            return Align(
              widthFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(reader['avatarColor']),
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          reader['displayName'][0].toUpperCase(),
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
          }).toList(),
        ),
        if (extraCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "+$extraCount",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .snapshots(),
      builder: (context, snapshot) {
        var data = widget.eventData;
        if (snapshot.hasData && snapshot.data!.data() != null) {
          data = snapshot.data!.data() as Map<String, dynamic>;
        }

        final bool isVibeCheck = data['type'] == 'vibe_check';

        final bool isMainHost = data['hostId'] == currentUser.uid;
        final bool isCoHost = data['coHostId'] == currentUser.uid;
        final bool canEdit = isMainHost || isCoHost;

        final Timestamp ts = data['time'];
        final DateTime dt = ts.toDate();
        final int rsvpDeadline = data['rsvpDeadline'] ?? 0;

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
        final List<String> weekDays = [
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun',
        ];

        final String weekDay = weekDays[dt.weekday - 1];
        final String day = dt.day.toString();
        final String month = months[dt.month - 1];
        final String year = dt.year.toString();

        int hour = dt.hour;
        final String period = hour >= 12 ? "PM" : "AM";
        hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final String minute = dt.minute.toString().padLeft(2, '0');

        final String dateString =
            "$weekDay $day $month $year at $hour:$minute $period";

        final String? details = data['details'] ?? data['description'];
        final bool hasDetails = details != null && details.isNotEmpty;
        final String location = data['location'] ?? "TBD";

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,

          appBar: AppBar(
            title: Text(
              isVibeCheck ? "Vibe Check" : (data['title'] ?? "Event"),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1.2),
            ),
            centerTitle: true,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: themeProvider.appGradient),
            ),
            actions: [
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    if (isVibeCheck) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditVibeCheckPage(
                            eventId: widget.eventId,
                            eventData: data,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditEventPage(
                            eventId: widget.eventId,
                            eventData: data,
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),

          floatingActionButton: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(widget.eventId)
                .collection('invitations')
                .doc(currentUser.uid)
                .snapshots(),
            builder: (context, inviteSnap) {
              Timestamp? lastReadTime;
              if (inviteSnap.hasData && inviteSnap.data!.exists) {
                final iData = inviteSnap.data!.data() as Map<String, dynamic>;
                lastReadTime = iData['lastReadChat'];
              }

              final Timestamp? lastMsgTime = data['lastMessageAt'];
              final List<dynamic> lastMentions =
                  data['lastMessageMentions'] ?? [];

              bool hasUnread = false;
              bool wasMentioned = false;

              if (lastMsgTime != null) {
                if (lastReadTime == null ||
                    lastMsgTime.seconds > lastReadTime.seconds) {
                  hasUnread = true;
                  if (lastMentions.contains(currentUser.uid)) {
                    wasMentioned = true;
                  }
                }
              }

              return Badge(
                isLabelVisible: hasUnread,
                label: Text(
                  wasMentioned ? "@" : "!",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                backgroundColor: wasMentioned
                    ? Colors.redAccent
                    : Colors.orangeAccent,
                offset: const Offset(-4, 4),
                largeSize: 20,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventChatPage(
                          eventId: widget.eventId,
                          eventTitle: data['title'] ?? "Chat",
                        ),
                      ),
                    );
                  },
                  backgroundColor: primaryColor,
                  foregroundColor: themeProvider.onPrimaryColor,
                  elevation: 4,
                  shape: const CircleBorder(),
                  heroTag: "btn_chat_details",
                  child: const Icon(Icons.chat),
                ),
              );
            },
          ),

          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAlertBanner(context, data),

                      if (isVibeCheck)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            "\"${data['title']}\"",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),

                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            dateString,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (!isVibeCheck)
                        Card(
                          elevation: isDark ? 1 : 2,
                          color: Theme.of(context).cardColor,
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isDark
                                ? BorderSide(color: Colors.grey.shade800)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                            ),
                            title: Text(location),
                            subtitle: Text(
                              "Tap for directions",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () => _openMap(location),
                          ),
                        ),

                      if (hasDetails) ...[
                        const SizedBox(height: 20),
                        const Text(
                          "Details",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        GestureDetector(
                          onTap: () => _showFullDetails(context, details),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                  ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  details,
                                  style: const TextStyle(fontSize: 15),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (details.length > 150 ||
                                    details.contains('\n'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      "Tap to read full details",
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('events')
                            .doc(widget.eventId)
                            .collection('roles')
                            .limit(1)
                            .snapshots(),
                        builder: (context, roleSnap) {
                          final bool hasRoles =
                              roleSnap.hasData &&
                              roleSnap.data!.docs.isNotEmpty;

                          if (!hasRoles) return const SizedBox.shrink();

                          return Column(
                            children: [
                              const SizedBox(height: 20),
                              Card(
                                elevation: isDark ? 1 : 2,
                                color: Theme.of(context).cardColor,
                                surfaceTintColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isDark
                                      ? BorderSide(color: Colors.grey.shade800)
                                      : BorderSide.none,
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.check_box_outlined,
                                    color: primaryColor,
                                  ),
                                  title: const Text(
                                    "Squad Needs (Dibs)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    canEdit
                                        ? "Manage the items you need help with"
                                        : "See what the host needs help with!",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EventRolesPage(
                                          eventId: widget.eventId,
                                          isHost: canEdit,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('events')
                            .doc(widget.eventId)
                            .collection('invitations')
                            .doc(currentUser.uid)
                            .snapshots(),
                        builder: (context, inviteSnap) {
                          Map<String, dynamic> myInviteData = {};
                          String myStatus = 'pending';
                          if (inviteSnap.hasData && inviteSnap.data!.exists) {
                            myInviteData =
                                inviteSnap.data!.data() as Map<String, dynamic>;
                            myStatus = myInviteData['status'] ?? 'pending';
                          }

                          final isGoing = myStatus == 'going';
                          final isDeclined = myStatus == 'declined';

                          return Column(
                            children: [
                              if (isVibeCheck) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Activity Options",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (!isGoing && !isMainHost)
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            bottom: 12.0,
                                          ),
                                          child: Text(
                                            "RSVP 'LET'S GO' below to cast your vote!",
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      VibeCheckPollUI(
                                        eventId: widget.eventId,
                                        eventData: data,
                                        myInviteData: myInviteData,
                                        myUid: currentUser.uid,
                                        isHost: isMainHost,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _rsvp('going'),
                                      icon: Icon(
                                        Icons.check_circle,
                                        color: isGoing
                                            ? Colors.white
                                            : Colors.green,
                                      ),
                                      label: const Text("LET'S GO!"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isGoing
                                            ? Colors.green
                                            : Theme.of(context).cardColor,
                                        foregroundColor: isGoing
                                            ? Colors.white
                                            : Colors.green,
                                        elevation: isGoing
                                            ? 2
                                            : (isDark ? 1 : 0),
                                        side: BorderSide(
                                          color: Colors.green.shade600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _rsvp('declined'),
                                      icon: Icon(
                                        Icons.cancel,
                                        color: isDeclined
                                            ? Colors.white
                                            : Colors.red,
                                      ),
                                      label: const Text("I'm out"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDeclined
                                            ? Colors.red
                                            : Theme.of(context).cardColor,
                                        foregroundColor: isDeclined
                                            ? Colors.white
                                            : Colors.red,
                                        elevation: isDeclined
                                            ? 2
                                            : (isDark ? 1 : 0),
                                        side: BorderSide(
                                          color: Colors.red.shade600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      Divider(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .doc(widget.eventId)
                      .collection('invitations')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final inviteDocs = snapshot.data!.docs;

                    if (inviteDocs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Text("No invitations found."),
                      );
                    }

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchAndSortGuests(inviteDocs, dt, rsvpDeadline),
                      builder: (context, sortedSnap) {
                        if (!sortedSnap.hasData) {
                          return const SliverToBoxAdapter(
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final guests = sortedSnap.data!;

                        return SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      "The Squad",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildFacepile(
                                      guests,
                                      currentUser.uid,
                                      isDark,
                                    ),
                                  ],
                                ),
                              );
                            }

                            final guest = guests[index - 1];
                            final String status = guest['status'];
                            final String guestUid = guest['uid'];
                            final String name = guest['displayName'];
                            final String phone = guest['phone'];
                            final int avatarColor = guest['avatarColor'];
                            final String? avatarUrl = guest['avatarUrl'];

                            final bool isEventMainHost =
                                guestUid == data['hostId'];
                            final bool isEventCoHost =
                                guestUid == data['coHostId'];

                            IconData badgeIcon;
                            Color badgeColor;
                            String statusText;

                            switch (status) {
                              case 'going':
                                badgeIcon = Icons.check_circle;
                                badgeColor = Colors.green;
                                statusText = "is down to clown!";
                                break;
                              case 'declined':
                                badgeIcon = Icons.cancel;
                                badgeColor = Colors.red;
                                statusText = "is missing out...";
                                break;
                              default:
                                badgeIcon = Icons.hourglass_empty;
                                badgeColor = isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700;
                                statusText = "is streets behind.";
                            }

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .collection('friends')
                                  .doc(guestUid)
                                  .snapshots(),
                              builder: (context, friendSnap) {
                                bool isMe = (guestUid == currentUser.uid);
                                bool isFriend = false;

                                if (friendSnap.hasData &&
                                    friendSnap.data!.exists) {
                                  isFriend = true;
                                }

                                bool showAddButton = !isMe && !isFriend;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 0,
                                  ),
                                  leading: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Center(
                                          child: CircleAvatar(
                                            backgroundColor: Color(avatarColor),
                                            radius: 20,
                                            backgroundImage: avatarUrl != null
                                                ? CachedNetworkImageProvider(
                                                    avatarUrl,
                                                  )
                                                : null,
                                            child: avatarUrl == null
                                                ? Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : "?",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          top: -4,
                                          left: -6,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                badgeIcon,
                                                size: 24,
                                                color: Theme.of(
                                                  context,
                                                ).scaffoldBackgroundColor,
                                              ),
                                              Icon(
                                                badgeIcon,
                                                size: 20,
                                                color: badgeColor,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isEventMainHost) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Symbols.crown,
                                          size: 18,
                                          color: Colors.amber,
                                        ),
                                      ] else if (isEventCoHost) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.handshake,
                                          size: 16,
                                          color: primaryColor,
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: status == 'pending'
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                  trailing: showAddButton
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.person_add_alt_1,
                                            color: primaryColor,
                                          ),
                                          tooltip: "Add Friend",
                                          onPressed: () => _addFriend(
                                            context,
                                            guestUid,
                                            phone,
                                            name,
                                          ),
                                        )
                                      : null,
                                );
                              },
                            );
                          }, childCount: guests.length + 1),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class VibeCheckPollUI extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;
  final Map<String, dynamic> myInviteData;
  final String myUid;
  final bool isHost;

  const VibeCheckPollUI({
    super.key,
    required this.eventId,
    required this.eventData,
    required this.myInviteData,
    required this.myUid,
    required this.isHost,
  });

  Future<void> _castVote(String optionId) async {
    final status = myInviteData['status'] ?? 'pending';
    if (status != 'going' && !isHost) {
      return;
    }

    List<String> currentVotes = List<String>.from(myInviteData['votes'] ?? []);
    if (currentVotes.contains(optionId)) {
      currentVotes.remove(optionId);
    } else {
      currentVotes.add(optionId);
    }

    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('invitations')
        .doc(myUid)
        .set({'votes': currentVotes}, SetOptions(merge: true));
  }

  Future<void> _lockInTieBreaker(Map<String, dynamic> option) async {
    final batch = FirebaseFirestore.instance.batch();
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);

    batch.update(eventRef, {
      'type': 'event',
      'lockedOptionId': option['id'],
      'title': option['title'],
      'location': option['location'],
      'isTieBreakerNeeded': false,
    });

    final invitesSnap = await eventRef.collection('invitations').get();
    for (var doc in invitesSnap.docs) {
      final data = doc.data();
      if (data['status'] == 'declined') continue;

      final votes = List<String>.from(data['votes'] ?? []);
      String newStatus = votes.contains(option['id']) ? 'going' : 'pending';
      if (data['role'] == 'host' || data['role'] == 'co-host') {
        newStatus = 'going';
      }

      batch.update(doc.reference, {'status': newStatus});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final options = List<dynamic>.from(eventData['pollOptions'] ?? []);

    final now = DateTime.now();
    final Timestamp? ts = eventData['time'];
    final DateTime eventTime = ts?.toDate() ?? now;
    final int deadlineOffset = eventData['rsvpDeadline'] ?? 0;
    final DateTime deadlineTime = eventTime.add(
      Duration(minutes: deadlineOffset),
    );
    final bool isPastDeadline = now.isAfter(deadlineTime);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('invitations')
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, int> voteCounts = {};

        int totalEligibleVoters = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;

            if (d['status'] == 'declined') continue;

            totalEligibleVoters++;

            final vList = List<String>.from(d['votes'] ?? []);
            for (var v in vList) {
              voteCounts[v] = (voteCounts[v] ?? 0) + 1;
            }
          }
        }

        bool dynamicIsTie = false;
        if (options.isNotEmpty) {
          int maxV = -1;
          int tieCount = 0;
          for (var opt in options) {
            int c = voteCounts[opt['id']] ?? 0;
            if (c > maxV) {
              maxV = c;
              tieCount = 1;
            } else if (c == maxV) {
              tieCount++;
            }
          }
          dynamicIsTie = (tieCount > 1);
        }

        final showTieBreaker = isHost && dynamicIsTie && isPastDeadline;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTieBreaker)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "It's a tie! Lock in your choice below to finalize the event.",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            ...options.map((opt) {
              final optId = opt['id'];
              final count = voteCounts[optId] ?? 0;

              final double percentage = totalEligibleVoters == 0
                  ? 0
                  : (count / totalEligibleVoters);

              final myVotes = List<String>.from(myInviteData['votes'] ?? []);
              final bool iVoted = myVotes.contains(optId);

              return GestureDetector(
                onTap: () => _castVote(optId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iVoted ? primaryColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: percentage > 0 ? percentage : 0.01,
                            heightFactor:
                                1.0, // Fill 100% of the vertical space
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(
                                  alpha: isDark ? 0.3 : 0.2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Foreground Content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              iVoted
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 18,
                              color: iVoted
                                  ? primaryColor
                                  : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    opt['title'],
                                    style: TextStyle(
                                      fontWeight: iVoted
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (opt['location'] != null &&
                                      opt['location'].toString().isNotEmpty &&
                                      opt['location'] != 'TBD')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2.0,
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              size: 10,
                                              color: isDark
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              opt['location'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            if (showTieBreaker)
                              InkWell(
                                onTap: () => _lockInTieBreaker(opt),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "LOCK IN",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                "$count",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
