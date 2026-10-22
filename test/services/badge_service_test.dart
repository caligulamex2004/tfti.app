import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/services/badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BadgeService Unit Tests', () {
    test('initial badge count is 0', () {
      final service = BadgeService.instance;
      expect(service.badgeCount, 0);
    });

    test('setBadge updates badge count and handles negative clamps', () async {
      final service = BadgeService.instance;
      await service.setBadge(5);
      expect(service.badgeCount, 5);

      await service.setBadge(-2);
      expect(service.badgeCount, 0);
    });

    test('incrementBadge increases count', () async {
      final service = BadgeService.instance;
      await service.setBadge(1);
      await service.incrementBadge();
      expect(service.badgeCount, 2);

      await service.incrementBadge(3);
      expect(service.badgeCount, 5);
    });

    test('clearBadge resets count to 0', () async {
      final service = BadgeService.instance;
      await service.setBadge(10);
      expect(service.badgeCount, 10);

      await service.clearBadge();
      expect(service.badgeCount, 0);
    });

    test('notifies listeners when badge count changes', () async {
      final service = BadgeService.instance;
      int notifications = 0;
      void listener() => notifications++;

      service.addListener(listener);
      await service.setBadge(3);
      expect(notifications, 1);

      await service.incrementBadge();
      expect(notifications, 2);

      await service.clearBadge();
      expect(notifications, 3);

      service.removeListener(listener);
    });
  });
}
