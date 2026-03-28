import 'dart:async';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'login_page.dart';
import 'create_event_page.dart';
import 'create_vibecheck_page.dart';
import 'event_details_page.dart';
import 'friends_page.dart';
import 'friend_circles_page.dart';
import 'profile_page.dart';
import 'firebase_options.dart';
import 'theme_provider.dart';
import 'onboarding_tutorial.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint("🚀 STARTING APP...");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase Initialized");
  } catch (e) {
    debugPrint("❌ Firebase already initialized: $e");
  }

  try {
    if (Platform.isIOS) {
      await Purchases.configure(PurchasesConfiguration("YOUR_APPLE_API_KEY"));
    } else if (Platform.isAndroid) {
      await Purchases.configure(PurchasesConfiguration("YOUR_GOOGLE_API_KEY"));
    }
  } catch (e) {
    debugPrint("RevenueCat Init Error (ignore if no API keys yet): $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return MaterialApp(
          title: 'TFTI',
          theme: themeProvider.themeData,
          debugShowCheckedModeBanner: false,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const MainShell();
        }
        return const LoginPage();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _showTutorial = false;

  final GlobalKey _contentKey = GlobalKey();

  final List<Widget> _pages = [
    const HomeFeedTab(),
    const FriendCirclesPage(),
    const FriendsPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _silentProfileRefresh();
    _checkTutorialStatus();
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial') ?? false;
    if (!hasSeen) {
      setState(() {
        _showTutorial = true;
      });
    }
  }

  Future<void> _silentProfileRefresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'Notification permission status: ${settings.authorizationStatus}',
      );

      final token = await messaging.getToken();

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('FCM Token error (expected on simulator): $e');
    }
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('invitations')
          .where('uid', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        bool hasPendingNotHidden = false;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['isHidden'] != true) {
              hasPendingNotHidden = true;
              break;
            }
          }
        }

        final showBadge = hasPendingNotHidden && _selectedIndex != 0;

        return Stack(
          children: [
            Scaffold(
              body: isLandscape
                  ? Row(
                      children: [
                        SafeArea(
                          right: false,
                          child: NavigationRail(
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: _onNavTapped,
                            backgroundColor: Theme.of(context).cardColor,
                            selectedIconTheme: IconThemeData(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            selectedLabelTextStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            labelType: NavigationRailLabelType.all,
                            useIndicator: true,
                            indicatorColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                            destinations: [
                              NavigationRailDestination(
                                icon: Badge(
                                  isLabelVisible: showBadge,
                                  backgroundColor: Colors.redAccent,
                                  smallSize: 8,
                                  child: const Icon(Symbols.cottage),
                                ),
                                label: const Text("Home"),
                              ),
                              const NavigationRailDestination(
                                icon: Icon(
                                  Icons.supervised_user_circle_outlined,
                                ),
                                label: Text("Teams"),
                              ),
                              const NavigationRailDestination(
                                icon: Icon(Symbols.group),
                                label: Text("Squad"),
                              ),
                              const NavigationRailDestination(
                                icon: Icon(Symbols.account_circle),
                                label: Text("Account"),
                              ),
                            ],
                          ),
                        ),
                        VerticalDivider(
                          thickness: 1,
                          width: 1,
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),
                        Expanded(
                          child: IndexedStack(
                            key: _contentKey,
                            index: _selectedIndex,
                            children: _pages,
                          ),
                        ),
                      ],
                    )
                  : IndexedStack(
                      key: _contentKey,
                      index: _selectedIndex,
                      children: _pages,
                    ),
              bottomNavigationBar: isLandscape
                  ? null
                  : BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Theme.of(context).cardColor,
                      selectedItemColor: Theme.of(context).colorScheme.primary,
                      unselectedItemColor: Colors.grey,
                      showSelectedLabels: true,
                      showUnselectedLabels: true,
                      currentIndex: _selectedIndex,
                      onTap: _onNavTapped,
                      items: [
                        BottomNavigationBarItem(
                          icon: Badge(
                            isLabelVisible: showBadge,
                            backgroundColor: Colors.redAccent,
                            smallSize: 8,
                            child: const Icon(Symbols.cottage),
                          ),
                          label: "Home",
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.supervised_user_circle_outlined),
                          label: "Teams",
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Symbols.group),
                          label: "Squad",
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Symbols.account_circle),
                          label: "Account",
                        ),
                      ],
                    ),
            ),
            if (_showTutorial)
              Positioned.fill(
                child: OnboardingTutorial(
                  onComplete: () {
                    setState(() {
                      _showTutorial = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class HomeFeedTab extends StatefulWidget {
  const HomeFeedTab({super.key});

  @override
  State<HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<HomeFeedTab> {
  String _selectedFilter = 'all';
  String? _selectedEventId;
  Map<String, dynamic>? _selectedEventData;

  // Track auto-resolves to prevent overlapping transaction attempts
  final Set<String> _resolvingVibeChecks = {};

  Future<void> _quickRSVP(String eventId, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('invitations')
        .doc(user.uid)
        .set({
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
          .set({'isHidden': !currentlyHidden}, SetOptions(merge: true));

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

  // --- LAZY EVALUATION FAILSAFE FOR VIBE CHECKS ---
  Future<void> _runVibeCheckAutoResolve(
    String eventId,
    Map<String, dynamic> eventData,
  ) async {
    if (_resolvingVibeChecks.contains(eventId)) return;
    _resolvingVibeChecks.add(eventId);

    try {
      final invitesSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('invitations')
          .get();

      Map<String, int> voteCounts = {};
      for (var doc in invitesSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'declined') continue;

        final votes = List<String>.from(data['votes'] ?? []);
        for (String v in votes) {
          voteCounts[v] = (voteCounts[v] ?? 0) + 1;
        }
      }

      final pollOptions = List<dynamic>.from(eventData['pollOptions'] ?? []);
      if (pollOptions.isEmpty) return;

      int maxVotes = -1;
      List<String> winningIds = [];

      for (var opt in pollOptions) {
        final String optId = opt['id'];
        final int count = voteCounts[optId] ?? 0;
        if (count > maxVotes) {
          maxVotes = count;
          winningIds = [optId];
        } else if (count == maxVotes) {
          winningIds.add(optId);
        }
      }

      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(eventId);

      if (winningIds.length == 1) {
        // Clear winner -> Convert to Event
        final winnerId = winningIds.first;
        final winnerOpt = pollOptions.firstWhere(
          (opt) => opt['id'] == winnerId,
        );

        final batch = FirebaseFirestore.instance.batch();
        batch.update(eventRef, {
          'type': 'event',
          'lockedOptionId': winnerId,
          'title': winnerOpt['title'],
          'location': winnerOpt['location'],
          'isTieBreakerNeeded': false,
        });

        // Resolve Guests statuses based on vote
        for (var doc in invitesSnap.docs) {
          final data = doc.data();
          if (data['status'] == 'declined') continue;

          final votes = List<String>.from(data['votes'] ?? []);
          String newStatus = votes.contains(winnerId) ? 'going' : 'pending';

          if (data['role'] == 'host' || data['role'] == 'co-host') {
            newStatus = 'going';
          }

          batch.update(doc.reference, {'status': newStatus});
        }
        await batch.commit();
      } else {
        await eventRef.update({'isTieBreakerNeeded': true});
      }
    } catch (e) {
      debugPrint("Auto-Resolve Error: $e");
    } finally {
      _resolvingVibeChecks.remove(eventId);
    }
  }

  // --- NEW: Filter Configuration ---
  final Map<String, Map<String, dynamic>> _filterConfig = {
    'all': {'name': 'All Hangouts', 'icon': Icons.all_inbox},
    'pending': {'name': 'Incoming', 'icon': Icons.mark_email_unread_outlined},
    'vibes': {'name': 'Vibes', 'icon': Symbols.earthquake},
    'soon': {'name': 'Starting Soon', 'icon': Icons.timer_outlined},
    'now': {'name': 'Go Time', 'icon': Icons.local_fire_department_outlined},
    'going': {'name': 'Going', 'icon': Icons.event_available},
    'declined': {'name': 'Missing Out', 'icon': Icons.cancel_outlined},
    'past_hidden': {'name': 'Past / Hidden', 'icon': Icons.history},
  };

  // --- NEW: Modern Filter Bottom Sheet ---
  void _showFilterBottomSheet(bool isDark, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
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
                  "Filter Feed",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filterConfig.length,
                  itemBuilder: (context, index) {
                    String key = _filterConfig.keys.elementAt(index);
                    Map<String, dynamic> config = _filterConfig[key]!;
                    bool isSelected = _selectedFilter == key;

                    return ListTile(
                      leading: Icon(
                        config['icon'],
                        color: isSelected
                            ? primaryColor
                            : (isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                      ),
                      title: Text(
                        config['name'],
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? primaryColor
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: primaryColor)
                          : null,
                      onTap: () {
                        setState(() => _selectedFilter = key);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- NEW: Host Profile Bottom Sheet ---
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
                "Captain",
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
                // 👇 FIX: Removed the phone number subtitle completely
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
          isScrollControlled:
              true, // 👇 Allows sheet to exceed 50% screen height
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              // 👇 Prevents overflow in landscape
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    Widget feedContent = Column(
      children: [
        // Modern Section Header & Pill Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // FIX: Wrap in Expanded + FittedBox to gracefully scale down text in landscape
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "the i's",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12), // Buffer to ensure they never touch
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showFilterBottomSheet(isDark, primaryColor),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filterConfig[_selectedFilter]!['icon'],
                          size: 14,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _filterConfig[_selectedFilter]!['name'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                    myInvitesMap[eventId] = doc.data() as Map<String, dynamic>;
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

                  final now = DateTime.now();
                  List<Map<String, dynamic>> displayEvents = [];

                  for (var eventDoc in eventSnapshot.data!.docs) {
                    final eventId = eventDoc.id;
                    final eventData = eventDoc.data() as Map<String, dynamic>;

                    final bool isMyEvent = eventData['hostId'] == user?.uid;
                    final inviteData = myInvitesMap[eventId] ?? {};

                    String status =
                        inviteData['status'] ??
                        (isMyEvent ? 'going' : 'pending');
                    final bool isHidden = inviteData['isHidden'] ?? false;

                    final Timestamp? ts = eventData['time'];
                    final DateTime eventTime = ts?.toDate() ?? now;

                    final int deadlineOffset = eventData['rsvpDeadline'] ?? 0;
                    final DateTime deadlineTime = eventTime.add(
                      Duration(minutes: deadlineOffset),
                    );
                    final bool isPastDeadline = now.isAfter(deadlineTime);

                    // --- LAZY EVALUATION TRIGGER ---
                    if (eventData['type'] == 'vibe_check' &&
                        eventData['lockedOptionId'] == null) {
                      if (isPastDeadline &&
                          eventData['isTieBreakerNeeded'] != true) {
                        _runVibeCheckAutoResolve(eventId, eventData);
                      }
                    }

                    if (status == 'pending' &&
                        isPastDeadline &&
                        eventData['type'] != 'vibe_check') {
                      status = 'declined';
                      if (inviteData.isNotEmpty &&
                          inviteData['status'] == 'pending') {
                        FirebaseFirestore.instance
                            .collection('events')
                            .doc(eventId)
                            .collection('invitations')
                            .doc(user?.uid)
                            .update({'status': 'declined'})
                            .catchError((_) {});
                      }
                    }

                    final Duration diff = eventTime.difference(now);
                    final int diffMins = diff.inMinutes;

                    final bool isStartingSoon = diffMins <= 60 && diffMins > 0;
                    final bool isHappeningNow =
                        diffMins <= 0 && diffMins >= -240;
                    final bool isPast = diffMins < -240;

                    bool shouldDisplay = false;

                    switch (_selectedFilter) {
                      case 'all':
                        if (!isHidden && !isPast) shouldDisplay = true;
                        break;
                      case 'pending':
                        if (status == 'pending' && !isHidden && !isPast) {
                          shouldDisplay = true;
                        }
                        break;
                      case 'vibes':
                        if (eventData['type'] == 'vibe_check' &&
                            !isHidden &&
                            !isPast) {
                          shouldDisplay = true;
                        }
                        break;
                      case 'soon':
                        if (isStartingSoon && !isHidden) shouldDisplay = true;
                        break;
                      case 'now':
                        if (isHappeningNow && !isHidden) shouldDisplay = true;
                        break;
                      case 'going':
                        if (status == 'going' && !isHidden && !isPast) {
                          shouldDisplay = true;
                        }
                        break;
                      case 'declined':
                        if (status == 'declined' && !isHidden && !isPast) {
                          shouldDisplay = true;
                        }
                        break;
                      case 'past_hidden':
                        if (isHidden || isPast) shouldDisplay = true;
                        break;
                    }

                    if (shouldDisplay) {
                      displayEvents.add({
                        'id': eventId,
                        'eventData': eventData,
                        'inviteData': inviteData,
                        'isPast': isPast,
                        'isStartingSoon': isStartingSoon,
                        'isHappeningNow': isHappeningNow,
                        'status': status,
                        'time': eventTime,
                      });
                    }
                  }

                  if (_selectedFilter == 'past_hidden') {
                    displayEvents.sort(
                      (a, b) => (b['time'] as DateTime).compareTo(
                        a['time'] as DateTime,
                      ),
                    );
                  } else {
                    displayEvents.sort(
                      (a, b) => (a['time'] as DateTime).compareTo(
                        b['time'] as DateTime,
                      ),
                    );
                  }

                  if (displayEvents.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return ListView.builder(
                    key: const PageStorageKey<String>('home_feed_list'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: displayEvents.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(
                        context,
                        displayEvents[index],
                        isDark,
                        primaryColor,
                        user?.uid,
                        isLandscape,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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
    String message = "Nothing happening here.";
    IconData icon = Icons.event_busy;

    if (_selectedFilter == 'pending') {
      message = "You're all caught up!";
      icon = Icons.mark_email_read_outlined;
    } else if (_selectedFilter == 'vibes') {
      message = "No Vibe Checks to vote on.";
      icon = Symbols.earthquake;
    } else if (_selectedFilter == 'soon') {
      message = "Nothing starting soon.";
      icon = Icons.timer_outlined;
    } else if (_selectedFilter == 'now') {
      message = "Nothing happening right now.";
      icon = Icons.local_fire_department_outlined;
    } else if (_selectedFilter == 'going') {
      message = "You're not going to anything yet.";
      icon = Icons.event_available;
    } else if (_selectedFilter == 'declined') {
      message = "You're not missing out on anything.";
      icon = Icons.sentiment_satisfied_alt;
    } else if (_selectedFilter == 'past_hidden') {
      message = "No past or hidden events.";
      icon = Icons.visibility_off_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 18),
          ),
          if (_selectedFilter == 'all') ...[
            const SizedBox(height: 8),
            Text(
              "Tap + to start something!",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.black87,
              ),
            ),
          ],
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
    bool isLandscape,
  ) {
    final String eventId = item['id'];
    final Map<String, dynamic> data = item['eventData'];
    final Map<String, dynamic> inviteData = item['inviteData'];

    final bool isPast = item['isPast'];
    final bool isStartingSoon = item['isStartingSoon'] ?? false;
    final bool isHappeningNow = item['isHappeningNow'];
    final String status = item['status'];
    final bool isHidden = inviteData['isHidden'] ?? false;

    final bool isVibeCheck = data['type'] == 'vibe_check';
    final bool isMyEvent = data['hostId'] == myUid;
    final bool isImportantDetails = data['isImportantDetails'] == true;

    final String? lastMessageSnippet = data['lastMessageSnippet'];

    Color cardBgColor = Theme.of(context).cardColor;
    double cardElevation = isDark ? 1 : 2;

    // --- NEW: DATE/TIME PARSING ---
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
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String timeString = "$hour:$minute $period";

    IconData statusIcon;
    Color statusColor;
    String statusText;
    Color titleTextColor = isDark ? Colors.white : Colors.black87;

    final bool isGoing = status == 'going';
    final bool isDeclined = status == 'declined';

    if (isPast) {
      cardElevation = 0;
      statusText = "Wrapped up";
      statusColor = Colors.grey;
      statusIcon = Icons.history;
      titleTextColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;
    } else if (isDeclined) {
      statusText = "Missing out";
      statusColor = isDark ? Colors.redAccent : Colors.red;
      statusIcon = Icons.cancel;
    } else if (isHappeningNow) {
      statusText = "Happening Now!";
      statusColor = isDark ? Colors.orangeAccent : Colors.orange.shade800;
      statusIcon = Icons.whatshot;
    } else if (isStartingSoon) {
      statusText = "Starting Soon";
      statusColor = isDark ? Colors.amberAccent : Colors.amber.shade800;
      statusIcon = Icons.directions_run;
    } else if (isGoing) {
      statusText = "You're going";
      statusColor = isDark ? Colors.greenAccent : Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusText = isVibeCheck ? "Vote Pending" : "RSVP Pending";
      statusColor = isDark
          ? const Color(0xFFF1AD5B)
          : const Color(0xFFD98301); // Custom Gold for better visibility
      statusIcon = isVibeCheck ? Icons.how_to_vote : Symbols.mail;
    }

    final Timestamp? lastUpdateTime = data['lastUpdatedAt'];
    final Timestamp? lastViewedDetailsTime = inviteData['lastViewedAt'];
    bool hasCriticalUpdate = false;
    if (lastUpdateTime != null && lastViewedDetailsTime != null) {
      if (lastUpdateTime.seconds > lastViewedDetailsTime.seconds) {
        hasCriticalUpdate = true;
      }
    }

    final Timestamp? lastMsgTime = data['lastMessageAt'];
    final Timestamp? lastReadTime = inviteData['lastReadChat'];
    final List<dynamic> lastMentions = data['lastMessageMentions'] ?? [];

    bool hasUnreadChat = false;
    bool wasMentioned = false;

    if (lastMsgTime != null) {
      if (lastReadTime == null || lastMsgTime.seconds > lastReadTime.seconds) {
        hasUnreadChat = true;
        if (lastMentions.contains(myUid)) wasMentioned = true;
      }
    }

    final bool isSelected = isLandscape && _selectedEventId == eventId;

    return Dismissible(
      key: Key(eventId),
      direction: isPast ? DismissDirection.none : DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24.0),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Symbols.thumb_up, color: Colors.white, size: 36),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Symbols.thumb_down, color: Colors.white, size: 36),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _quickRSVP(eventId, 'going');
        } else if (direction == DismissDirection.endToStart) {
          await _quickRSVP(eventId, 'declined');
        }
        return false;
      },
      child: Card(
        elevation: isSelected ? 4 : cardElevation,
        color: isSelected ? primaryColor.withValues(alpha: 0.1) : cardBgColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: primaryColor, width: 2)
              : BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 1,
                ),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _toggleHideStatus(eventId, isHidden),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- NEW: THE CALENDAR LEFT COLUMN ---
                Column(
                  children: [
                    Container(
                      width: 52,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.red.shade100,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: isPast ? Colors.grey : Colors.redAccent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              month,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPast ? Colors.grey : primaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // --- NEW: THE CONTENT RIGHT COLUMN ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isVibeCheck)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary
                                .withValues(
                                  alpha: 0.15,
                                ), // Dynamic Material 3 Pill Color
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.earthquake,
                                size: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary, // Dynamic Material 3 Accent
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "VIBE CHECK",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] ?? "Untitled",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: titleTextColor,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasCriticalUpdate)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.info,
                                color: Colors.amber,
                                size: 20,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Location Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: isPast
                                ? Colors.grey.shade600
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['location'] ?? 'Multiple Spots',
                              style: TextStyle(
                                fontSize: 13,
                                color: isPast
                                    ? Colors.grey.shade600
                                    : (isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // --- NEW: HORIZONTAL DASHBOARD (PILL TAGS) ---
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // 1. HOST PILL
                          if (isMyEvent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Symbols.crown,
                                    size: 12,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Captain",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
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
                                final String hostName =
                                    hostData['displayName'] ?? "Captain";
                                final int hostColor =
                                    hostData['avatarColor'] ??
                                    Colors.blue.toARGB32();
                                final String? hostAvatarUrl =
                                    hostData['avatarUrl'];

                                return InkWell(
                                  onTap: () => _showHostBottomSheet(
                                    context,
                                    hostData,
                                    isDark,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      right: 8,
                                      top: 2,
                                      bottom: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(
                                                  hostColor,
                                                ).withValues(alpha: 0.4),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 10,
                                            backgroundColor: Color(hostColor),
                                            backgroundImage:
                                                hostAvatarUrl != null
                                                ? CachedNetworkImageProvider(
                                                    hostAvatarUrl,
                                                  )
                                                : null,
                                            child: hostAvatarUrl == null
                                                ? Text(
                                                    hostName.isNotEmpty
                                                        ? hostName[0]
                                                              .toUpperCase()
                                                        : "?",
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Captain",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.black87,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                          // 2. STATUS PILL
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 3. IMPORTANT DETAILS PILL
                          if (isImportantDetails && !isPast)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.announcement_outlined,
                                    size: 12,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "PLEASE READ",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // --- REFINED CHAT SNIPPET ---
                      if (lastMessageSnippet != null &&
                          lastMessageSnippet.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: hasUnreadChat
                                  ? Border.all(
                                      color: wasMentioned
                                          ? Colors.amber.shade600
                                          : primaryColor.withValues(alpha: 0.5),
                                      width: 1,
                                    )
                                  : Border.all(
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                    ),
                            ),
                            child: Row(
                              children: [
                                if (wasMentioned)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.alternate_email,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  )
                                else if (hasUnreadChat)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      size: 14,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    lastMessageSnippet,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: hasUnreadChat
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black87)
                                          : (isDark
                                                ? Colors.grey.shade500
                                                : Colors.grey.shade600),
                                      fontWeight: hasUnreadChat
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (lastMsgTime != null)
                                  LastMessageSenderAvatar(
                                    eventId: eventId,
                                    lastMessageAt: lastMsgTime,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- NEW: SENDER AVATAR WIDGET ---
class LastMessageSenderAvatar extends StatefulWidget {
  final String eventId;
  final Timestamp lastMessageAt; // Used to trigger rebuilds on new messages

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
      // Query the messages subcollection safely (allowed by your firestore rules)
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
