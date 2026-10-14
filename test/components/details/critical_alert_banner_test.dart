import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/critical_alert_banner.dart';

void main() {
  group('CriticalAlertBanner Tests', () {
    testWidgets('Renders nothing when latestCriticalChange is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CriticalAlertBanner(
              eventData: {'title': 'Regular Hangout'},
            ),
          ),
        ),
      );

      expect(find.byType(CriticalAlertBanner), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.textContaining('HEADS UP:'), findsNothing);
    });

    testWidgets('Renders alert message, changed field, and values when present', (tester) async {
      final eventData = {
        'title': 'Board Game Night',
        'latestCriticalChange': {
          'field': 'Time',
          'original': 'Oct 15, 6:00 PM',
          'new': 'Oct 15, 8:00 PM',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CriticalAlertBanner(eventData: eventData),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('HEADS UP: Time Changed!'), findsOneWidget);
      expect(find.text('Was: Oct 15, 6:00 PM\nNow: Oct 15, 8:00 PM'), findsOneWidget);
    });
  });
}
