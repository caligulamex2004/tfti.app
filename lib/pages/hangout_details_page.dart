import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// --- PAGES ---
import 'chat_page.dart';
import 'hangout_editor_page.dart';
import 'vibe_check_editor_page.dart';

// --- UTILS & COMPONENTS ---
import '../utils/calendar_export_helper.dart';
import '../utils/event_service.dart';
import '../utils/theme_provider.dart';
import '../utils/responsive_layout.dart';
import '../components/details/event_crew_card.dart';
import '../components/details/event_details_card.dart';
import '../components/details/event_rsvp_card.dart';
import '../components/details/event_squad_needs_card.dart';
import '../components/details/event_vitals_card.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import '../components/shared/app_avatar.dart';
import '../components/shared/app_banner_image.dart';
import '../components/feed/empty_feed_states.dart';
import '../components/shared/user_profile_sheet.dart';
import '../components/shared/event_type_pill.dart';
import '../services/contact_resolver.dart';
import '../services/badge_service.dart';

class HangoutDetailsPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;
  final VoidCallback? onDeleted;

  const HangoutDetailsPage({
    super.key,
    required this.eventId,
    required this.eventData,
    this.onDeleted,
  });

  @override
  State<HangoutDetailsPage> createState() => _HangoutDetailsPageState();
}

class _HangoutDetailsPageState extends State<HangoutDetailsPage> {
  final ScrollController _scrollController = ScrollController();

  late Stream<DocumentSnapshot> _eventStream;
  late Stream<QuerySnapshot> _rolesStream;
  late Stream<DocumentSnapshot> _myInviteStream;
  late Stream<QuerySnapshot> _crewStream;

  Future<List<Map<String, dynamic>>>? _cachedCrewFuture;
  int _lastCrewHash = 0;

  @override
  void initState() {
    super.initState();
    BadgeService.instance.clearBadge();

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
            if (guestPhone.isNotEmpty) 'phoneNumber': guestPhone,
            'addedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await EventService.syncActiveEventsForUser(user.uid);

      if (mounted) {
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
              "Report sent. Thank you for keeping tfti safe.",
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
          'phoneNumber': userData['phoneNumber'] ?? '',
          'showPhoneNumber':
              (userData['showPhoneNumber'] ?? userData['isPhonePublic']) !=
              false,
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
      final nameA = (ContactResolver.instance.resolveMiniProfileName(a['phoneNumber'], fallbackName: a['displayName']) ??
              a['displayName'] ??
              '')
          .toString()
          .toLowerCase();
      final nameB = (ContactResolver.instance.resolveMiniProfileName(b['phoneNumber'], fallbackName: b['displayName']) ??
              b['displayName'] ??
              '')
          .toString()
          .toLowerCase();
      return nameA.compareTo(nameB);
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

    if (kIsWeb) {
      final gCalUrl = CalendarExportHelper.buildGoogleCalendarUrl(
        title: data['title'] ?? 'Squad Hangout',
        details: data['details'] ?? 'Added via tfti.app',
        location: data['location'] ?? '',
        startTime: startTime,
        endTime: endTime,
      );
      launchUrl(gCalUrl, mode: LaunchMode.externalApplication);
      return;
    }

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

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const SizedBox();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = context.isWideScreen;

    return StreamBuilder<DocumentSnapshot>(
      stream: _eventStream,
      builder: (context, eventSnapshot) {
        if (eventSnapshot.hasData &&
            (!eventSnapshot.data!.exists ||
                eventSnapshot.data!.data() == null)) {
          widget.onDeleted?.call();
          if (isLandscape) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const FeedDetailPlaceholder(),
            );
          }

          // On mobile / portrait: only pop if this page is the current active route.
          // If an editor (e.g. HangoutEditorPage) is active on top, do NOT pop here
          // as the editor's deleteEventWithConfirmation will popUntil root.
          final route = ModalRoute.of(context);
          if (route != null && route.isCurrent) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            });
          }
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const SizedBox.shrink(),
          );
        }

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
                          (d['lastViewedAt']?.hashCode ?? 0) ^
                          (d['votes']?.toString().hashCode ?? 0);
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
                            constraints.maxWidth >= 700;
                        final String location = data['location'] ?? 'TBD';

                        final vitalsCardWidget = EventVitalsCard(
                          eventTime: dt,
                          keepAliveDays: keepAliveDays,
                          location: location,
                          isVibeCheck: isVibeCheck,
                          margin: useTwoColumns
                              ? const EdgeInsets.only(
                                  bottom: 24,
                                  left: 20,
                                  right: 10,
                                )
                              : null,
                          onCalendarTap: _pushToCalendar,
                          onMapTap: () => _openMap(location),
                        );

                        final detailsCardWidget = EventDetailsCard(
                          eventData: data,
                        );

                        final squadNeedsCardWidget = EventSquadNeedsCard(
                          hasRoles: rolesDocs.isNotEmpty,
                          canEdit: canEdit,
                          eventId: widget.eventId,
                          hostId: data['hostId'],
                          isPast: isPast,
                        );

                        final rsvpCardWidget = EventRsvpCard(
                          isVibeCheck: isVibeCheck,
                          eventId: widget.eventId,
                          eventData: data,
                          myInviteData: myInviteData,
                          myStatus: myStatus,
                          myUid: currentUser.uid,
                          isMainHost: isMainHost,
                          isPast: isPast,
                          margin: useTwoColumns
                              ? const EdgeInsets.only(
                                  bottom: 24,
                                  left: 10,
                                  right: 20,
                                )
                              : null,
                          cachedCrewFuture: _cachedCrewFuture,
                          onRsvp: _rsvp,
                        );

                        final crewCardWidget = EventCrewCard(
                          eventId: widget.eventId,
                          inviteDocsEmpty: inviteDocs.isEmpty,
                          cachedCrewFuture: _cachedCrewFuture,
                          currentUserId: currentUser.uid,
                          hostId: data['hostId'],
                          coHostId: data['coHostId'],
                          invitedCircles: List<String>.from(
                            data['invitedCircles'] ?? [],
                          ),
                          inviteAll: data['inviteAll'] ?? true,
                          lastMinuteInvites: List<String>.from(
                            data['lastMinuteInvites'] ?? [],
                          ),
                          coHostInvitedCircles:
                              data['coHostInvitedCircles'] != null
                                  ? List<String>.from(
                                      data['coHostInvitedCircles'],
                                    )
                                  : null,
                          coHostInviteAll: data['coHostInviteAll'] ?? false,
                          coHostLastMinuteInvites:
                              data['coHostLastMinuteInvites'] != null
                                  ? List<String>.from(
                                      data['coHostLastMinuteInvites'],
                                    )
                                  : null,
                          isPast: isPast,
                          onEditTeamsTap: canEdit
                              ? () => Navigator.push(
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
                                )
                              : null,
                          onAddFriend: _addFriend,
                          onReportUser: _reportUser,
                        );

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
                                    eventTitle: (data['title'] != null &&
                                            data['title']
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                        ? data['title'].toString().trim()
                                        : (isVibeCheck
                                            ? "Vibe Check Chat"
                                            : "Chat"),
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
                              SharedSliverAppBar(
                                title: (data['title'] != null &&
                                        data['title']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                    ? data['title'].toString().trim()
                                    : (isVibeCheck
                                        ? "Untitled Vibe Check"
                                        : "Untitled Event"),
                                collapsedTitle: (data['title'] != null &&
                                        data['title']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                    ? data['title'].toString().trim()
                                    : (isVibeCheck
                                        ? "Untitled Vibe Check"
                                        : "Untitled Event"),
                                expandedTitleColor: hasBanner
                                    ? Colors.white
                                    : (isDark ? Colors.white : Colors.black87),
                                expandedIconColor: hasBanner
                                    ? Colors.white
                                    : null,
                                expandedHeight: hasBanner
                                    ? (isLandscape
                                          ? 220.0
                                          : MediaQuery.sizeOf(context).height *
                                                0.55)
                                    : (isLandscape ? 180.0 : 240.0),
                                actions: [
                                  if (canEdit)
                                    IconButton(
                                      icon: const Icon(Icons.edit),
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
                                background: hasBanner
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          AppBannerImage(
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
                                      )
                                    : null,
                                topBadges: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (isImportantDetails)
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red
                                              .withValues(alpha: 0.8),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
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
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    EventTypePill(
                                      isVibeCheck: isVibeCheck,
                                      fontSize: 10,
                                      iconSize: 14,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      borderRadius: 20,
                                    ),
                                  ],
                                ),
                                bottomContent: FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(data['hostId'])
                                      .get(),
                                  builder: (context, hostSnap) {
                                    if (!hostSnap.hasData ||
                                        !hostSnap.data!.exists) {
                                      return const SizedBox.shrink();
                                    }
                                    final hostData = hostSnap.data!.data()
                                        as Map<String, dynamic>;
                                    final hostPhone =
                                        (hostData['phoneNumber'] ?? '')
                                            .toString();
                                    final bool isHostMe =
                                        data['hostId'] == currentUser.uid;
                                    final contactName = isHostMe
                                        ? null
                                        : ContactResolver.instance
                                            .resolveName(hostPhone);
                                    final bool hasContact = contactName !=
                                            null &&
                                        contactName.trim().isNotEmpty;
                                    final fallbackHost =
                                        (hostData['displayName'] ?? 'Someone')
                                            .toString();
                                    final String hostDisplayName = isHostMe
                                        ? ContactResolver.instance
                                            .formatMiniProfileFallback(
                                            fallbackHost,
                                          )
                                        : (ContactResolver.instance
                                                .resolveMiniProfileName(
                                              hostPhone,
                                              fallbackName: fallbackHost,
                                            ) ??
                                            ContactResolver.instance
                                                .formatMiniProfileFallback(
                                              fallbackHost,
                                            ));

                                    return GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        final hostMap =
                                            Map<String, dynamic>.from(hostData);
                                        hostMap['uid'] = data['hostId'];
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(24),
                                            ),
                                          ),
                                          builder: (ctx) => UserProfileSheet(
                                            userData: hostMap,
                                            currentUserId: currentUser.uid,
                                            showAddButton: data['hostId'] !=
                                                currentUser.uid,
                                            onAddFriend: _addFriend,
                                            onReportUser: _reportUser,
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AppAvatar.fromColorValue(
                                            radius: 12,
                                            avatarColor:
                                                hostData['avatarColor'],
                                            avatarUrl: hostData['avatarUrl'],
                                            displayName: hostDisplayName,
                                            fontSize: 10,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Led by $hostDisplayName",
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (hasContact) ...[
                                            const SizedBox(width: 4),
                                            Tooltip(
                                              message: "From your contacts",
                                              child: Icon(
                                                Icons.contact_phone_outlined,
                                                size: 13,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 24,
                                    bottom: 100,
                                  ),
                                  child: useTwoColumns
                                      ? Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 1000,
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: vitalsCardWidget,
                                                    ),
                                                    Expanded(
                                                      child: rsvpCardWidget,
                                                    ),
                                                  ],
                                                ),
                                                detailsCardWidget,
                                                crewCardWidget,
                                                squadNeedsCardWidget,
                                              ],
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            vitalsCardWidget,
                                            crewCardWidget,
                                            squadNeedsCardWidget,
                                            detailsCardWidget,
                                            rsvpCardWidget,
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
