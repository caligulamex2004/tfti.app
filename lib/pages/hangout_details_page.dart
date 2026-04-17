import 'dart:io';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

// --- PAGES ---
import 'chat_page.dart';
import 'hangout_editor_page.dart';
import 'vibe_check_editor_page.dart';

// --- UTILS & COMPONENTS ---
import '../utils/phone_formatter.dart';
import '../utils/theme_provider.dart';
import '../components/details/swipe_rsvp_widget.dart';
import '../components/details/vibe_check_poll_ui.dart';
import '../components/details/vote_tally_sheet.dart';
import '../components/shared/user_profile_sheet.dart';
import '../components/details/details_bottom_sheets.dart';
import '../components/shared/info_card.dart';
import '../components/details/event_vitals_card.dart';
import '../components/details/event_details_card.dart';
import '../components/details/event_squad_needs_card.dart';

class HangoutDetailsPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const HangoutDetailsPage({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<HangoutDetailsPage> createState() => _HangoutDetailsPageState();
}

class _HangoutDetailsPageState extends State<HangoutDetailsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAppBarCollapsed = false;

  late Stream<DocumentSnapshot> _eventStream;
  late Stream<QuerySnapshot> _rolesStream;
  late Stream<DocumentSnapshot> _myInviteStream;
  late Stream<QuerySnapshot> _crewStream;

  Future<List<Map<String, dynamic>>>? _cachedCrewFuture;
  int _lastCrewHash = 0;

  @override
  void initState() {
    super.initState();

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

  // --- LOGIC METHODS ---

  Future<void> _markDetailsAsViewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
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
    Uri url = Platform.isAndroid
        ? Uri.parse("https://www.google.com/maps/search/?api=1&query=$query")
        : Uri.parse("https://maps.apple.com/?q=$query");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _rsvp(String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId);
    final inviteRef = eventRef.collection('invitations').doc(user.uid);

    await inviteRef.set({
      'uid': user.uid,
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final evSnap = await eventRef.get();
    if (evSnap.exists) {
      final evData = evSnap.data() as Map<String, dynamic>;
      if (evData['type'] == 'vibe_check' &&
          evData['isTieBreakerNeeded'] == true) {
        await eventRef.update({'isTieBreakerNeeded': false});
      }
    }

    if (status == 'going') {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.data()?['autoExportCalendar'] == true) {
          _pushToCalendar();
        }
      } catch (e) {
        debugPrint("Error checking calendar preference: $e");
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
    if (user == null) {
      return;
    }

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

  Future<void> _reportUser(String reportedUid, String reportedName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Report User?"),
        content: Text(
          "Flag $reportedName for inappropriate behavior or profile content? Our team will review this.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.redAccent : Colors.red,
            ),
            child: const Text("Report"),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'eventId': widget.eventId,
        'reportedUserUid': reportedUid,
        'reportedByName': reportedName,
        'reportedBy': user.uid,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'user_report',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Report sent. Thank you for keeping TFTI safe.",
            ),
            backgroundColor: isDark ? Colors.green.shade700 : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error sending report.")));
      }
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
      try {
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

        if (!userSnap.exists) {
          return null;
        }
        final userData = userSnap.data() as Map<String, dynamic>;

        return {
          'uid': uid,
          'status': status,
          'hasSeen': hasSeen,
          'displayName': userData['displayName'] ?? 'Unknown',
          'phone':
              (userData['showPhoneNumber'] == true &&
                  (userData['phoneNumber'] ?? userData['phone'] ?? '')
                      .isNotEmpty)
              ? PhoneFormatter.beautify(
                  userData['phoneNumber'] ?? userData['phone'],
                )
              : '',
          'avatarColor': userData['avatarColor'] ?? 0xFF9E9E9E,
          'avatarUrl': userData['avatarUrl'],
          'username': userData['username'] ?? '',
          'statusText': userData['statusText'] ?? '',
          'votes': inviteData['votes'] ?? [],
          'hp': userData['hp'] ?? 0,
          'mana': userData['mana'] ?? 0,
          'createdAt': userData['createdAt'] ?? userData['created_at'],
        };
      } catch (e) {
        return null;
      }
    });

    final results = await Future.wait(futures);
    final validGuests = results
        .where((guest) => guest != null)
        .cast<Map<String, dynamic>>()
        .toList();

    validGuests.sort((a, b) {
      final Map<String, int> statusWeight = {
        'going': 0,
        'declined': 1,
        'pending': 2,
      };
      int weightA = statusWeight[a['status']] ?? 3;
      int weightB = statusWeight[b['status']] ?? 3;

      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      return (a['displayName'] as String).toLowerCase().compareTo(
        (b['displayName'] as String).toLowerCase(),
      );
    });

    return validGuests;
  }

  void _pushToCalendar() {
    final data = widget.eventData;
    final Timestamp? ts = data['time'];
    if (ts == null) {
      return;
    }

    final DateTime startTime = ts.toDate();
    final DateTime endTime = startTime.add(const Duration(hours: 2));

    Add2Calendar.addEvent2Cal(
      Event(
        title: data['title'] ?? 'Squad Hangout',
        description: data['details'] ?? 'Added via tfti.app',
        location: data['location'] ?? '',
        startDate: startTime,
        endDate: endTime,
        iosParams: const IOSParams(reminder: Duration(minutes: 60)),
      ),
    );
  }

  // --- BUILD METHDOD ---

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const SizedBox();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return StreamBuilder<DocumentSnapshot>(
      stream: _eventStream,
      builder: (context, eventSnapshot) {
        var data = widget.eventData;
        if (eventSnapshot.hasData && eventSnapshot.data!.data() != null) {
          data = eventSnapshot.data!.data() as Map<String, dynamic>;
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: _myInviteStream,
          builder: (context, inviteSnap) {
            Map<String, dynamic> myInviteData = {};
            String myStatus = 'pending';
            if (inviteSnap.hasData && inviteSnap.data!.exists) {
              myInviteData = inviteSnap.data!.data() as Map<String, dynamic>;
              myStatus = myInviteData['status'] ?? 'pending';
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _rolesStream,
              builder: (context, roleSnap) {
                final rolesDocs = roleSnap.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot>(
                  stream: _crewStream,
                  builder: (context, crewSnap) {
                    final inviteDocs = crewSnap.data?.docs ?? [];

                    final bool isVibeCheck = data['type'] == 'vibe_check';
                    final bool isImportantDetails =
                        data['isImportantDetails'] == true;
                    final bool isMainHost = data['hostId'] == currentUser.uid;
                    final bool isCoHost = data['coHostId'] == currentUser.uid;
                    final bool canEdit = isMainHost || isCoHost;

                    final Timestamp ts = data['time'];
                    final DateTime dt = ts.toDate();
                    final int rsvpDeadline = data['rsvpDeadline'] ?? 0;
                    final int keepAliveDays = data['keepAliveDays'] ?? 0;

                    final Timestamp? endTs = data['endTime'];
                    DateTime endTime;
                    if (endTs != null) {
                      endTime = endTs.toDate();
                    } else {
                      final int durationMinutes = keepAliveDays > 0
                          ? (keepAliveDays * 24 * 60)
                          : 240;
                      endTime = dt.add(Duration(minutes: durationMinutes));
                    }
                    final bool isPast =
                        (data['isPast'] == true) ||
                        DateTime.now().isAfter(endTime);

                    int currentHash = inviteDocs.length;
                    for (var doc in inviteDocs) {
                      final d = doc.data() as Map<String, dynamic>;
                      currentHash ^=
                          doc.id.hashCode ^
                          (d['status']?.hashCode ?? 0) ^
                          (d['respondedAt']?.hashCode ?? 0) ^
                          (d['lastViewedAt']?.hashCode ?? 0);
                    }

                    if (_cachedCrewFuture == null ||
                        currentHash != _lastCrewHash) {
                      _lastCrewHash = currentHash;
                      _cachedCrewFuture = _fetchAndSortGuests(
                        inviteDocs,
                        dt,
                        rsvpDeadline,
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final bool useTwoColumns =
                            isLandscape || constraints.maxWidth > 600;
                        final Color appBarIconColor = isDark
                            ? Colors.white
                            : (_isAppBarCollapsed
                                  ? Colors.grey.shade700
                                  : Colors.white);
                        final String location = data['location'] ?? 'TBD';

                        // --- THE VITALS CARD ---
                        final vitalsCardWidget = EventVitalsCard(
                          eventTime: dt,
                          keepAliveDays: keepAliveDays,
                          location: location,
                          isVibeCheck: isVibeCheck,
                          onCalendarTap: _pushToCalendar,
                          onMapTap: () => _openMap(location),
                        );

                        // --- THE DETAILS CARD ---
                        final detailsCardWidget = EventDetailsCard(
                          details: data['details'] ?? data['description'],
                          latestCriticalChange: data['latestCriticalChange'],
                        );

                        // --- THE SQUAD NEEDS CARD ---
                        final squadNeedsCardWidget = EventSquadNeedsCard(
                          hasRoles: rolesDocs.isNotEmpty,
                          canEdit: canEdit,
                          eventId: widget.eventId,
                          hostId: data['hostId'],
                          isPast: isPast,
                        );

                        Widget rsvpCardWidget;
                        if (isVibeCheck) {
                          rsvpCardWidget = InfoCard(
                            title: "Cast Your Vote",
                            icon: Icons.how_to_vote,
                            onIconTap: () async {
                              if (_cachedCrewFuture != null) {
                                final guests = await _cachedCrewFuture!;
                                if (context.mounted) {
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
                                    builder: (ctx) => VoteTallySheet(
                                      options: data['pollOptions'] ?? [],
                                      guests: guests,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (myStatus != 'going' && !isMainHost)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.withValues(
                                          alpha: 0.5,
                                        ),
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
                                  isLocked: isPast,
                                ),
                                const SizedBox(height: 24),
                                SwipeRsvpWidget(
                                  key: ValueKey(myStatus),
                                  currentStatus: myStatus,
                                  isLocked: isPast,
                                  onRsvp: _rsvp,
                                ),
                              ],
                            ),
                          );
                        } else {
                          rsvpCardWidget = InfoCard(
                            title: "In or Out?",
                            icon: Icons.thumbs_up_down,
                            child: SwipeRsvpWidget(
                              key: ValueKey(myStatus),
                              currentStatus: myStatus,
                              isLocked: isPast,
                              onRsvp: _rsvp,
                            ),
                          );
                        }

                        Widget crewCardWidget;
                        if (inviteDocs.isEmpty) {
                          crewCardWidget = const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text("No invitations found."),
                          );
                        } else {
                          crewCardWidget = FutureBuilder<List<Map<String, dynamic>>>(
                            future: _cachedCrewFuture,
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
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final guests = sortedSnap.data!;
                              final seenGuests = guests
                                  .where(
                                    (g) =>
                                        g['hasSeen'] == true &&
                                        g['uid'] != currentUser.uid,
                                  )
                                  .toList();

                              return InfoCard(
                                title: "The Crew",
                                icon: Icons.group,
                                onIconTap: seenGuests.isNotEmpty
                                    ? () {
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
                                          builder: (ctx) => SeenBySheet(
                                            seenGuests: seenGuests,
                                          ),
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
                                          .doc(currentUser.uid)
                                          .collection('friends')
                                          .doc(guestUid)
                                          .snapshots(),
                                      builder: (context, friendSnap) {
                                        bool showAddButton =
                                            (guestUid != currentUser.uid) &&
                                            !(friendSnap.hasData &&
                                                friendSnap.data!.exists);
                                        bool isGoated =
                                            friendSnap.hasData &&
                                                friendSnap.data!.exists
                                            ? (friendSnap.data!.data()
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)['isGoated'] ==
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
                                              shape:
                                                  const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            24,
                                                          ),
                                                        ),
                                                  ),
                                              builder: (ctx) =>
                                                  UserProfileSheet(
                                                    userData: guest,
                                                    showAddButton:
                                                        showAddButton,
                                                    isGoated: isGoated,
                                                    currentUserId:
                                                        currentUser.uid,
                                                    onAddFriend:
                                                        (uid, phone, name) =>
                                                            _addFriend(
                                                              context,
                                                              uid,
                                                              phone,
                                                              name,
                                                            ),
                                                    onReportUser: (uid, name) =>
                                                        _reportUser(uid, name),
                                                  ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                            color:
                                                                Color(
                                                                  guest['avatarColor'],
                                                                ).withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                            blurRadius: 8,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                      ),
                                                      child: CircleAvatar(
                                                        backgroundColor: Color(
                                                          guest['avatarColor'],
                                                        ),
                                                        radius: 22,
                                                        backgroundImage:
                                                            guest['avatarUrl'] !=
                                                                null
                                                            ? CachedNetworkImageProvider(
                                                                guest['avatarUrl'],
                                                              )
                                                            : null,
                                                        child:
                                                            guest['avatarUrl'] ==
                                                                null
                                                            ? Text(
                                                                guest['displayName'][0]
                                                                    .toUpperCase(),
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                            : null,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: -5,
                                                      right: -10,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              2,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Theme.of(
                                                                context,
                                                              ).cardColor,
                                                              shape: BoxShape
                                                                  .circle,
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              guest['displayName'],
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          if (guestUid ==
                                                              data['hostId'])
                                                            const Padding(
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    left: 6,
                                                                  ),
                                                              child: Icon(
                                                                Symbols.crown,
                                                                size: 18,
                                                                color: Colors
                                                                    .amber,
                                                              ),
                                                            ),
                                                          if (guestUid ==
                                                              data['coHostId'])
                                                            const Padding(
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    left: 6,
                                                                  ),
                                                              child: Icon(
                                                                Symbols
                                                                    .military_tech,
                                                                size: 16,
                                                                color: Colors
                                                                    .amber,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      if ((guest['username'] ??
                                                              "")
                                                          .isNotEmpty)
                                                        Text(
                                                          "@${guest['username']}",
                                                          style: TextStyle(
                                                            color: primaryColor,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
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
                                                    onPressed: () => _addFriend(
                                                      context,
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

                        Timestamp? lastReadTime = myInviteData['lastReadChat'];
                        bool hasUnread = false;
                        bool wasMentioned = false;
                        if (data['lastMessageAt'] != null) {
                          if (lastReadTime == null ||
                              (data['lastMessageAt'] as Timestamp).seconds >
                                  lastReadTime.seconds) {
                            hasUnread = true;
                            if ((data['lastMessageMentions'] ?? []).contains(
                              currentUser.uid,
                            )) {
                              wasMentioned = true;
                            }
                          }
                        }

                        final bool hasBanner =
                            data['bannerUrl'] != null &&
                            data['bannerUrl'].toString().isNotEmpty;

                        return Scaffold(
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          floatingActionButton: Badge(
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
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    eventId: widget.eventId,
                                    eventTitle: data['title'] ?? "Chat",
                                  ),
                                ),
                              ),
                              backgroundColor: primaryColor,
                              foregroundColor: themeProvider.onPrimaryColor,
                              elevation: 4,
                              shape: const CircleBorder(),
                              heroTag: "btn_chat_details",
                              child: const Icon(Icons.chat),
                            ),
                          ),
                          body: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              SliverAppBar(
                                expandedHeight: hasBanner
                                    ? (isLandscape
                                          ? 220.0
                                          : MediaQuery.of(context).size.height *
                                                0.55)
                                    : (isLandscape ? 180.0 : 240.0),
                                pinned: true,
                                stretch: true,
                                backgroundColor: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                foregroundColor: appBarIconColor,
                                actions: [
                                  if (canEdit)
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: appBarIconColor,
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => isVibeCheck
                                              ? VibeCheckEditorPage(
                                                  eventId: widget.eventId,
                                                  eventData: data,
                                                )
                                              : HangoutEditorPage(
                                                  eventId: widget.eventId,
                                                  eventData: data,
                                                ),
                                        ),
                                      ),
                                    ),
                                ],
                                flexibleSpace: FlexibleSpaceBar(
                                  stretchModes: const [
                                    StretchMode.zoomBackground,
                                  ],
                                  background: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: themeProvider.appGradient,
                                        ),
                                      ),
                                      if (hasBanner) ...[
                                        CachedNetworkImage(
                                          imageUrl: data['bannerUrl'],
                                          fit: BoxFit.cover,
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      SafeArea(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 20,
                                            right: 20,
                                            bottom: 40,
                                            top: 40,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (isImportantDetails)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                        ),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.priority_high,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            "READ DETAILS",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              letterSpacing:
                                                                  1.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (isVibeCheck)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
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
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              letterSpacing:
                                                                  1.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Text(
                                                data['title'] ??
                                                    "Untitled Event",
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
                                                future: FirebaseFirestore
                                                    .instance
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
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  return Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 12,
                                                        backgroundColor: Color(
                                                          hostData['avatarColor'] ??
                                                              Colors.blue
                                                                  .toARGB32(),
                                                        ),
                                                        backgroundImage:
                                                            hostData['avatarUrl'] !=
                                                                null
                                                            ? CachedNetworkImageProvider(
                                                                hostData['avatarUrl'],
                                                              )
                                                            : null,
                                                        child:
                                                            hostData['avatarUrl'] ==
                                                                null
                                                            ? Text(
                                                                (hostData['displayName'] ??
                                                                        "S")[0]
                                                                    .toUpperCase(),
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              )
                                                            : null,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        "${hostData['displayName'] ?? 'Someone'} is captain",
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.9,
                                                              ),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
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
                                    ],
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 24,
                                    bottom: 100,
                                  ),
                                  child: useTwoColumns
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
              },
            );
          },
        );
      },
    );
  }
}
