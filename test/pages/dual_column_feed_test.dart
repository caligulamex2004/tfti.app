import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/feed/empty_feed_states.dart';
import 'package:tftiapp/utils/event_service.dart';

void main() {
  group('Dual Column Feed & Event Deletion Tests', () {
    test('EventService.lastDeletedEventId updates and notifies listeners', () {
      String? observedId;
      void listener() {
        observedId = EventService.lastDeletedEventId.value;
      }

      EventService.lastDeletedEventId.addListener(listener);
      addTearDown(() {
        EventService.lastDeletedEventId.removeListener(listener);
        EventService.lastDeletedEventId.value = null;
      });

      expect(EventService.lastDeletedEventId.value, isNull);

      EventService.lastDeletedEventId.value = 'event_123';
      expect(observedId, equals('event_123'));

      EventService.lastDeletedEventId.value = 'event_456';
      expect(observedId, equals('event_456'));
    });

    testWidgets('FeedDetailPlaceholder renders prompt correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedDetailPlaceholder(),
          ),
        ),
      );

      expect(find.byType(FeedDetailPlaceholder), findsOneWidget);
      expect(find.text('Tap an event to view details'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsOneWidget);
    });
  });
}
