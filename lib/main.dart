import 'dart:async';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import 'login_page.dart';
import 'event_chat_page.dart';
import 'create_event_page.dart';
import 'create_vibecheck_page.dart';
import 'event_details_page.dart';
import 'friends_page.dart';
import 'friend_circles_page.dart';
import 'profile_page.dart';
import 'firebase_options.dart';
import 'theme_provider.dart';
import 'onboarding_tutorial.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<
      NavigatorState
    >(); // Global navigator key for showing dialogs/snackbars from anywhere

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

  // Scenario 1: The app is completely closed / terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null && message.data.isNotEmpty) {
      handleNotificationRouting(message.data);
    }
  });

  // Scenario 2: The app is running in the background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (message.data.isNotEmpty) {
      handleNotificationRouting(message.data);
    }
  });

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
          navigatorKey: navigatorKey, // Attach global navigator key
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _clearAppBadge();
    _silentProfileRefresh();
    _checkTutorialStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearAppBadge();
    }
  }

  Future<void> _clearAppBadge() async {
    try {
      bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      debugPrint("App Badger Error: $e");
    }
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
              const SizedBox(width: 12),
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
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.5),
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

                    if (status == 'pending' &&
                        isPastDeadline &&
                        eventData['type'] != 'vibe_check') {
                      status = 'declined';
                      if (inviteData.isNotEmpty &&
                          inviteData['status'] == 'pending') {
                        status = 'declined';
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
                    // 👇 FIX 1: Added large bottom padding so the last card clears the FAB!
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 8,
                      bottom: 100,
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

    final String? bannerUrl = data['bannerUrl'];
    final String? lastMessageSnippet = data['lastMessageSnippet'];

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

    // --- STATUS LOGIC ---
    IconData statusIcon;
    Color statusColor;
    String statusText;

    final bool isGoing = status == 'going';
    final bool isDeclined = status == 'declined';
    final bool isPending = status == 'pending';

    if (isPast) {
      statusText = "Wrapped up";
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.history;
    } else if (isDeclined) {
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
    } else if (isGoing) {
      statusText = "You're going";
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle;
    } else {
      statusText = isVibeCheck ? "Vote Needed" : "Action Needed";
      statusColor = Colors.orangeAccent;
      statusIcon = isVibeCheck ? Icons.how_to_vote : Symbols.mail;
    }

    // --- NOTIFICATION LOGIC ---
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
        // 👇 NEW: Premium Haptic Feedback on Swipe!
        HapticFeedback.mediumImpact();

        if (direction == DismissDirection.startToEnd) {
          await _quickRSVP(eventId, 'going');
        } else if (direction == DismissDirection.endToStart) {
          await _quickRSVP(eventId, 'declined');
        }
        return false; // Springs the card back into place
      },
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
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: isSelected
                ? Border.all(color: primaryColor, width: 2)
                : null,
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
            child: Column(
              children: [
                // --- TOP HALF: THE 16:9 HERO IMAGE ---
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. The Background Image or Fallback Gradient
                      if (bannerUrl != null && bannerUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: themeProvider.appGradient,
                          ),
                        ),

                      // 2. The Text-Protection Gradient Overlay
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

                      // 3. Top-Right: Frosted Glass Date Badge
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
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

                      // 4. Top-Left: Status Pill
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

                      // 5. Bottom-Left: Title & Details
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
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
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
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
                                ),
                                if (hasCriticalUpdate)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- BOTTOM HALF: THE LIVE PULSE (Chat/Updates) ---
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (wasMentioned)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
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
                          margin: const EdgeInsets.only(right: 12),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
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
                              : "Tap to view details & RSVP",
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

                      if (lastMsgTime != null)
                        LastMessageSenderAvatar(
                          eventId: eventId,
                          lastMessageAt: lastMsgTime,
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

Future<void> handleNotificationRouting(Map<String, dynamic> data) async {
  final eventId = data['eventId'];
  final type = data['type'];

  if (eventId == null) return;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();

    if (!doc.exists) {
      debugPrint("Event no longer exists.");
      return;
    }

    final eventData = doc.data() as Map<String, dynamic>;
    final eventTitle = eventData['title'] ?? 'Event';

    await Future.delayed(const Duration(milliseconds: 500));

    if (type == 'chat' || type == 'chat_mention') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
              EventChatPage(eventId: eventId, eventTitle: eventTitle),
        ),
      );
    } else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
              EventDetailsPage(eventId: eventId, eventData: eventData),
        ),
      );
    }
  } catch (e) {
    debugPrint("Failed to route from notification: $e");
  }
}
