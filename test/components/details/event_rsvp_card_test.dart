import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/event_rsvp_card.dart';

void main() {
  // Fixed future event: next Friday at 6:00 PM (18:00)
  final DateTime futureFriday = DateTime(2027, 5, 21, 18, 0);

  Widget buildWidget({
    required String myStatus,
    bool isPast = false,
    bool isVibeCheck = false,
    DateTime? eventTime,
    int deadlineOffset = 0,
    Future<List<Map<String, dynamic>>>? cachedCrewFuture,
    required Function(String) onRsvp,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EventRsvpCard(
            isVibeCheck: isVibeCheck,
            eventId: 'event_123',
            eventData: {
              'title': 'Friday Night Hangout',
              'time': eventTime ?? futureFriday,
              'rsvpDeadline': deadlineOffset,
            },
            myInviteData: {
              'uid': 'user_me',
              'status': myStatus,
            },
            myStatus: myStatus,
            myUid: 'user_me',
            isMainHost: false,
            isPast: isPast,
            cachedCrewFuture: cachedCrewFuture,
            onRsvp: onRsvp,
          ),
        ),
      ),
    );
  }

  group('EventRsvpCard Widget Tests', () {
    testWidgets('Pending state renders "Can You Make It?", deadline text, and Slide 5 buttons',
        (WidgetTester tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          myStatus: 'pending',
          eventTime: futureFriday,
          onRsvp: (status) => rsvpResult = status,
        ),
      );

      // Card Header
      expect(find.text('CAN YOU MAKE IT?'), findsOneWidget);

      // Deadline text format: "Let the crew know by Fri @ 6:00 PM"
      expect(find.text('Let the crew know by Fri @ 6:00 PM'), findsOneWidget);

      // Action buttons
      expect(find.text('Count Me In ✓'), findsOneWidget);
      expect(find.text("Can't Make It"), findsOneWidget);

      // Tap Count Me In ✓
      await tester.tap(find.text('Count Me In ✓'));
      await tester.pump();
      expect(rsvpResult, 'going');

      // Tap Can't Make It
      await tester.tap(find.text("Can't Make It"));
      await tester.pump();
      expect(rsvpResult, 'declined');
    });

    testWidgets('Going state renders "You\'re on the list ✓" and "Change" action',
        (WidgetTester tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          myStatus: 'going',
          eventTime: futureFriday,
          onRsvp: (status) => rsvpResult = status,
        ),
      );

      expect(find.text("You're on the list ✓"), findsOneWidget);
      expect(find.text("Ready for the hangout"), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      // Tapping Change resets to pending
      await tester.tap(find.text('Change'));
      await tester.pump();
      expect(rsvpResult, 'pending');
    });

    testWidgets('Declined state renders "Can\'t make it this time" and "Count Me In ✓"',
        (WidgetTester tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          myStatus: 'declined',
          eventTime: futureFriday,
          onRsvp: (status) => rsvpResult = status,
        ),
      );

      expect(find.text("Can't make it this time"), findsOneWidget);
      expect(find.text('Count Me In ✓'), findsOneWidget);

      // Tapping Count Me In ✓ calls going
      await tester.tap(find.text('Count Me In ✓'));
      await tester.pump();
      expect(rsvpResult, 'going');
    });

    testWidgets('Locked / Past state renders "Responses closed"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildWidget(
          myStatus: 'pending',
          isPast: true,
          eventTime: DateTime(2025, 1, 1),
          onRsvp: (_) {},
        ),
      );

      expect(find.text('Responses closed'), findsAtLeastNWidgets(1));
      expect(find.text('The crew list has been finalized.'), findsOneWidget);
      expect(find.text('Count Me In ✓'), findsNothing);
    });

    testWidgets('Locked state when user is going preserves "You\'re on the list ✓"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildWidget(
          myStatus: 'going',
          isPast: true,
          eventTime: DateTime(2025, 1, 1),
          onRsvp: (_) {},
        ),
      );

      expect(find.text("You're on the list ✓"), findsOneWidget);
      expect(find.text('Responses closed • See you there'), findsOneWidget);
      // Change button is NOT shown once responses are finalized
      expect(find.text('Change'), findsNothing);
    });

    testWidgets('Social proof and header count pill display going guests',
        (WidgetTester tester) async {
      final mockGuestsFuture = Future.value(<Map<String, dynamic>>[
        {
          'uid': 'user_1',
          'displayName': 'Alex',
          'status': 'going',
          'avatarColor': 0xFF2196F3,
          'avatarUrl': null,
        },
        {
          'uid': 'user_2',
          'displayName': 'Jordan',
          'status': 'going',
          'avatarColor': 0xFF4CAF50,
          'avatarUrl': null,
        },
        {
          'uid': 'user_3',
          'displayName': 'Taylor',
          'status': 'pending',
          'avatarColor': 0xFFFF9800,
          'avatarUrl': null,
        },
      ]);

      await tester.pumpWidget(
        buildWidget(
          myStatus: 'pending',
          eventTime: futureFriday,
          cachedCrewFuture: mockGuestsFuture,
          onRsvp: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Header pill: "2 In"
      expect(find.text('2 In'), findsOneWidget);

      // Social proof text: "Alex and Jordan are in"
      expect(find.text('Alex and Jordan are in'), findsOneWidget);
    });

    testWidgets(
        'Pending state does not overflow in narrow container (e.g. 220px width)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: EventRsvpCard(
                  isVibeCheck: false,
                  eventId: 'event_123',
                  eventData: {
                    'title': 'Narrow Test',
                    'time': futureFriday,
                  },
                  myInviteData: const {'uid': 'user_me', 'status': 'pending'},
                  myStatus: 'pending',
                  myUid: 'user_me',
                  isMainHost: false,
                  isPast: false,
                  cachedCrewFuture: null,
                  onRsvp: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Count Me In ✓'), findsOneWidget);
      expect(find.text("Can't Make It"), findsOneWidget);
    });

    testWidgets(
        'Declined state does not overflow in narrow container (e.g. 200px width)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: EventRsvpCard(
                  isVibeCheck: false,
                  eventId: 'event_123',
                  eventData: {
                    'title': 'Narrow Declined Test',
                    'time': futureFriday,
                  },
                  myInviteData: const {'uid': 'user_me', 'status': 'declined'},
                  myStatus: 'declined',
                  myUid: 'user_me',
                  isMainHost: false,
                  isPast: false,
                  cachedCrewFuture: null,
                  onRsvp: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text("Can't make it this time"), findsOneWidget);
      expect(find.text('Count Me In ✓'), findsOneWidget);
    });

    testWidgets(
        'Going state does not overflow in narrow container (e.g. 200px width)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: EventRsvpCard(
                  isVibeCheck: false,
                  eventId: 'event_123',
                  eventData: {
                    'title': 'Narrow Going Test',
                    'time': futureFriday,
                  },
                  myInviteData: const {'uid': 'user_me', 'status': 'going'},
                  myStatus: 'going',
                  myUid: 'user_me',
                  isMainHost: false,
                  isPast: false,
                  cachedCrewFuture: null,
                  onRsvp: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text("You're on the list ✓"), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });
  });
}
