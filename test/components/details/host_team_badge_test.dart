import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tftiapp/components/details/host_team_badge.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

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

    testWidgets(
        'Host with specific team selected renders Last Minute Invite chip and info button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HostTeamBadge(
              currentUserId: 'host_123',
              hostId: 'host_123',
              coHostId: null,
              invitedCircles: ['circle_1'],
              inviteAll: false,
              lastMinuteInvites: ['friend_a', 'friend_b'],
              coHostInvitedCircles: null,
              coHostInviteAll: false,
              eventId: 'evt_1',
            ),
          ),
        ),
      );

      expect(find.text('VISIBLE ONLY TO YOU AS HOST'), findsOneWidget);
      expect(find.textContaining('Last Minute Invite (2)'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();

      expect(
        find.text('Select one or more to join the Crew on this one.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Co-host only sees coHostLastMinuteInvites and not host lastMinuteInvites',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HostTeamBadge(
              currentUserId: 'cohost_456',
              hostId: 'host_123',
              coHostId: 'cohost_456',
              invitedCircles: ['host_circle'],
              inviteAll: false,
              lastMinuteInvites: ['host_lmi_1', 'host_lmi_2', 'host_lmi_3'],
              coHostInvitedCircles: ['cohost_circle'],
              coHostInviteAll: false,
              coHostLastMinuteInvites: ['cohost_lmi_1'],
              eventId: 'evt_1',
            ),
          ),
        ),
      );

      expect(find.text('VISIBLE ONLY TO YOU AS CO-CAPTAIN'), findsOneWidget);
      expect(find.text('Last Minute Invite (1)'), findsOneWidget);
      expect(find.text('Last Minute Invite (3)'), findsNothing);
    });

    testWidgets(
        'Tapping Last Minute Invite chip when inviteAll is true or circles empty shows guidance snackbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HostTeamBadge(
              currentUserId: 'host_123',
              hostId: 'host_123',
              coHostId: null,
              invitedCircles: [],
              inviteAll: true,
              coHostInvitedCircles: null,
              coHostInviteAll: false,
              eventId: 'evt_1',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Last Minute Invite'));
      await tester.pump();
      expect(
        find.text('Entire Squad is selected — everyone is already invited!'),
        findsOneWidget,
      );
    });
  });
}
