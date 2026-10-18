import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/squad_needs_rail.dart';

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
  });
}
