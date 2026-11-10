import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'badge_service_stub.dart'
    if (dart.library.html) 'badge_service_web.dart';

/// Unified badging service for Web (W3C App Badge API & browser tab title)
/// and Native Mobile (iOS APNs / Android launcher badges & system tray).
class BadgeService extends ChangeNotifier {
  static final BadgeService instance = BadgeService._();
  BadgeService._();

  static const MethodChannel _androidChannel =
      MethodChannel('com.bearmoose.tftiapp/notifications');

  int _badgeCount = 0;
  int get badgeCount => _badgeCount;

  /// Sets the badge count across Web and Native Mobile platforms.
  Future<void> setBadge(int count) async {
    final int newCount = count < 0 ? 0 : count;
    if (_badgeCount == newCount) return;
    _badgeCount = newCount;
    notifyListeners();

    if (kIsWeb) {
      setWebBadge(_badgeCount);
    } else {
      try {
        final bool isSupported = await AppBadgePlus.isSupported();
        if (isSupported) {
          await AppBadgePlus.updateBadge(_badgeCount);
        }
      } catch (e) {
        debugPrint('BadgeService mobile error: $e');
      }

      if (_badgeCount == 0 && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _androidChannel.invokeMethod('cancelAllNotifications');
        } catch (e) {
          debugPrint('BadgeService android cancelAllNotifications error: $e');
        }
      }
    }
  }

  /// Increments the badge count by [step] (default: 1).
  Future<void> incrementBadge([int step = 1]) async {
    await setBadge(_badgeCount + step);
  }

  /// Clears the badge counter back to zero and cancels active mobile notifications.
  Future<void> clearBadge() async {
    await setBadge(0);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidChannel.invokeMethod('cancelAllNotifications');
      } catch (e) {
        debugPrint('BadgeService android cancelAllNotifications error: $e');
      }
    }
  }
}
