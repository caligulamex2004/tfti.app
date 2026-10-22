import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/event_summary_card.dart';
import 'package:tftiapp/models/event_model.dart';
import 'package:tftiapp/models/invitation_model.dart';

void main() {
  group('EventSummaryCard Overflow Regression Tests', () {
    final testEvent = Event(
      id: 'event-overflow-test',
      type: 'event',
      hostId: 'host-1',
      title: 'Taco Fest Meetup with a Long Title That Might Wrap',
      location: '123 Cantina Blvd, Downtown',
      details: 'Meeting up for lunch',
      time: DateTime.now().add(const Duration(days: 2)),
      isPast: false,
    );

    const testInvitation = Invitation(
      uid: 'user-1',
      eventId: 'event-overflow-test',
      status: 'pending',
    );

    testWidgets('Does not overflow under exact Carousel constraints (w=344.7, h=238.0)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344.7,
                height: 238.0,
                child: EventSummaryCard.fromModel(
                  event: testEvent,
                  invitation: testInvitation,
                  myUid: 'user-1',
                  isLandscape: false,
                  isHorizontal: true,
                  isSelected: false,
                  onTap: () {},
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no RenderFlex overflow exception was thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(EventSummaryCard), findsOneWidget);
    });

    testWidgets('Does not overflow on larger devices (w=390, h=240 or h=248)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390.0,
                height: 240.0,
                child: EventSummaryCard.fromModel(
                  event: testEvent,
                  invitation: testInvitation,
                  myUid: 'user-1',
                  isLandscape: false,
                  isHorizontal: true,
                  isSelected: false,
                  onTap: () {},
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(EventSummaryCard), findsOneWidget);
    });
  });
}
