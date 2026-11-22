import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/squad_needs_rail.dart';
import 'package:tftiapp/utils/event_service.dart';

void main() {
  group('SquadNeedsRail Widget Tests', () {
    testWidgets('Collapses cleanly when no roles exist and user cannot edit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SquadNeedsRail(
              eventId: 'non_existent_event',
              hostId: 'host_123',
              canEdit: false,
              isPast: true,
            ),
          ),
        ),
      );

      // Without currentUser or with canEdit false + empty roles, it collapses cleanly
      expect(find.text('SQUAD NEEDS'), findsNothing);
    });

    test('canClaimSquadNeed is true only for going status', () {
      expect(EventService.canClaimSquadNeed('going'), isTrue);
      expect(EventService.canClaimSquadNeed('pending'), isFalse);
      expect(EventService.canClaimSquadNeed('declined'), isFalse);
    });

    testWidgets('SquadNeedCardAction enables Claim only when canClaim is true',
        (WidgetTester tester) async {
      int claimCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadNeedCardAction(
              isClaimed: false,
              isMe: false,
              isPast: false,
              canClaim: true,
              primaryColor: Colors.blue,
              isDark: false,
              onClaim: () => claimCount++,
              onRelease: () {},
            ),
          ),
        ),
      );

      expect(find.text('Claim'), findsOneWidget);
      await tester.tap(find.text('Claim'));
      await tester.pump();
      expect(claimCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadNeedCardAction(
              isClaimed: false,
              isMe: false,
              isPast: false,
              canClaim: false,
              primaryColor: Colors.blue,
              isDark: false,
              onClaim: () => claimCount++,
              onRelease: () {},
            ),
          ),
        ),
      );

      expect(find.text('Claim'), findsNothing);
      expect(find.text('RSVP In'), findsOneWidget);
      await tester.tap(find.text('RSVP In'));
      await tester.pump();
      expect(claimCount, 1);
    });

    testWidgets('SquadNeedCardAction shows Release when claimed by me',
        (WidgetTester tester) async {
      int releaseCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadNeedCardAction(
              isClaimed: true,
              isMe: true,
              isPast: false,
              canClaim: false,
              primaryColor: Colors.blue,
              isDark: false,
              onClaim: () {},
              onRelease: () => releaseCount++,
            ),
          ),
        ),
      );

      expect(find.text('Release'), findsOneWidget);
      await tester.tap(find.text('Release'));
      await tester.pump();
      expect(releaseCount, 1);
    });
  });
}
