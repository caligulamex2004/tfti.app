import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'badge_service.dart';
import 'contact_resolver.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const MethodChannel _tapChannel = MethodChannel(
    'com.bearmoose.tftiapp/notification_taps',
  );

  // Loaded at build/runtime via --dart-define-from-file=secrets.json
  static const String vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
  static bool get hasVapidKey => vapidKey.trim().isNotEmpty;

  final StreamController<RemoteMessage> _foregroundStreamController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundStreamController.stream;

  /// The ID of the event chat currently active/open on screen.
  /// Used by in-app toast overlays to suppress redundant banners for conversations
  /// the user is already viewing.
  String? activeChatEventId;

  @visibleForTesting
  void emitForegroundMessageForTesting(RemoteMessage message) {
    _foregroundStreamController.add(message);
  }

  /// Displays an in-app foreground toast banner for local app actions
  /// (e.g. Hangout creation, updates) without altering the app badge count.
  void showLocalNotification({
    required String title,
    required String body,
    String type = 'success',
    Map<String, dynamic>? data,
  }) {
    final message = RemoteMessage(
      data: {
        'title': title,
        'body': body,
        'type': type,
        'isLocal': 'true',
        ...?data,
      },
    );
    _foregroundStreamController.add(message);
  }

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  Future<void> Function(Map<String, dynamic> data)? _onNotificationTap;

  /// Registers a handler for notification taps forwarded from native Android
  /// locally-posted notifications and processes any pending launch tap.
  Future<void> registerNotificationTapHandler(
    Future<void> Function(Map<String, dynamic> data) onTap,
  ) async {
    _onNotificationTap = onTap;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    _tapChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap' && call.arguments is Map) {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        await _onNotificationTap?.call(data);
      }
    });

    try {
      final initial = await _tapChannel.invokeMethod<dynamic>(
        'getInitialNotificationTap',
      );
      if (initial is Map && initial.isNotEmpty) {
        await _onNotificationTap?.call(Map<String, dynamic>.from(initial));
      }
    } catch (e) {
      debugPrint('Error reading initial native notification tap: $e');
    }
  }

  /// Resolves localized notification title and body for person-centric push
  /// payloads (`rsvp_update`, `chat`, `chat_mention`, `whisper`) using the
  /// recipient's local address book ([ContactResolver]) and Mini Profile format.
  static ({String? title, String? body}) resolveNotificationContent(
    RemoteMessage message,
  ) {
    final data = message.data;
    final rawTitle = message.notification?.title ?? data['title']?.toString();
    final rawBody = message.notification?.body ?? data['body']?.toString();

    final type = data['type']?.toString();
    final actorName = data['actorName']?.toString();
    final actorPhone = data['actorPhone']?.toString();
    final actorUid =
        (data['actorUid'] ?? data['senderId'] ?? data['responderId'])
            ?.toString();

    final bool hasActor =
        (actorName != null && actorName.trim().isNotEmpty) ||
        (actorPhone != null && actorPhone.trim().isNotEmpty);

    if (!hasActor ||
        (type != 'rsvp_update' &&
            type != 'chat' &&
            type != 'chat_mention' &&
            type != 'whisper')) {
      return (title: rawTitle, body: rawBody);
    }

    final bool isSelf = ContactResolver.instance.isCurrentUserId(actorUid);
    final resolvedName =
        ContactResolver.instance.resolveMiniProfileName(
          actorPhone,
          fallbackName: actorName,
          isCurrentUser: isSelf,
        ) ??
        ContactResolver.instance.formatMiniProfileFallback(
          actorName,
          isCurrentUser: isSelf,
        );

    if (resolvedName.trim().isEmpty) {
      return (title: rawTitle, body: rawBody);
    }

    final eventTitle = data['eventTitle']?.toString().trim() ?? '';
    final isWhisper =
        data['isWhisper'] == 'true' ||
        type == 'whisper' ||
        (data['whisperRecipientId'] != null &&
            data['whisperRecipientId'].toString().isNotEmpty);

    if (type == 'rsvp_update') {
      final rsvpStatus = data['rsvpStatus']?.toString();
      final targetEvent =
          eventTitle.isNotEmpty ? eventTitle : 'your hangout';
      if (rsvpStatus == 'going') {
        return (
          title: 'RSVP Update ✅',
          body: '$resolvedName is going to $targetEvent',
        );
      }
      return (
        title: 'RSVP Update',
        body: "$resolvedName can't make it to $targetEvent",
      );
    }

    if (isWhisper) {
      return (
        title: eventTitle.isNotEmpty ? eventTitle : (rawTitle ?? 'Event Chat'),
        body: '🤫 $resolvedName sent you a whisper',
      );
    }

    if (type == 'chat_mention') {
      final targetEvent = eventTitle.isNotEmpty ? eventTitle : 'Event Chat';
      final msgText = data['messageText']?.toString() ?? rawBody ?? '';
      return (
        title: '$resolvedName mentioned you in $targetEvent',
        body: msgText,
      );
    }

    // Standard chat message
    final msgText = data['messageText']?.toString() ?? '';
    return (
      title: eventTitle.isNotEmpty ? eventTitle : (rawTitle ?? 'Event Chat'),
      body: msgText.isNotEmpty ? '$resolvedName: $msgText' : (rawBody ?? ''),
    );
  }

  /// Initializes listeners for foreground notifications and token refresh.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Listen for foreground push messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '📬 Foreground FCM Message: ${message.notification?.title} - ${message.notification?.body}',
      );
      BadgeService.instance.incrementBadge();
      _foregroundStreamController.add(message);
    });

    // Listen for FCM token rotations
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && newToken.isNotEmpty) {
        debugPrint('🔄 FCM token refreshed, updating Firestore...');
        await _saveTokenToFirestore(user.uid, newToken);
      }
    });
  }

  /// Checks the current authorization status without forcing a prompt.
  Future<AuthorizationStatus> getAuthorizationStatus() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('Error getting notification settings: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Explicitly requests notification permission and registers device token.
  /// Used for web opt-in buttons and mobile initialization.
  Future<bool> requestPermissionAndRegister() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint(
        'Notification permission result: ${settings.authorizationStatus}',
      );

      if (isAuthorized) {
        await syncDeviceToken();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Syncs current device token to Firestore if permitted.
  /// On Web, avoids prompting if permission is not already granted.
  Future<void> syncDeviceToken({bool forcePrompt = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final messaging = FirebaseMessaging.instance;

      if (kIsWeb) {
        final currentStatus = await getAuthorizationStatus();
        final hasPermission =
            currentStatus == AuthorizationStatus.authorized ||
            currentStatus == AuthorizationStatus.provisional;

        if (!hasPermission && !forcePrompt) {
          // Do not show cold, uninvited browser prompt on web page load
          return;
        }

        if (!hasPermission && forcePrompt) {
          final granted = await requestPermissionAndRegister();
          if (!granted) return;
        }

        if (!hasVapidKey) {
          debugPrint(
            '⚠️ Warning: FCM_WEB_VAPID_KEY is not defined in secrets.json. Web Push disabled.',
          );
          return;
        }

        final token = await messaging.getToken(vapidKey: vapidKey);
        if (token != null && token.isNotEmpty) {
          await _saveTokenToFirestore(user.uid, token);
          debugPrint('✅ Web FCM token saved successfully.');
        }
      } else {
        // Mobile platform: request permission if needed and fetch token
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _saveTokenToFirestore(user.uid, token);
          debugPrint('✅ Mobile FCM token saved successfully.');
        }
      }
    } catch (e) {
      debugPrint('FCM Token sync error: $e');
    }
  }

  /// Atomically saves the device token to the user document.
  /// Preserves both the new `fcmTokens` array and legacy `fcmToken` string.
  Future<void> _saveTokenToFirestore(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token, // Legacy fallback
        'fcmTokens': FieldValue.arrayUnion([token]), // Multi-device array
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving token to Firestore: $e');
    }
  }

  /// Cleans up current device token on user logout so the logged-out device
  /// stops receiving private notifications for this account.
  Future<void> removeTokenOnLogout(String uid) async {
    try {
      String? currentToken;
      if (kIsWeb) {
        if (hasVapidKey) {
          currentToken = await FirebaseMessaging.instance.getToken(
            vapidKey: vapidKey,
          );
        }
      } else {
        currentToken = await FirebaseMessaging.instance.getToken();
      }

      if (currentToken != null && currentToken.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([currentToken]),
        });
        debugPrint('Device token removed on logout.');
      }
    } catch (e) {
      debugPrint('Error removing token on logout: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundStreamController.close();
  }
}
