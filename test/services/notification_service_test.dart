import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tftiapp/components/shared/in_app_notification_toast.dart';
import 'package:tftiapp/components/feed/web_notification_prompt_banner.dart';
import 'package:tftiapp/services/contact_resolver.dart';
import 'package:tftiapp/services/contact_service.dart';
import 'package:tftiapp/services/notification_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContactResolver.instance.clearForTest();
  });

  tearDown(() {
    ContactResolver.instance.clearForTest();
  });

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

    testWidgets(
      'InAppNotificationToastWrapper renders rsvp_update toast with registration icon',
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
              'type': 'rsvp_update',
              'eventId': 'event-rsvp',
              'title': 'RSVP Update ✅',
              'body': 'Alice is going to Game Night',
            },
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('RSVP Update ✅'), findsOneWidget);
        expect(find.text('Alice is going to Game Night'), findsOneWidget);
        expect(find.byIcon(Icons.how_to_reg_rounded), findsOneWidget);
      },
    );

    test(
      'resolveNotificationContent uses address book name and mini profile format for rsvp_update and chat types',
      () async {
        ContactResolver.instance.seedForTest({
          '+15551234567': 'Mark Anthony Johnson',
        });

        const rsvpMsg = RemoteMessage(
          data: {
            'type': 'rsvp_update',
            'eventId': 'ev-pool',
            'eventTitle': 'Hangout by the Pool',
            'actorUid': 'user-mark',
            'actorName': 'Bob',
            'actorPhone': '+15551234567',
            'rsvpStatus': 'going',
            'title': 'RSVP Update ✅',
            'body': 'Bob is going to Hangout by the Pool',
          },
        );

        // Default miniProfileFormat is firstName -> "Mark"
        final firstRes = NotificationService.resolveNotificationContent(rsvpMsg);
        expect(firstRes.title, 'RSVP Update ✅');
        expect(firstRes.body, 'Mark is going to Hangout by the Pool');

        // firstNameLastInitial -> "Mark J."
        await ContactResolver.instance.setMiniProfileFormat(
          DisplayNameFormat.firstNameLastInitial,
        );
        final initialRes =
            NotificationService.resolveNotificationContent(rsvpMsg);
        expect(initialRes.body, 'Mark J. is going to Hangout by the Pool');

        // fullName -> "Mark Anthony Johnson"
        await ContactResolver.instance.setMiniProfileFormat(
          DisplayNameFormat.fullName,
        );
        final fullRes = NotificationService.resolveNotificationContent(rsvpMsg);
        expect(
          fullRes.body,
          'Mark Anthony Johnson is going to Hangout by the Pool',
        );

        // givenName -> "Mark Anthony"
        await ContactResolver.instance.setMiniProfileFormat(
          DisplayNameFormat.givenName,
        );
        final givenRes = NotificationService.resolveNotificationContent(rsvpMsg);
        expect(givenRes.body, 'Mark Anthony is going to Hangout by the Pool');

        // Reset to firstName and verify chat, chat_mention, whisper
        await ContactResolver.instance.setMiniProfileFormat(
          DisplayNameFormat.firstName,
        );

        final chatRes = NotificationService.resolveNotificationContent(
          const RemoteMessage(
            data: {
              'type': 'chat',
              'eventId': 'ev-pool',
              'eventTitle': 'Hangout by the Pool',
              'actorName': 'Bob',
              'actorPhone': '+15551234567',
              'messageText': 'On my way!',
            },
          ),
        );
        expect(chatRes.title, 'Hangout by the Pool');
        expect(chatRes.body, 'Mark: On my way!');

        final mentionRes = NotificationService.resolveNotificationContent(
          const RemoteMessage(
            data: {
              'type': 'chat_mention',
              'eventId': 'ev-pool',
              'eventTitle': 'Hangout by the Pool',
              'actorName': 'Bob',
              'actorPhone': '+15551234567',
              'messageText': '@you bring sunscreen',
            },
          ),
        );
        expect(mentionRes.title, 'Mark mentioned you in Hangout by the Pool');
        expect(mentionRes.body, '@you bring sunscreen');

        final whisperRes = NotificationService.resolveNotificationContent(
          const RemoteMessage(
            data: {
              'type': 'chat',
              'isWhisper': 'true',
              'eventId': 'ev-pool',
              'eventTitle': 'Hangout by the Pool',
              'actorName': 'Bob',
              'actorPhone': '+15551234567',
            },
          ),
        );
        expect(whisperRes.title, 'Hangout by the Pool');
        expect(whisperRes.body, '🤫 Mark sent you a whisper');
      },
    );

    test(
      'resolveNotificationContent applies mini profile format to fallback displayName when unmatched',
      () async {
        await ContactResolver.instance.setMiniProfileFormat(
          DisplayNameFormat.firstName,
        );
        final fallbackRes = NotificationService.resolveNotificationContent(
          const RemoteMessage(
            data: {
              'type': 'rsvp_update',
              'eventId': 'ev-pool',
              'eventTitle': 'Hangout by the Pool',
              'actorName': 'Bob Smith',
              'actorPhone': '+19998887777',
              'rsvpStatus': 'declined',
            },
          ),
        );
        expect(fallbackRes.title, 'RSVP Update');
        expect(fallbackRes.body, "Bob can't make it to Hangout by the Pool");
      },
    );

    testWidgets(
      'InAppNotificationToastWrapper renders resolved address book name for rsvp_update',
      (WidgetTester tester) async {
        ContactResolver.instance.seedForTest({'+15551234567': 'Mark Johnson'});

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
              'type': 'rsvp_update',
              'eventId': 'event-pool',
              'eventTitle': 'Hangout by the Pool',
              'actorName': 'Bob',
              'actorPhone': '+15551234567',
              'rsvpStatus': 'going',
              'title': 'RSVP Update ✅',
              'body': 'Bob is going to Hangout by the Pool',
            },
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('RSVP Update ✅'), findsOneWidget);
        expect(find.text('Mark is going to Hangout by the Pool'), findsOneWidget);
        expect(find.text('Bob is going to Hangout by the Pool'), findsNothing);
      },
    );
  });
}
