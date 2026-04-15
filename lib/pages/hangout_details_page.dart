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

import 'hangout_editor_page.dart';
import 'vibe_check_editor_page.dart';
import 'hangout_chat_page.dart';
import '../utils/phone_formatter.dart';
import '../utils/theme_provider.dart';

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

  // Cache variables to prevent infinite loading loops
  Future<List<Map<String, dynamic>>>? _cachedCrewFuture;
  int _lastCrewHash = 0;

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
      'uid': user.uid,
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
    // Check prefs before pushing to calendar - only for "going" since "maybe" or "decline" shouldn't trigger it
    if (status == 'going') {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        // Defaults to false if the field doesn't exist yet!
        final bool autoExport = userDoc.data()?['autoExportCalendar'] ?? false;

        if (autoExport) {
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
      // Wrap individual fetches in a try/catch
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

        final bool showPhone = userData['showPhoneNumber'] ?? false;
        String rawPhone = userData['phoneNumber'] ?? userData['phone'] ?? '';
        String securePhone = '';

        if (showPhone && rawPhone.isNotEmpty) {
          securePhone = PhoneFormatter.beautify(rawPhone);
        }

        return {
          'uid': uid,
          'status': status,
          'hasSeen': hasSeen,
          'displayName': userData['displayName'] ?? 'Unknown',
          'phone': securePhone,
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
        debugPrint("Guest fetch failed, skipping... $e");
        return null; // Fails gracefully!
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

      // Group by status first
      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }

      // Then alphabetize within that specific group
      final nameA = (a['displayName'] as String).toLowerCase();
      final nameB = (b['displayName'] as String).toLowerCase();
      return nameA.compareTo(nameB);
    });

    return validGuests;
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
                          vertical: 4,
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
                        // Display @username as subtitle if they have one
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

  void _showGuestProfileSheet(
    Map<String, dynamic> guest,
    bool showAddButton, {
    bool isGoated = false,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final String displayName = guest['displayName'] ?? "No Name";
    final String username = guest['username'] ?? "";
    final String phone = guest['phone'] ?? "";
    final bool showPhone = phone.isNotEmpty;
    final String statusText = guest['statusText'] ?? "";

    final String? avatarUrl = guest['avatarUrl'];
    Color avatarColor = Colors.blue.shade100;
    if (guest['avatarColor'] is int) {
      avatarColor = Color(guest['avatarColor']);
    }

    // --- Extract RPG Stats & Origin Date ---
    final int hp = guest['hp'] ?? 0;
    final int mana = guest['mana'] ?? 0;
    final Timestamp? createdAt = guest['createdAt'];

    String originDate = "";
    if (createdAt != null) {
      final DateTime dt = createdAt.toDate();
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
      originDate = "Joined ${months[dt.month - 1]} ${dt.year}";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isLandscape =
            MediaQuery.of(ctx).orientation == Orientation.landscape;

        // --- TCG STYLE DECORATIONS ---
        // Creates the "Card Text Box" feel (semi-transparent tinted glass)
        final plateDecoration = BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        );

        // Helper widget for drawing the RPG Bars
        Widget buildStatBar(
          String label,
          int totalValue,
          Color color,
          IconData icon,
        ) {
          int level = (totalValue ~/ 100) + 1;
          int progress = totalValue % 100;
          double percentage = progress / 100.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Lvl. $level",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 10,
                  backgroundColor: isDark ? Colors.black38 : Colors.white60,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.center,
                child: Text(
                  "$progress / 100",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          );
        }

        // --- REUSABLE TCG CARD COMPONENTS ---

        // 1. The Title Plate
        Widget titleWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: plateDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      if (username.isNotEmpty)
                        TextSpan(
                          text: "@$username, ",
                          style: TextStyle(
                            fontSize: isLandscape ? 15 : 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      TextSpan(
                        text: displayName,
                        style: TextStyle(
                          fontSize: isLandscape ? 20 : 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isGoated) ...[
                const SizedBox(width: 8),
                const Text("🐐", style: TextStyle(fontSize: 22)),
              ],
            ],
          ),
        );

        // 2. The Card Art
        Widget avatarWidget = Container(
          width: isLandscape ? 120 : 160,
          height: isLandscape ? 120 : 160,
          decoration: BoxDecoration(
            color: avatarColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 3,
            ),
            image: avatarUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null
              ? Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 60,
                    ),
                  ),
                )
              : null,
        );

        // 3. The Power Level Badge (Pill)
        Widget hpManaPill = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            "🔥 $hp / $mana 💧",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900, // Extra bold for impact
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        );

        // 4. The Flavor Text Plate
        Widget statusWidget = Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            top: 24.0,
          ), // Extra top margin to clear the overlapping pill
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: plateDecoration,
          child: Text(
            '"$statusText"',
            textAlign: TextAlign.center, // Centered looks great inside a plate
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.3,
            ),
          ),
        );

        // 5. The Footer Plate
        Widget metaWidget = Row(
          children: [
            // LEFT ALIGNED: Joined Date
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: originDate.isNotEmpty
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          originDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // RIGHT ALIGNED: Phone Number
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: showPhone
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_iphone,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );

        // STACK: Combines Card Art + Overlapping Power Level Badge
        Widget metaWithBadgeStack = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            metaWidget,
            Positioned(
              bottom:
                  -46, // Pulls the pill down so it straddles the bottom border!
              child: hpManaPill,
            ),
          ],
        );

        // --- ASSEMBLE THE TCG CARD BASED ON ORIENTATION ---
        Widget tcgCard;
        if (isLandscape) {
          tcgCard = Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: avatarColor.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          avatarWidget,
                          if (statusText.isNotEmpty) statusWidget,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildStatBar(
                            "HP (Hangouts)",
                            hp,
                            Colors.redAccent,
                            Icons.whatshot,
                          ),
                          const SizedBox(height: 12),
                          buildStatBar(
                            "Mana (Invites)",
                            mana,
                            Colors.blueAccent,
                            Icons.water_drop,
                          ),
                          const SizedBox(height: 20),
                          metaWithBadgeStack,
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          tcgCard = Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: avatarColor.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                titleWidget,
                const SizedBox(height: 20),
                avatarWidget,
                if (statusText.isNotEmpty) statusWidget,
                if (statusText.isEmpty)
                  const SizedBox(height: 24), // Spacer if no status
                const SizedBox(height: 20),
                buildStatBar(
                  "HP (Hangouts)",
                  hp,
                  Colors.redAccent,
                  Icons.whatshot,
                ),
                const SizedBox(height: 12),
                buildStatBar(
                  "Mana (Invites)",
                  mana,
                  Colors.blueAccent,
                  Icons.water_drop,
                ),
                const SizedBox(height: 16),
                metaWithBadgeStack,
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: double.infinity,
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
                    const SizedBox(height: 24),

                    // Render the dynamically built TCG Card
                    tcgCard,

                    const SizedBox(height: 24),

                    // --- ACTION BUTTONS ---
                    if (showAddButton) ...[
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.person_add_alt_1,
                          color: primaryColor,
                          size: 28,
                        ),
                        title: const Text(
                          "Add to Squad",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          "Invite them to your future hangouts",
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _addFriend(context, guest['uid'], phone, displayName);
                        },
                      ),
                    ],

                    // HIDE FROM SELF: Only show Report if this is NOT the logged-in user
                    if (guest['uid'] != currentUserId) ...[
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.flag,
                          color: Colors.red,
                          size: 28,
                        ),
                        title: const Text(
                          "Report User",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text("Flag for inappropriate behavior"),
                        onTap: () {
                          Navigator.pop(ctx);
                          _reportUser(guest['uid'], displayName);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVoteTallySheet(
    BuildContext context,
    List<dynamic> options,
    List<Map<String, dynamic>> guests,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

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
              maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.how_to_vote, color: primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      "Vote Breakdown",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: options.map((opt) {
                        final optId = opt['id'];
                        final title = opt['title'];
                        final location = opt['location'];

                        // Find everyone who voted for this option (excluding declined guests)
                        final voters = guests.where((g) {
                          if (g['status'] == 'declined') return false;
                          final vList = List<String>.from(g['votes'] ?? []);
                          return vList.contains(optId);
                        }).toList();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        if (location != null &&
                                            location != 'TBD')
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              location,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "${voters.length} Vote${voters.length == 1 ? '' : 's'}",
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (voters.isEmpty)
                                Text(
                                  "No votes yet.",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: voters.map((v) {
                                    final avatarColor = Color(
                                      v['avatarColor'] ??
                                          Colors.blue.toARGB32(),
                                    );
                                    final avatarUrl = v['avatarUrl'];
                                    final name = v['displayName'];

                                    return Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor: avatarColor,
                                        backgroundImage: avatarUrl != null
                                            ? CachedNetworkImageProvider(
                                                avatarUrl,
                                              )
                                            : null,
                                        child: avatarUrl == null
                                            ? Text(
                                                name[0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                      label: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey.shade200
                                              : Colors.grey.shade800,
                                        ),
                                      ),
                                      backgroundColor: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade100,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade200,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TACTILE CARD WRAPPER ---
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
                // NEW: Beautiful Material Ripple wrapped around the icon
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

  void _pushToCalendar() {
    final data = widget.eventData;
    final Timestamp? ts = data['time'];
    if (ts == null) return;

    final DateTime startTime = ts.toDate();
    // Defaulting the event duration to 2 hours since we don't explicitly ask for an end time
    final DateTime endTime = startTime.add(const Duration(hours: 2));

    final Event calendarEvent = Event(
      title: data['title'] ?? 'Squad Hangout',
      description: data['details'] ?? 'Added via tfti.app',
      location: data['location'] ?? '',
      startDate: startTime,
      endDate: endTime,
      iosParams: const IOSParams(
        reminder: Duration(minutes: 60), // Remind them an hour before!
      ),
    );

    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  void _showSquadNeedsSheet(BuildContext context, bool canEdit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUser = FirebaseAuth.instance.currentUser!;
    final roleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // Padding ensures the keyboard smoothly pushes the text field up!
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
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
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_box_outlined,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Squad Needs",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // --- THE LIVE NEEDS LIST ---
                  Flexible(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('events')
                          .doc(widget.eventId)
                          .collection('roles')
                          .orderBy('createdAt')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final roles = snapshot.data!.docs;

                        if (roles.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volunteer_activism,
                                  size: 48,
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  canEdit
                                      ? "Add items you need help with!"
                                      : "No squad needs right now.",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: roles.length,
                          itemBuilder: (context, index) {
                            final roleDoc = roles[index];
                            final roleData =
                                roleDoc.data() as Map<String, dynamic>;
                            final title = roleData['title'] ?? 'Item';

                            final assigneeId = roleData['claimedByUid'];
                            final assigneeName = roleData['claimedByName'];
                            final addedBy = roleData['addedBy'];

                            final isClaimed = assigneeId != null;
                            final isMe = assigneeId == currentUser.uid;

                            // --- EXACT PERMISSIONS ---
                            final isMainHost =
                                widget.eventData['hostId'] == currentUser.uid;
                            final isItemCreator = addedBy == currentUser.uid;
                            final canManageItem = isMainHost || isItemCreator;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isClaimed
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : (isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade100),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isClaimed
                                      ? Icons.check
                                      : Icons.pan_tool_outlined,
                                  color: isClaimed
                                      ? Colors.green
                                      : (isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: null,
                                  color: isClaimed
                                      ? (isDark
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade500)
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                              ),
                              subtitle: isClaimed
                                  ? Text(
                                      isMe
                                          ? "Claimed by you"
                                          : "Claimed by $assigneeName",
                                      style: TextStyle(
                                        color: isMe
                                            ? primaryColor
                                            : (isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600),
                                        fontWeight: isMe
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isClaimed)
                                    ElevatedButton(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        final userDoc = await FirebaseFirestore
                                            .instance
                                            .collection('users')
                                            .doc(currentUser.uid)
                                            .get();
                                        final myName =
                                            userDoc.data()?['displayName'] ??
                                            "Someone";
                                        await roleDoc.reference.update({
                                          'claimedByUid': currentUser.uid,
                                          'claimedByName': myName,
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text(
                                        "Claim",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (isMe || canManageItem)
                                    OutlinedButton(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        await roleDoc.reference.update({
                                          'claimedByUid': FieldValue.delete(),
                                          'claimedByName': FieldValue.delete(),
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        isMe ? "Unclaim" : "Unassign",
                                      ),
                                    ),
                                  if (canManageItem)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        roleDoc.reference.delete();
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // --- ADD ITEM FORM (Hosts Only) ---
                  if (canEdit) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: roleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: "Add a new need (e.g. Bring Ice)",
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (val) async {
                                if (val.trim().isEmpty) return;
                                await FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(widget.eventId)
                                    .collection('roles')
                                    .add({
                                      'title': val.trim(),
                                      'addedBy': currentUser.uid,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                roleController.clear();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () async {
                                if (roleController.text.trim().isEmpty) return;
                                await FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(widget.eventId)
                                    .collection('roles')
                                    .add({
                                      'title': roleController.text.trim(),
                                      'addedBy': currentUser.uid,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                roleController.clear();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<TextSpan> _buildLinkedTextSpans(
    String text,
    bool isDark,
    Color primaryColor,
  ) {
    final List<TextSpan> spans = [];

    // regex to catch http, https, and www links
    final RegExp urlRegExp = RegExp(
      r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(text);
    int previousEnd = 0;

    for (final match in matches) {
      // Add the normal text before the URL
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

      // Add the clickable URL
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
              // Force https if they just typed "www.example.com"
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                launchUrlString = 'https://$url';
              }
              final Uri uri = Uri.parse(launchUrlString);
              if (await canLaunchUrl(uri)) {
                await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                ); // Opens default Safari/Chrome
              } else {
                debugPrint('Could not launch $launchUrlString');
              }
            },
        ),
      );

      previousEnd = match.end;
    }

    // Add any remaining normal text after the last URL
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // 1. Resolve Event Stream
    return StreamBuilder<DocumentSnapshot>(
      stream: _eventStream,
      builder: (context, eventSnapshot) {
        var data = widget.eventData;
        if (eventSnapshot.hasData && eventSnapshot.data!.data() != null) {
          data = eventSnapshot.data!.data() as Map<String, dynamic>;
        }

        // 2. Resolve My Invite Stream
        return StreamBuilder<DocumentSnapshot>(
          stream: _myInviteStream,
          builder: (context, inviteSnap) {
            Map<String, dynamic> myInviteData = {};
            String myStatus = 'pending';
            if (inviteSnap.hasData && inviteSnap.data!.exists) {
              myInviteData = inviteSnap.data!.data() as Map<String, dynamic>;
              myStatus = myInviteData['status'] ?? 'pending';
            }

            // 3. Resolve Roles Stream
            return StreamBuilder<QuerySnapshot>(
              stream: _rolesStream,
              builder: (context, roleSnap) {
                final rolesDocs = roleSnap.data?.docs ?? [];

                // 4. Resolve Crew Stream
                return StreamBuilder<QuerySnapshot>(
                  stream: _crewStream,
                  builder: (context, crewSnap) {
                    final inviteDocs = crewSnap.data?.docs ?? [];

                    // --- 5. EXTRACT CORE VARIABLES ---
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
                    final bool dbIsPast = data['isPast'] == true;
                    final bool isPast =
                        dbIsPast || DateTime.now().isAfter(endTime);

                    // --- 6. CACHE CREW FUTURE ---
                    // Generates a hash to see if anyone's RSVP changed
                    int currentHash = inviteDocs.length;
                    for (var doc in inviteDocs) {
                      final d = doc.data() as Map<String, dynamic>;
                      currentHash ^=
                          doc.id.hashCode ^
                          (d['status']?.hashCode ?? 0) ^
                          (d['respondedAt']?.hashCode ?? 0) ^
                          (d['lastViewedAt']?.hashCode ?? 0);
                    }

                    // Only re-fetch profiles if the hash changes!
                    if (_cachedCrewFuture == null ||
                        currentHash != _lastCrewHash) {
                      _lastCrewHash = currentHash;
                      _cachedCrewFuture = _fetchAndSortGuests(
                        inviteDocs,
                        dt,
                        rsvpDeadline,
                      );
                    }

                    // --- 7. RENDER THE LAYOUT ---
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final bool useTwoColumns =
                            isLandscape || constraints.maxWidth > 600;
                        final Color appBarIconColor = isDark
                            ? Colors.white
                            : (_isAppBarCollapsed
                                  ? Colors.grey.shade700
                                  : Colors.white);

                        // --- UI: Vitals Card ---
                        final String location =
                            data['location'] ??
                            'TBD'; // Add this line to grab the location

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
                              // (The old calendar button is now completely gone!)
                            ],
                          ),
                        );

                        // --- UI: Details Card ---
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

                        // --- UI: Squad Needs Card ---
                        Widget squadNeedsCardWidget = const SizedBox.shrink();
                        if (rolesDocs.isNotEmpty) {
                          squadNeedsCardWidget = _buildInfoCard(
                            title: "Squad Needs",
                            icon: Icons.check_box_outlined,
                            child: InkWell(
                              onTap: () =>
                                  _showSquadNeedsSheet(context, canEdit),
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

                        // --- UI: RSVP Card ---
                        Widget rsvpCardWidget;
                        if (isVibeCheck) {
                          rsvpCardWidget = _buildInfoCard(
                            title: "Cast Your Vote",
                            icon: Icons.how_to_vote,
                            onIconTap: () async {
                              if (_cachedCrewFuture != null) {
                                final guests = await _cachedCrewFuture!;
                                if (context.mounted) {
                                  _showVoteTallySheet(
                                    context,
                                    data['pollOptions'] ?? [],
                                    guests,
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

                        // --- UI: Crew Card ---
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
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
                                                        : Colors
                                                              .grey
                                                              .shade700));

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
                                              onTap: () =>
                                                  _showGuestProfileSheet(
                                                    guest,
                                                    showAddButton,
                                                    isGoated: isGoated,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal:
                                                      8, // Added a little horizontal padding for the tap highlight
                                                ),
                                                child: Row(
                                                  children: [
                                                    Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color:
                                                                    Color(
                                                                      guest['avatarColor'],
                                                                    ).withValues(
                                                                      alpha:
                                                                          0.4,
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
                                                                    fontSize:
                                                                        16,
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
                                                                    Symbols
                                                                        .crown,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .amber,
                                                                  ),
                                                                ),
                                                              if (guestUid ==
                                                                  data['coHostId'])
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
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
                                                                color:
                                                                    primaryColor,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (showAddButton)
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons
                                                              .person_add_alt_1,
                                                          color: primaryColor,
                                                        ),
                                                        onPressed: () =>
                                                            _addFriend(
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
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        // --- FINAL SCAFFOLD ---
                        // We calculate unread FAB notification directly without another StreamBuilder!
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
                                      // 1. Base Gradient (Fallback if no image - identical to Teams page!)
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: themeProvider.appGradient,
                                        ),
                                      ),

                                      // 2. Custom Uploaded Banner & Simple 2-Color Overlay
                                      if (hasBanner) ...[
                                        CachedNetworkImage(
                                          imageUrl: data['bannerUrl'],
                                          fit: BoxFit.cover,
                                        ),

                                        // 3. Text Protection (Only applied if there's a photo!)
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

                                      // 4. The Content (Title, Host, Vibe Check Pill)
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

// --- SWIPE-TO-RSVP WIDGET ---
class SwipeRsvpWidget extends StatefulWidget {
  final String currentStatus;
  final bool isLocked;
  final Function(String) onRsvp;

  const SwipeRsvpWidget({
    super.key,
    required this.currentStatus,
    this.isLocked = false,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        final bool isCompact =
            trackWidth < 280; // Detects landscape/narrow widths

        // If event is locked and they haven't RSVP'd, show closed text
        if (widget.isLocked && widget.currentStatus == 'pending') {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 12 : 16,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.grey, size: 24),
                const SizedBox(width: 8),
                Text(
                  "RSVP Closed",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // Status 1: ACCEPTED
        if (widget.currentStatus == 'going') {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 12 : 16,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: isCompact
                ? Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "You're in! 🤗",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!widget.isLocked)
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => widget.onRsvp('pending'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.green.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Change",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
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
                      if (!widget.isLocked)
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
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 12 : 16,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: isCompact
                ? Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 24),
                          SizedBox(width: 8),
                          Text(
                            "Missing out.",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // --- FIX: ADDED LOCK CHECK HERE ---
                      if (!widget.isLocked)
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => widget.onRsvp('pending'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Change RSVP",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.cancel, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
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
                      // --- FIX: ADDED LOCK CHECK HERE ---
                      if (!widget.isLocked)
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

        // Status 3: PENDING (Interactive Slider OR Compact Buttons)
        if (isCompact) {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onRsvp('declined');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
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
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onRsvp('going');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "I'm In!",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        }

        // Normal Pending Slider for Portrait Mode
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
  final bool isLocked;

  const VibeCheckPollUI({
    super.key,
    required this.eventId,
    required this.eventData,
    required this.myInviteData,
    required this.myUid,
    required this.isHost,
    this.isLocked = false,
  });

  Future<void> _castVote(String optionId) async {
    if (isLocked) return;

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

    batch.set(inviteRef, {
      'uid': myUid,
      'votes': currentVotes,
    }, SetOptions(merge: true));

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
    if (isLocked) return;

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
