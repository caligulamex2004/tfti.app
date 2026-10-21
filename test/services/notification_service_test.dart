import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
