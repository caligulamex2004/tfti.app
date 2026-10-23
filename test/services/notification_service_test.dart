import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tftiapp/components/shared/in_app_notification_toast.dart';
import 'package:tftiapp/components/feed/web_notification_prompt_banner.dart';
import 'package:tftiapp/services/notification_service.dart';

void main() {
  group('NotificationService & Hybrid Web Notification Tests', () {
    test('NotificationService singleton initializes correctly', () {
      final service = NotificationService.instance;
      expect(service, isNotNull);
      expect(NotificationService.vapidKey, isA<String>());
      expect(NotificationService.hasVapidKey, isA<bool>());
    });

    test('activeChatEventId property sets and clears properly', () {
      final service = NotificationService.instance;
      expect(service.activeChatEventId, isNull);

      service.activeChatEventId = 'event-123';
      expect(service.activeChatEventId, equals('event-123'));

      service.activeChatEventId = null;
      expect(service.activeChatEventId, isNull);
    });

    test('showLocalNotification emits message on onForegroundMessage stream', () async {
      final service = NotificationService.instance;
      expectLater(
        service.onForegroundMessage,
        emits(
          predicate<RemoteMessage>((m) {
            return m.data['title'] == "It's official! 🚀" &&
                m.data['body'] == "Your crew has been notified! 📨" &&
                m.data['type'] == 'success';
          }),
        ),
      );

      service.showLocalNotification(
        title: "It's official! 🚀",
        body: "Your crew has been notified! 📨",
        type: 'success',
      );
    });

    testWidgets(
      'InAppNotificationToastWrapper renders child widget correctly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: InAppNotificationToastWrapper(
              child: const Scaffold(
                body: Center(child: Text('Main Content')),
              ),
            ),
          ),
        );

        expect(find.text('Main Content'), findsOneWidget);
      },
    );

    testWidgets(
      'InAppNotificationToastWrapper renders whisper toast with badge and lock icon',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: InAppNotificationToastWrapper(
              privacyFilter: (_) async => true,
              child: const Scaffold(
                body: Center(child: Text('Main Content')),
              ),
            ),
          ),
        );

        NotificationService.instance.emitForegroundMessageForTesting(
          const RemoteMessage(
            data: {
              'type': 'chat',
              'eventId': 'event-abc',
              'isWhisper': 'true',
              'title': 'Board Game Night',
              'body': '🤫 Alice sent you a whisper',
            },
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Board Game Night'), findsOneWidget);
        expect(find.text('🤫 Alice sent you a whisper'), findsOneWidget);
        expect(find.text('Whisper'), findsOneWidget);
        expect(find.byIcon(Icons.hearing_outlined), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'InAppNotificationToastWrapper suppresses toast when privacy filter rejects message',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: InAppNotificationToastWrapper(
              privacyFilter: (_) async => false, // Suppressed by privacy check
              child: const Scaffold(
                body: Center(child: Text('Main Content')),
              ),
            ),
          ),
        );

        NotificationService.instance.emitForegroundMessageForTesting(
          const RemoteMessage(
            data: {
              'type': 'chat',
              'eventId': 'event-abc',
              'isWhisper': 'true',
              'title': 'Secret Hangout',
              'body': '🤫 Secret whisper for someone else',
            },
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Secret Hangout'), findsNothing);
        expect(find.text('Whisper'), findsNothing);
      },
    );

    testWidgets(
      'WebNotificationPromptBanner returns SizedBox.shrink on non-web platform',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: WebNotificationPromptBanner(),
            ),
          ),
        );

        await tester.pump();
        // On non-web test harness, the banner should not render
        expect(find.text('Stay in the loop'), findsNothing);
      },
    );
  });
}
