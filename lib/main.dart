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
import 'package:flutter_app_badger/flutter_app_badger.dart';

import 'pages/login_page.dart';
import 'pages/hangout_chat_page.dart';
import 'pages/hangout_details_page.dart';
import 'pages/squad_page.dart';
import 'pages/teams_page.dart';
import 'pages/account_page.dart';
import 'firebase_options.dart';
import 'utils/theme_provider.dart';
import 'pages/onboarding_tutorial.dart';
import 'pages/home_feed.dart';

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

  // Ghost Badge Fix: Keep track of REAL pending invites
  bool _hasRealPending = false;
  StreamSubscription? _pendingInvitesSub;

  final GlobalKey _contentKey = GlobalKey();

  final List<Widget> _pages = [
    const HomePage(),
    const TeamsPage(),
    const SquadPage(),
    const AccountPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clearAppBadge();
    _silentProfileRefresh();
    _checkTutorialStatus();
    _listenToPendingInvites(); // Initialize the smart badge listener
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingInvitesSub?.cancel(); // Clean up the listener
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearAppBadge();
    }
  }

  // --- SMART BADGE LISTENER ---
  // This replaces the old StreamBuilder. It fetches pending invites and cross-references
  // them against the actual event time to ensure they aren't "Ghost Badges".
  void _listenToPendingInvites() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _pendingInvitesSub = FirebaseFirestore.instance
        .collectionGroup('invitations')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) async {
          bool foundRealPending = false;
          final now = DateTime.now();

          for (var doc in snap.docs) {
            final data = doc.data();
            if (data['isHidden'] == true) continue;

            final eventId = doc.reference.parent.parent?.id;
            if (eventId == null) continue;

            try {
              // Fetch the parent event to check its actual time
              final eventDoc = await FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .get();
              if (!eventDoc.exists) continue;

              final eventData = eventDoc.data() as Map<String, dynamic>;

              // Use the exact same validation logic as Home Feed
              final Timestamp? ts = eventData['time'];
              final DateTime eventTime = ts?.toDate() ?? now;

              final Timestamp? endTs = eventData['endTime'];
              DateTime endTime;
              if (endTs != null) {
                endTime = endTs.toDate();
              } else {
                final int keepAliveDays = eventData['keepAliveDays'] ?? 0;
                final int durationMinutes = keepAliveDays > 0
                    ? (keepAliveDays * 24 * 60)
                    : 240;
                endTime = eventTime.add(Duration(minutes: durationMinutes));
              }

              final bool dbIsPast = eventData['isPast'] == true;
              final bool isPast = dbIsPast || now.isAfter(endTime);

              final int deadlineOffset = eventData['rsvpDeadline'] ?? 0;
              final DateTime deadlineTime = eventTime.add(
                Duration(minutes: deadlineOffset),
              );
              final bool isPastDeadline = now.isAfter(deadlineTime);
              final bool isActuallyDeclined =
                  isPastDeadline && eventData['type'] != 'vibe_check';

              // If the event is NOT past, and NOT artificially declined, it's a REAL pending invite!
              if (!isPast && !isActuallyDeclined) {
                foundRealPending = true;
                break; // Found one! No need to check the rest, turn on the badge!
              }
            } catch (e) {
              debugPrint("Error validating pending invite: $e");
            }
          }

          if (mounted) {
            setState(() {
              _hasRealPending = foundRealPending;
            });
          }
        });
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use new smart variable to show the badge
    final showBadge = _hasRealPending && _selectedIndex != 0;

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
                            icon: Icon(Icons.supervised_user_circle_outlined),
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
              HangoutChatPage(eventId: eventId, eventTitle: eventTitle),
        ),
      );
    } else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
              HangoutDetailsPage(eventId: eventId, eventData: eventData),
        ),
      );
    }
  } catch (e) {
    debugPrint("Failed to route from notification: $e");
  }
}
