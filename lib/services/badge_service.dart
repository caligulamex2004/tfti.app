import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'badge_service_stub.dart'
    if (dart.library.html) 'badge_service_web.dart';

/// Unified badging service for Web (W3C App Badge API & browser tab title)
/// and Native Mobile (iOS APNs / Android launcher badges).
class BadgeService {
  static final BadgeService instance = BadgeService._();
  BadgeService._();

  int _badgeCount = 0;
  int get badgeCount => _badgeCount;

  /// Sets the badge count across Web and Native Mobile platforms.
  Future<void> setBadge(int count) async {
    _badgeCount = count < 0 ? 0 : count;

    if (kIsWeb) {
      setWebBadge(_badgeCount);
    } else {
      try {
        final bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
        if (isSupported) {
          if (_badgeCount > 0) {
            FlutterAppBadger.updateBadgeCount(_badgeCount);
          } else {
            FlutterAppBadger.removeBadge();
          }
        }
      } catch (e) {
        debugPrint('BadgeService mobile error: $e');
      }
    }
  }

  /// Increments the badge count by [step] (default: 1).
  Future<void> incrementBadge([int step = 1]) async {
    await setBadge(_badgeCount + step);
  }

  /// Clears the badge counter back to zero.
  Future<void> clearBadge() async {
    await setBadge(0);
  }
}
