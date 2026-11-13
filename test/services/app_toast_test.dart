import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tftiapp/components/shared/in_app_notification_toast.dart';
import 'package:tftiapp/services/app_toast.dart';
import 'package:tftiapp/services/badge_service.dart';
import 'package:tftiapp/services/notification_service.dart';

void main() {
  setUp(() {
    const badgeChannel = MethodChannel('app_badge_plus');
    const notifChannel = MethodChannel('com.bearmoose.tftiapp/notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(badgeChannel, (call) async {
      if (call.method == 'isSupported') return false;
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifChannel, (call) async => null);
  });

  Widget wrapWithToast(
    Widget child, {
    Future<bool> Function(RemoteMessage message)? privacyFilter,
  }) {
    return MaterialApp(
      builder: (context, inner) => InAppNotificationToastWrapper(
        privacyFilter: privacyFilter,
        child: inner ?? const SizedBox.shrink(),
      ),
      home: child,
    );
  }

  group('AppToast & InAppNotificationToastWrapper Tests', () {
    test('AppToast emits typed messages on onToast stream', () async {
      expectLater(
        AppToast.onToast,
        emitsInOrder([
          predicate<AppToastMessage>(
            (m) =>
                m.type == AppToastType.success &&
                m.message == 'Saved!' &&
                m.title == 'Done',
          ),
          predicate<AppToastMessage>(
            (m) =>
                m.type == AppToastType.error &&
                m.message == 'Something failed' &&
                m.title == null,
          ),
          predicate<AppToastMessage>(
            (m) => m.type == AppToastType.warning && m.message == 'Check input',
          ),
          predicate<AppToastMessage>(
            (m) => m.type == AppToastType.info && m.message == 'Heads up',
          ),
        ]),
      );

      AppToast.success('Saved!', title: 'Done');
      AppToast.error('Something failed');
      AppToast.warning('Check input');
      AppToast.info('Heads up');
    });

    testWidgets('Renders single-line and titled semantic toasts cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWithToast(const Scaffold(body: Center(child: Text('Home')))),
      );

      AppToast.success('Copied to clipboard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Copied to clipboard'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      // Replacing with an error toast with a title swaps immediately
      AppToast.error('Please try again.', title: 'Upload Failed');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Copied to clipboard'), findsNothing);
      expect(find.text('Upload Failed'), findsOneWidget);
      expect(find.text('Please try again.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Auto-dismisses after duration
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Upload Failed'), findsNothing);
    });

    testWidgets('Action button triggers callback and dismisses toast', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWithToast(const Scaffold(body: Center(child: Text('Home')))),
      );

      AppToast.warning(
        'Connection lost',
        actionLabel: 'Retry',
        onAction: () => tapped = true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(find.text('Connection lost'), findsNothing);
    });

    testWidgets(
      'Local AppToast dismissal does not clear unread push badge count',
      (WidgetTester tester) async {
        await BadgeService.instance.setBadge(3);
        expect(BadgeService.instance.badgeCount, equals(3));

        await tester.pumpWidget(
          wrapWithToast(const Scaffold(body: Center(child: Text('Home')))),
        );

        AppToast.info('Event hidden.', duration: const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(BadgeService.instance.badgeCount, equals(3));
        await BadgeService.instance.clearBadge();
      },
    );

    testWidgets(
      'Push notification dismissal clears unread push badge count',
      (WidgetTester tester) async {
        await BadgeService.instance.setBadge(2);
        expect(BadgeService.instance.badgeCount, equals(2));

        await tester.pumpWidget(
          wrapWithToast(
            const Scaffold(body: Center(child: Text('Home'))),
            privacyFilter: (_) async => true,
          ),
        );

        NotificationService.instance.emitForegroundMessageForTesting(
          const RemoteMessage(
            messageId: 'push_msg_1',
            data: {
              'type': 'invite',
              'title': 'New Hangout',
              'body': 'You were invited!',
            },
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('New Hangout'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(BadgeService.instance.badgeCount, equals(0));
      },
    );
  });
}
