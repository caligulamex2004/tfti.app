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
  final ScrollController _scrollController = ScrollController();
  bool _isAppBarCollapsed = false;

  // FIX: Declare persistent stream variables
  late Stream<DocumentSnapshot> _eventStream;
  late Stream<QuerySnapshot> _rolesStream;
  late Stream<DocumentSnapshot> _myInviteStream;
  late Stream<QuerySnapshot> _crewStream;

  @override
  void initState() {
    super.initState();

    // FIX: Initialize them ONCE when the page loads
    final user = FirebaseAuth.instance.currentUser;
    _eventStream = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .snapshots();
    _rolesStream = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('roles')
        .limit(1)
        .snapshots();
    _crewStream = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('invitations')
        .snapshots();

    if (user != null) {
      _myInviteStream = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('invitations')
          .doc(user.uid)
          .snapshots();
    }

    _markDetailsAsViewed();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        bool isCollapsed = _scrollController.offset > 140;
        if (isCollapsed != _isAppBarCollapsed) {
          setState(() {
            _isAppBarCollapsed = isCollapsed;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId);
    final inviteRef = eventRef.collection('invitations').doc(user.uid);

    // FIX 1: Direct set() triggers instant, stable local UI updates (bypassing batch delay)
    await inviteRef.set({
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Handle tie-breaker independently after the RSVP is securely saved
    final evSnap = await eventRef.get();
    if (evSnap.exists) {
      final evData = evSnap.data() as Map<String, dynamic>;
      if (evData['type'] == 'vibe_check' &&
          evData['isTieBreakerNeeded'] == true) {
        await eventRef.update({'isTieBreakerNeeded': false});
      }
    }
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
        'username': userData['username'] ?? '',
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

  // --- CRITICAL CHANGE ALERT BANNER ---
  Widget _buildAlertBanner(BuildContext context, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final change = data['latestCriticalChange'] as Map<String, dynamic>?;

    if (change == null) return const SizedBox.shrink();

    final field = change['field'] ?? 'Details';
    final original = change['original'] ?? '';
    final newValue = change['new'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "HEADS UP: $field Changed!",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Was: $original\nNow: $newValue",
                  style: TextStyle(
                    color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                    fontSize: 13,
                    height: 1.4,
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
                "About",
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

  void _showSeenByBottomSheet(List<Map<String, dynamic>> seenGuests) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(
      context,
    ).colorScheme.primary; // Added to color the username

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                  "Seen By",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: seenGuests.length,
                    itemBuilder: (context, index) {
                      final guest = seenGuests[index];
                      final String name = guest['displayName'];
                      final String username =
                          guest['username'] ?? ""; // NEW: Extract username
                      final String? avatarUrl = guest['avatarUrl'];
                      final int avatarColor =
                          guest['avatarColor'] ?? Colors.blue.toARGB32();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  avatarColor,
                                ).withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(avatarColor),
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
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        // 👇 NEW: Display @username as subtitle if they have one
                        subtitle: username.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  "@$username",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    return InkWell(
      onTap: () => _showSeenByBottomSheet(seenGuests),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Seen by  ",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
                        color: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade100,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(
                            reader['avatarColor'],
                          ).withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(reader['avatarColor']),
                      backgroundImage: avatarUrl != null
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              reader['displayName'][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
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
                padding: const EdgeInsets.only(left: 10.0),
                child: Text(
                  "+$extraCount",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- TACTILE CARD WRAPPER ---
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // THE FIX: We use a LayoutBuilder to measure the ACTUAL space
    // main.dart has given us, rather than relying on the global screen width!
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we have more than 600 pixels of true width, use the 2-column layout.
        // Otherwise, fall back to the clean vertical stack!
        final bool useTwoColumns = constraints.maxWidth > 600;

        final Color appBarIconColor = isDark
            ? Colors.white
            : (_isAppBarCollapsed ? Colors.grey.shade700 : Colors.white);

        return StreamBuilder<DocumentSnapshot>(
          stream: _eventStream, // Replaced inline query
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
            final int keepAliveDays = data['keepAliveDays'] ?? 0;

            String keepAliveLabel = "";
            if (keepAliveDays == 1) {
              keepAliveLabel = "1 Day";
            } else if (keepAliveDays == 7) {
              keepAliveLabel = "1 Week";
            } else if (keepAliveDays > 0) {
              keepAliveLabel = "$keepAliveDays Days";
            }

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
            final List<String> fullWeekDays = [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ];

            final String shortMonth = shortMonths[dt.month - 1];
            final String day = dt.day.toString();
            final String fullWeekDay = fullWeekDays[dt.weekday - 1];

            int hour = dt.hour;
            final String period = hour >= 12 ? "PM" : "AM";
            hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
            final String minute = dt.minute.toString().padLeft(2, '0');
            final String timeString = "$hour:$minute $period";

            final String? details = data['details'] ?? data['description'];
            final bool hasDetails = details != null && details.isNotEmpty;
            final String location = data['location'] ?? "TBD";
            final String hostId = data['hostId'];

            // --- WIDGET 1: VITALS CARD ---
            final vitalsCardWidget = _buildInfoCard(
              title: "The Vitals",
              icon: Icons.push_pin,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 55,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                              ),
                              child: Text(
                                shortMonth,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  fullWeekDay,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                if (keepAliveDays > 0) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      keepAliveLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.tertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isVibeCheck) ...[
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () => _openMap(location),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: isDark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.tertiary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tap for directions",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );

            // --- WIDGET 2: DETAILS CARD ---
            Widget detailsCardWidget = const SizedBox.shrink();
            if (hasDetails || data.containsKey('latestCriticalChange')) {
              detailsCardWidget = _buildInfoCard(
                title: "The Details",
                icon: Icons.notes,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.containsKey('latestCriticalChange')) ...[
                      _buildAlertBanner(context, data),
                      const SizedBox(height: 8),
                    ],
                    if (hasDetails)
                      GestureDetector(
                        onTap: () => _showFullDetails(context, details),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (details.length > 150 || details.contains('\n'))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "Read more",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }

            // --- WIDGET 3: SQUAD NEEDS CARD ---
            final squadNeedsCardWidget = StreamBuilder<QuerySnapshot>(
              stream: _rolesStream, // Replaced inline query
              builder: (context, roleSnap) {
                if (!roleSnap.hasData || roleSnap.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                return _buildInfoCard(
                  title: "Squad Needs",
                  icon: Icons.check_box_outlined,
                  child: InkWell(
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
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pan_tool, color: primaryColor, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              canEdit
                                  ? "Manage items you need help with"
                                  : "See what the captain needs!",
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );

            // --- WIDGET 4: RSVP / VIBE CHECK CARD ---
            final rsvpCardWidget = StreamBuilder<DocumentSnapshot>(
              stream: _myInviteStream, // Replaced inline query
              builder: (context, inviteSnap) {
                Map<String, dynamic> myInviteData = {};
                String myStatus = 'pending';
                if (inviteSnap.hasData && inviteSnap.data!.exists) {
                  myInviteData =
                      inviteSnap.data!.data() as Map<String, dynamic>;
                  myStatus = myInviteData['status'] ?? 'pending';
                }

                if (isVibeCheck) {
                  final isGoing = myStatus == 'going';
                  return _buildInfoCard(
                    title: "Cast Your Vote",
                    icon: Icons.how_to_vote,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isGoing && !isMainHost)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Swipe 'LET'S GO' below to cast your vote!",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        VibeCheckPollUI(
                          eventId: widget.eventId,
                          eventData: data,
                          myInviteData: myInviteData,
                          myUid: currentUser.uid,
                          isHost: isMainHost,
                        ),
                        const SizedBox(height: 24),
                        SwipeRsvpWidget(
                          key: ValueKey(
                            myStatus,
                          ), // FIX 2: Purges phantom state
                          currentStatus: myStatus,
                          onRsvp: _rsvp,
                        ),
                      ],
                    ),
                  );
                }

                return _buildInfoCard(
                  title: "In or Out?",
                  icon: Icons.thumbs_up_down,
                  child: SwipeRsvpWidget(
                    key: ValueKey(myStatus), // FIX 2: Purges phantom state
                    currentStatus: myStatus,
                    onRsvp: _rsvp,
                  ),
                );
              },
            );

            // --- WIDGET 5: THE CREW CARD ---
            final crewCardWidget = StreamBuilder<QuerySnapshot>(
              stream: _crewStream, // Replaced inline query
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final inviteDocs = snapshot.data!.docs;
                if (inviteDocs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text("No invitations found."),
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchAndSortGuests(inviteDocs, dt, rsvpDeadline),
                  builder: (context, sortedSnap) {
                    if (!sortedSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final guests = sortedSnap.data!;

                    return _buildInfoCard(
                      title: "The Crew",
                      icon: Icons.group,
                      trailing: _buildFacepile(guests, currentUser.uid, isDark),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: guests.length,
                        itemBuilder: (context, index) {
                          final guest = guests[index];
                          final String status = guest['status'];
                          final String guestUid = guest['uid'];
                          final String name = guest['displayName'];
                          final String phone = guest['phone'];
                          final String username = guest['username'] ?? "";
                          final int avatarColor = guest['avatarColor'];
                          final String? avatarUrl = guest['avatarUrl'];

                          final bool isEventMainHost =
                              guestUid == data['hostId'];
                          final bool isEventCoHost =
                              guestUid == data['coHostId'];

                          IconData badgeIcon;
                          Color badgeColor;

                          switch (status) {
                            case 'going':
                              badgeIcon = Icons.check_circle;
                              badgeColor = Colors.green;
                              break;
                            case 'declined':
                              badgeIcon = Icons.cancel;
                              badgeColor = Colors.red;
                              break;
                            default:
                              badgeIcon = Icons.hourglass_empty;
                              badgeColor = isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700;
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

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4, // Tighter vertical padding
                                  ),
                                  child: Row(
                                    children: [
                                      // UPDATED: Tighter Stack hugging the avatar with Top-Right badge
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
                                                  ).withValues(alpha: 0.4),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              backgroundColor: Color(
                                                avatarColor,
                                              ),
                                              radius: 22,
                                              backgroundImage: avatarUrl != null
                                                  ? CachedNetworkImageProvider(
                                                      avatarUrl,
                                                    )
                                                  : null,
                                              child: avatarUrl == null
                                                  ? Text(
                                                      name.isNotEmpty
                                                          ? name[0]
                                                                .toUpperCase()
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
                                          // TOP-RIGHT RSVP BADGE
                                          Positioned(
                                            top: -5,
                                            right: -10,
                                            child: Container(
                                              padding: const EdgeInsets.all(
                                                2,
                                              ), // Creates the cutout border
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).cardColor,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                    Symbols.military_tech,
                                                    size: 16,
                                                    color: primaryColor,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (username.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2.0,
                                                ),
                                                child: Text(
                                                  "@$username",
                                                  style: TextStyle(
                                                    color: primaryColor,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
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
                                          tooltip: "Add Friend",
                                          onPressed: () => _addFriend(
                                            context,
                                            guestUid,
                                            phone,
                                            name,
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
              },
            );

            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,

              floatingActionButton: StreamBuilder<DocumentSnapshot>(
                stream: _myInviteStream, // Reused our persistent invite stream!
                builder: (context, inviteSnap) {
                  Timestamp? lastReadTime;
                  if (inviteSnap.hasData && inviteSnap.data!.exists) {
                    final iData =
                        inviteSnap.data!.data() as Map<String, dynamic>;
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
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    stretch: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    foregroundColor: appBarIconColor,
                    actions: [
                      if (canEdit)
                        IconButton(
                          icon: Icon(Icons.edit, color: appBarIconColor),
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
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: themeProvider.appGradient,
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: 20,
                              top: 40,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isVibeCheck)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Symbols.earthquake,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "VIBE CHECK",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  data['title'] ?? "Untitled Event",
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(hostId)
                                      .get(),
                                  builder: (context, hostSnap) {
                                    String hostName = "Someone";
                                    String? hostAvatarUrl;
                                    int hostColor = Colors.grey.toARGB32();

                                    if (hostSnap.hasData &&
                                        hostSnap.data!.exists) {
                                      final hostData =
                                          hostSnap.data!.data()
                                              as Map<String, dynamic>;
                                      hostName =
                                          hostData['displayName'] ?? "Someone";
                                      hostAvatarUrl = hostData['avatarUrl'];
                                      hostColor =
                                          hostData['avatarColor'] ??
                                          Colors.blue.toARGB32();
                                    }

                                    return Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(
                                                  hostColor,
                                                ).withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Color(hostColor),
                                            backgroundImage:
                                                hostAvatarUrl != null
                                                ? CachedNetworkImageProvider(
                                                    hostAvatarUrl,
                                                  )
                                                : null,
                                            child: hostAvatarUrl == null
                                                ? Text(
                                                    hostName[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "$hostName is captain",
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // THE RESPONSIVE CONTENT AREA
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 100),
                      // 👇 FIX: The layout now uses the constraints from LayoutBuilder,
                      // falling back to a perfect single-column stack when needed!
                      child: useTwoColumns
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      vitalsCardWidget,
                                      crewCardWidget,
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      detailsCardWidget,
                                      squadNeedsCardWidget,
                                      rsvpCardWidget,
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                vitalsCardWidget,
                                detailsCardWidget,
                                squadNeedsCardWidget,
                                rsvpCardWidget,
                                crewCardWidget,
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- SWIPE-TO-RSVP WIDGET ---
class SwipeRsvpWidget extends StatefulWidget {
  final String currentStatus;
  final Function(String) onRsvp;

  const SwipeRsvpWidget({
    super.key,
    required this.currentStatus,
    required this.onRsvp,
  });

  @override
  State<SwipeRsvpWidget> createState() => _SwipeRsvpWidgetState();
}

class _SwipeRsvpWidgetState extends State<SwipeRsvpWidget> {
  double _dragPosition = 0.0;
  bool _isDragging = false;

  void _handleDragUpdate(DragUpdateDetails details, double maxDrag) {
    setState(() {
      _isDragging = true;
      _dragPosition += details.delta.dx;

      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
      if (_dragPosition < -maxDrag) _dragPosition = -maxDrag;
    });
  }

  void _handleDragEnd(double maxDrag) {
    setState(() {
      _isDragging = false;
    });

    if (_dragPosition > maxDrag * 0.7) {
      widget.onRsvp('going');
      setState(() => _dragPosition = maxDrag);
    } else if (_dragPosition < -maxDrag * 0.7) {
      widget.onRsvp('declined');
      setState(() => _dragPosition = -maxDrag);
    } else {
      setState(() => _dragPosition = 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant SwipeRsvpWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStatus != oldWidget.currentStatus) {
      _dragPosition = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Status 1: ACCEPTED
    if (widget.currentStatus == 'going') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            // FIX: Expanded prevents overflow and allows text to wrap if needed
            const Expanded(
              child: Text(
                "You're in! 🤗",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => widget.onRsvp('pending'),
              child: const Text(
                "Change",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Status 2: DECLINED
    if (widget.currentStatus == 'declined') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            // FIX: Expanded prevents overflow and allows text to wrap if needed
            const Expanded(
              child: Text(
                "You're missing out.",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => widget.onRsvp('pending'),
              child: const Text(
                "Change",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Status 3: PENDING (Interactive Slider)
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        const double thumbWidth = 100.0;
        final double maxDrag = (trackWidth - thumbWidth) / 2;

        return Container(
          width: trackWidth,
          height: 65,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 24,
                child: Text(
                  "« I'M OUT",
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Positioned(
                right: 24,
                child: Text(
                  "LET'S GO »",
                  style: TextStyle(
                    color: Colors.green.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: (trackWidth / 2) - (thumbWidth / 2) + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _handleDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) => _handleDragEnd(maxDrag),
                  child: Container(
                    width: thumbWidth,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chevron_left,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "SWIPE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
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

    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);
    final inviteRef = eventRef.collection('invitations').doc(myUid);
    final batch = FirebaseFirestore.instance.batch();

    batch.set(inviteRef, {'votes': currentVotes}, SetOptions(merge: true));

    final evSnap = await eventRef.get();
    if (evSnap.exists) {
      final evData = evSnap.data() as Map<String, dynamic>;
      if (evData['type'] == 'vibe_check' &&
          evData['isTieBreakerNeeded'] == true) {
        batch.update(eventRef, {'isTieBreakerNeeded': false});
      }
    }

    await batch.commit();
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
        int maxV = -1;

        if (options.isNotEmpty) {
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
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "It's a tie! Lock in your choice below to finalize the event.",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
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
              final bool isThisOptionTied = showTieBreaker && (count == maxV);

              return GestureDetector(
                onTap: () => _castVote(optId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: iVoted ? primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: percentage > 0 ? percentage : 0.01,
                            heightFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(
                                  alpha: isDark ? 0.3 : 0.15,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              iVoted
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 22,
                              color: iVoted
                                  ? primaryColor
                                  : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 16),

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
                                          : FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (opt['location'] != null &&
                                      opt['location'].toString().isNotEmpty &&
                                      opt['location'] != 'TBD')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
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
                                              size: 12,
                                              color: isDark
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              opt['location'],
                                              style: TextStyle(
                                                fontSize: 13,
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

                            if (isThisOptionTied)
                              InkWell(
                                onTap: () => _lockInTieBreaker(opt),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "LOCK IN",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
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
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
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
