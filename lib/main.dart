import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'pages/chat_page.dart';
import 'pages/hangout_details_page.dart';
import 'pages/squad_page.dart';
import 'pages/teams_page.dart';
import 'pages/account_page.dart';
import 'firebase_options.dart';
import 'utils/theme_provider.dart';
import 'services/user_cache_repository.dart';
import 'services/web_update_service.dart';
import 'components/shared/web_update_banner.dart';
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
    if (!kIsWeb) {
      if (Platform.isIOS) {
        await Purchases.configure(PurchasesConfiguration("YOUR_APPLE_API_KEY"));
      } else if (Platform.isAndroid) {
        await Purchases.configure(PurchasesConfiguration("YOUR_GOOGLE_API_KEY"));
      }
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

  // Start background update checker for Web/PWA clients
  WebUpdateService.instance.start();

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
          title: 'thanks for the invite',
          theme: themeProvider.themeData,
          debugShowCheckedModeBanner: false,
          builder: (context, widget) {
            return WebUpdateBannerWrapper(
              child: widget ?? const SizedBox.shrink(),
            );
          },
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
          final now = DateTime.now();

          final eventIds = snap.docs
              .where((doc) => doc.data()['isHidden'] != true)
              .map((doc) => doc.reference.parent.parent?.id)
              .whereType<String>()
              .toSet();

          if (eventIds.isEmpty) {
            if (mounted) setState(() => _hasRealPending = false);
            return;
          }

          final eventsMap =
              await UserCacheRepository.instance.getEvents(eventIds);

          bool foundRealPending = false;
          for (final eventId in eventIds) {
            final event = eventsMap[eventId];
            if (event == null) continue;

            final bool isPast = event.isCurrentlyPast(now);
            final bool isPastDeadline = now.isAfter(event.rsvpDeadlineTime);
            final bool isActuallyDeclined =
                isPastDeadline && !event.isVibeCheck;

            if (!isPast && !isActuallyDeclined) {
              foundRealPending = true;
              break;
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
    if (kIsWeb) return;
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
    if (!mounted) return;
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

      // One-time build migration: ensure user phone visibility is reverted to show phone number by default
      final prefs = await SharedPreferences.getInstance();
      final hasReverted = prefs.getBool('phone_visibility_reverted_to_show_v1') ?? false;
      if (!hasReverted) {
        await prefs.setBool('phone_visibility_reverted_to_show_v1', true);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'showPhoneNumber': true,
          'isPhonePublic': true,
          'isSearchableByPhone': true,
        }, SetOptions(merge: true));
      }

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
        MediaQuery.orientationOf(context) == Orientation.landscape;
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
                          color: isDark
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                        unselectedIconTheme: IconThemeData(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        selectedLabelTextStyle: TextStyle(
                          color: isDark
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black87,
                        ),
                        labelType: NavigationRailLabelType.all,
                        useIndicator: true,
                        indicatorColor: isDark
                            ? Color.lerp(
                                Theme.of(context).colorScheme.primary,
                                Colors.white,
                                0.15,
                              )!.withValues(alpha: 0.35)
                            : Theme.of(
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
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onNavTapped,
                  destinations: [
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: showBadge,
                        backgroundColor: Colors.redAccent,
                        smallSize: 8,
                        child: const Icon(Symbols.cottage),
                      ),
                      label: "Home",
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.supervised_user_circle_outlined),
                      label: "Teams",
                    ),
                    const NavigationDestination(
                      icon: Icon(Symbols.group),
                      label: "Squad",
                    ),
                    const NavigationDestination(
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
          builder: (_) => ChatPage(eventId: eventId, eventTitle: eventTitle),
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
