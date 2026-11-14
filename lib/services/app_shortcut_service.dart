import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// Canonical home-screen / Dock / PWA app icon shortcut actions.
enum AppShortcutAction {
  planHangout('plan_hangout'),
  vibeCheck('vibe_check'),
  scanQr('scan_qr'),
  squad('squad');

  final String id;
  const AppShortcutAction(this.id);

  /// Parses a shortcut type string from native quick actions or Web URL params.
  static AppShortcutAction? fromId(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    for (final action in values) {
      if (action.id == normalized) return action;
    }
    return null;
  }
}

/// Centralized handler for home-screen / Dock / PWA app icon shortcuts across
/// iOS, Android, and Web.
class AppShortcutService {
  static final AppShortcutService instance = AppShortcutService._();
  AppShortcutService._();

  /// Holds the latest unconsumed shortcut action requested via app launch or
  /// quick-action tap so `MainShell` can navigate once mounted and signed in.
  final ValueNotifier<AppShortcutAction?> pendingAction =
      ValueNotifier<AppShortcutAction?>(null);

  /// Trigger counter listened to by `SquadPage` to open the QR scanner tab.
  final ValueNotifier<int> scanQrTrigger = ValueNotifier<int>(0);

  bool _initialized = false;

  static const List<ShortcutItem> nativeShortcutItems = <ShortcutItem>[
    ShortcutItem(
      type: 'plan_hangout',
      localizedTitle: 'Plan Hangout',
      icon: 'shortcut_hangout',
    ),
    ShortcutItem(
      type: 'vibe_check',
      localizedTitle: 'Vibe Check',
      icon: 'shortcut_vibe',
    ),
    ShortcutItem(
      type: 'scan_qr',
      localizedTitle: 'Scan QR Code',
      icon: 'shortcut_qr',
    ),
    ShortcutItem(
      type: 'squad',
      localizedTitle: 'My Squad',
      icon: 'shortcut_squad',
    ),
  ];

  /// Initializes platform shortcut listeners and registers native iOS/Android
  /// home-screen Quick Actions, or inspects Web query parameters (`?shortcut=`).
  Future<void> init({
    Uri? initialWebUri,
    QuickActions? quickActionsOverride,
    bool? isWebOverride,
    TargetPlatform? platformOverride,
  }) async {
    if (_initialized) return;
    _initialized = true;

    final bool runningOnWeb = isWebOverride ?? kIsWeb;
    if (runningOnWeb) {
      final uri = initialWebUri ?? Uri.base;
      final action = AppShortcutAction.fromId(uri.queryParameters['shortcut']);
      if (action != null) {
        dispatch(action);
      }
      return;
    }

    final platform = platformOverride ?? defaultTargetPlatform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      return;
    }

    try {
      final QuickActions quickActions =
          quickActionsOverride ?? const QuickActions();
      await quickActions.initialize((String shortcutType) {
        final action = AppShortcutAction.fromId(shortcutType);
        if (action != null) {
          dispatch(action);
        }
      });
      await quickActions.setShortcutItems(nativeShortcutItems);
    } catch (e) {
      debugPrint('AppShortcutService init skipped: $e');
    }
  }

  /// Dispatches [action] to listeners (`MainShell`).
  void dispatch(AppShortcutAction action) {
    pendingAction.value = action;
  }

  /// Consumes and clears the pending shortcut action, returning null if none.
  AppShortcutAction? consumePendingAction() {
    final action = pendingAction.value;
    pendingAction.value = null;
    return action;
  }

  /// Signals `SquadPage` to open [QrDuoSheet] directly on the Scan Code tab.
  void requestOpenQrScanner() {
    scanQrTrigger.value++;
  }

  /// Resets internal state for unit tests.
  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    pendingAction.value = null;
    scanQrTrigger.value = 0;
  }
}
