import 'dart:io';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

// --- PAGES ---
import 'hangout_editor_page.dart';
import 'vibe_check_editor_page.dart';
import 'hangout_chat_page.dart';

// --- UTILS & COMPONENTS ---
import '../utils/phone_formatter.dart';
import '../utils/theme_provider.dart';
import '../components/forms/squad_needs_sheet.dart';
import '../components/details/swipe_rsvp_widget.dart';
import '../components/details/vibe_check_poll_ui.dart';
import '../components/details/guest_profile_sheet.dart';
import '../components/details/vote_tally_sheet.dart';

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
          setState(() => _isAppBarCollapsed = isCollapsed);
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
    Uri url = Platform.isAndroid
        ? Uri.parse("https://www.google.com/maps/search/?api=1&query=$query")
        : Uri.parse("https://maps.apple.com/?q=$query");

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
        if (userDoc.data()?['autoExportCalendar'] == true) _pushToCalendar();
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

  Future<void> _reportUser(String reportedUid, String reportedName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
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

    if (confirm != true) return;

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

        if (!userSnap.exists) return null;
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

      if (weightA != weightB) return weightA.compareTo(weightB);
      return (a['displayName'] as String).toLowerCase().compareTo(
        (b['displayName'] as String).toLowerCase(),
      );
    });

    return validGuests;
  }

  void _pushToCalendar() {
    final data = widget.eventData;
    final Timestamp? ts = data['time'];
    if (ts == null) return;

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

  // --- UI HELPERS ---

  Widget _buildAlertBanner(BuildContext context, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final change = data['latestCriticalChange'] as Map<String, dynamic>?;
    if (change == null) return const SizedBox.shrink();

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
                  "HEADS UP: ${change['field'] ?? 'Details'} Changed!",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Was: ${change['original'] ?? ''}\nNow: ${change['new'] ?? ''}",
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

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    VoidCallback? onIconTap,
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
                Material(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onIconTap,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(icon, color: primaryColor, size: 20),
                    ),
                  ),
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

  List<TextSpan> _buildLinkedTextSpans(
    String text,
    bool isDark,
    Color primaryColor,
  ) {
    final List<TextSpan> spans = [];
    final RegExp urlRegExp = RegExp(
      r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
      caseSensitive: false,
    );
    final matches = urlRegExp.allMatches(text);
    int previousEnd = 0;

    for (final match in matches) {
      if (match.start > previousEnd) {
        spans.add(
          TextSpan(
            text: text.substring(previousEnd, match.start),
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.black87,
              height: 1.5,
            ),
          ),
        );
      }
      final String url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            height: 1.5,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              HapticFeedback.lightImpact();
              String launchUrlString = url;
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                launchUrlString = 'https://$url';
              }
              final Uri uri = Uri.parse(launchUrlString);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      previousEnd = match.end;
    }
    if (previousEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(previousEnd),
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.black87,
            height: 1.5,
          ),
        ),
      );
    }
    return spans;
  }

  // --- SIMPLE BOTTOM SHEETS ---

  void _showFullDetails(BuildContext context, String details) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
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
                  child: SelectableText.rich(
                    TextSpan(
                      children: _buildLinkedTextSpans(
                        details,
                        isDark,
                        primaryColor,
                      ),
                    ),
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
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
                    final String username = guest['username'] ?? "";
                    final String? avatarUrl = guest['avatarUrl'];
                    final int avatarColor =
                        guest['avatarColor'] ?? Colors.blue.toARGB32();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
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
                          radius: 20,
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
      ),
    );
  }

  // --- BUILD METHDOD ---

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

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

                        final vitalsCardWidget = _buildInfoCard(
                          title: "The Vitals",
                          icon: Icons.calendar_month,
                          onIconTap: _pushToCalendar,
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
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            [
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
                                            ][dt.month - 1],
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
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            dt.day.toString(),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 10,
                                          runSpacing: 6,
                                          children: [
                                            Text(
                                              [
                                                'Monday',
                                                'Tuesday',
                                                'Wednesday',
                                                'Thursday',
                                                'Friday',
                                                'Saturday',
                                                'Sunday',
                                              ][dt.weekday - 1],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            if (keepAliveDays > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .tertiary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  keepAliveDays == 1
                                                      ? "1 Day"
                                                      : (keepAliveDays == 7
                                                            ? "1 Week"
                                                            : "$keepAliveDays Days"),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.tertiary,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? "PM" : "AM"}",
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.tertiary,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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

                        final String? details =
                            data['details'] ?? data['description'];
                        Widget detailsCardWidget = const SizedBox.shrink();
                        if ((details != null && details.isNotEmpty) ||
                            data.containsKey('latestCriticalChange')) {
                          detailsCardWidget = _buildInfoCard(
                            title: "The Details",
                            icon: Icons.notes,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data.containsKey(
                                  'latestCriticalChange',
                                )) ...[
                                  _buildAlertBanner(context, data),
                                  const SizedBox(height: 8),
                                ],
                                if (details != null && details.isNotEmpty)
                                  GestureDetector(
                                    onTap: () =>
                                        _showFullDetails(context, details),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        if (details.length > 150 ||
                                            details.contains('\n'))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
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

                        Widget squadNeedsCardWidget = const SizedBox.shrink();
                        if (rolesDocs.isNotEmpty) {
                          squadNeedsCardWidget = _buildInfoCard(
                            title: "Squad Needs",
                            icon: Icons.check_box_outlined,
                            child: InkWell(
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
                                  builder: (ctx) => SquadNeedsSheet(
                                    eventId: widget.eventId,
                                    hostId: data['hostId'],
                                    isPast: isPast,
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
                                    Icon(
                                      Icons.pan_tool,
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        canEdit
                                            ? "Manage items you need help with"
                                            : "See what the captain needs!",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
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
                        }

                        Widget rsvpCardWidget;
                        if (isVibeCheck) {
                          rsvpCardWidget = _buildInfoCard(
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
                          rsvpCardWidget = _buildInfoCard(
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

                              return _buildInfoCard(
                                title: "The Crew",
                                icon: Icons.group,
                                onIconTap: seenGuests.isNotEmpty
                                    ? () => _showSeenByBottomSheet(seenGuests)
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
                                                  GuestProfileSheet(
                                                    guest: guest,
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
                                  builder: (context) => EventChatPage(
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
                                              if (isVibeCheck)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.3),
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
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 1.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
