import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/host_team_badge.dart';

void main() {
  group('HostTeamBadge Widget Tests', () {
    testWidgets('Guest (non-host, non-cohost) renders nothing (SizedBox.shrink)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HostTeamBadge(
              currentUserId: 'guest_123',
              hostId: 'host_456',
              coHostId: 'cohost_789',
              invitedCircles: ['circle_1'],
              inviteAll: false,
              coHostInvitedCircles: ['circle_2'],
              coHostInviteAll: false,
            ),
          ),
        ),
      );

      expect(find.byType(HostTeamBadge), findsOneWidget);
      expect(find.textContaining('VISIBLE ONLY TO YOU'), findsNothing);
      expect(find.text('Entire Squad'), findsNothing);
    });

    testWidgets('Host with inviteAll=true renders Entire Squad and Host badge',
        (WidgetTester tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostTeamBadge(
              currentUserId: 'host_123',
              hostId: 'host_123',
              coHostId: 'cohost_456',
              invitedCircles: const [],
              inviteAll: true,
              coHostInvitedCircles: const [],
              coHostInviteAll: false,
              onEditTap: () => editTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('VISIBLE ONLY TO YOU AS HOST'), findsOneWidget);
      expect(find.text('Entire Squad'), findsOneWidget);
      expect(
        find.text('All friends in your squad are invited to this hangout.'),
        findsOneWidget,
      );

      // Verify Edit tap
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      expect(editTapped, isTrue);
    });

    testWidgets(
        'Co-host with coHostInviteAll=true renders Entire Squad and Co-Captain badge',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HostTeamBadge(
              currentUserId: 'cohost_456',
              hostId: 'host_123',
              coHostId: 'cohost_456',
              invitedCircles: ['host_circle_1'],
              inviteAll: false,
              coHostInvitedCircles: [],
              coHostInviteAll: true,
            ),
          ),
        ),
      );

      expect(
        find.text('VISIBLE ONLY TO YOU AS CO-CAPTAIN'),
        findsOneWidget,
      );
      expect(find.text('Entire Squad'), findsOneWidget);
      // Ensures co-host cannot see host's circle
      expect(find.textContaining('host_circle_1'), findsNothing);
    });

    testWidgets(
        'Host with inviteAll=false and empty circles shows empty prompt',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HostTeamBadge(
              currentUserId: 'host_123',
              hostId: 'host_123',
              coHostId: null,
              invitedCircles: [],
              inviteAll: false,
              coHostInvitedCircles: null,
              coHostInviteAll: false,
            ),
          ),
        ),
      );

      expect(find.text('VISIBLE ONLY TO YOU AS HOST'), findsOneWidget);
      expect(find.text('No specific teams selected.'), findsOneWidget);
    });
  });
}
