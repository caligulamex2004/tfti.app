import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/crew_attendees_rail.dart';
import 'package:tftiapp/services/contact_resolver.dart';

void main() {
  final List<Map<String, dynamic>> mockGuests = [
    {
      'uid': 'user_host',
      'displayName': 'Marcus Miller',
      'username': 'marcus',
      'status': 'going',
      'avatarColor': 0xFF2196F3,
      'avatarUrl': null,
      'hasSeen': true,
      'phoneNumber': '555-555-1001',
    },
    {
      'uid': 'user_cohost',
      'displayName': 'Sarah Connor',
      'username': 'sarah',
      'status': 'going',
      'avatarColor': 0xFF4CAF50,
      'avatarUrl': null,
      'hasSeen': true,
      'phoneNumber': '555-555-1002',
    },
    {
      'uid': 'user_pending',
      'displayName': 'David Rose',
      'username': 'david',
      'status': 'pending',
      'avatarColor': 0xFFFF9800,
      'avatarUrl': null,
      'hasSeen': false,
      'phoneNumber': '555-555-1003',
    },
  ];

  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CrewAttendeesRail(
            guests: mockGuests,
            currentUserId: 'user_host',
            hostId: 'user_host',
            coHostId: 'user_cohost',
            onAddFriend: (_, _, _) {},
            onReportUser: (_, _) {},
          ),
        ),
      ),
    );
  }

  group('CrewAttendeesRail Widget Tests', () {
    testWidgets('Renders filter chips with correct counts and default rail view',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());

      // Filter chips
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Going (2) 🔥'), findsOneWidget);
      expect(find.text('Pending (1) ⏳'), findsOneWidget);

      // Toggle button in rail mode displays "List"
      expect(find.text('List'), findsOneWidget);

      // Attendee names in rail
      expect(find.text('Marcus'), findsOneWidget);
      expect(find.text('@marcus'), findsOneWidget);
      expect(find.text('Sarah'), findsOneWidget);
      expect(find.text('@sarah'), findsOneWidget);
      expect(find.text('David'), findsOneWidget);
      expect(find.text('@david'), findsOneWidget);
    });

    testWidgets('Filtering by "Going" updates displayed attendees',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());

      // Tap on Going filter
      await tester.tap(find.text('Going (2) 🔥'));
      await tester.pumpAndSettle();

      // Going guests remain
      expect(find.text('Marcus'), findsOneWidget);
      expect(find.text('Sarah'), findsOneWidget);

      // Pending guest is filtered out
      expect(find.text('David'), findsNothing);
    });

    testWidgets('Tapping "List" switches to full list view and allows toggling back',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());

      // Tap "List" toggle
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // Toggle button should now show "Rail"
      expect(find.text('Rail'), findsOneWidget);

      // Host badge shown in list tile
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Co-Capt'), findsOneWidget);

      // Tap "Rail" toggle to go back
      await tester.tap(find.text('Rail'));
      await tester.pumpAndSettle();

      expect(find.text('List'), findsOneWidget);
    });

    testWidgets(
        'Resolves contact name as primaryName and shows ~ displayName subtitle when differing',
        (WidgetTester tester) async {
      ContactResolver.instance.seedForTest({
        '555-555-1003': 'Allen',
      });
      addTearDown(() => ContactResolver.instance.clearForTest());

      await tester.pumpWidget(buildWidget());

      // In rail: Allen is displayed as primaryName, and ~ David Rose is the subtitle
      expect(find.text('Allen'), findsOneWidget);
      expect(find.text('~ David Rose'), findsOneWidget);

      // Switch to List view
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // In list view: Allen with contact icon, and ~ David Rose (@david)
      expect(find.text('Allen'), findsOneWidget);
      expect(find.text('~ David Rose (@david)'), findsOneWidget);
      expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
    });
  });
}
