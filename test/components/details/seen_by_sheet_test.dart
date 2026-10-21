import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/details_bottom_sheets.dart';
import 'package:tftiapp/services/contact_resolver.dart';

void main() {
  setUp(() {
    ContactResolver.instance.clearForTest();
  });

  tearDown(() {
    ContactResolver.instance.clearForTest();
  });

  final List<Map<String, dynamic>> mockSeenGuests = [
    {
      'uid': 'user_contact',
      'displayName': 'TheRealBob',
      'username': 'bob99',
      'phoneNumber': '+15551234567',
      'avatarColor': 0xFF2196F3,
      'avatarUrl': null,
    },
    {
      'uid': 'user_no_contact',
      'displayName': 'Alice Wonderland',
      'username': 'alicew',
      'phoneNumber': '+15559876543',
      'avatarColor': 0xFF4CAF50,
      'avatarUrl': null,
    },
  ];

  Widget buildWidget(List<Map<String, dynamic>> seenGuests) {
    return MaterialApp(
      home: Scaffold(
        body: SeenBySheet(seenGuests: seenGuests),
      ),
    );
  }

  group('SeenBySheet Widget Tests', () {
    testWidgets('Renders Seen By header and divider', (tester) async {
      await tester.pumpWidget(buildWidget(mockSeenGuests));
      expect(find.text('Seen By'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('Resolves contact name as primary and shows ~ displayName as subtitle',
        (tester) async {
      ContactResolver.instance.seedForTest({
        '+15551234567': 'Bob Contact Book',
      });

      await tester.pumpWidget(buildWidget(mockSeenGuests));

      // Bob: Should show contact name as primary title, and icon
      expect(find.text('Bob Contact Book'), findsOneWidget);
      expect(find.text('~ TheRealBob (@bob99)'), findsOneWidget);
      expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);

      // Alice: No contact match, should show original displayName as primary title
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('@alicew'), findsOneWidget);
    });

    testWidgets('Renders empty list gracefully if seenGuests is empty',
        (tester) async {
      await tester.pumpWidget(buildWidget([]));
      expect(find.text('Seen By'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });
  });
}
