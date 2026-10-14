import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/teams/create_team_sheet.dart';

void main() {
  group('CreateTeamSheet Tests', () {
    testWidgets('shows create team sheet and returns created id upon submission', (tester) async {
      String? returnedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedId = await CreateTeamSheet.showCreate<String>(
                    context: context,
                    onCreated: (name) async {
                      return 'new-circle-id-123';
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('New Team'), findsOneWidget);
      expect(find.text('Create Team'), findsOneWidget);

      // Enter team name
      await tester.enterText(find.byType(TextField), 'Bowling Crew');
      await tester.pump();

      // Submit
      await tester.tap(find.text('Create Team'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('New Team'), findsNothing);
      expect(returnedId, equals('new-circle-id-123'));
    });

    testWidgets('does not submit when team name is empty', (tester) async {
      bool called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await CreateTeamSheet.showCreate<String>(
                    context: context,
                    onCreated: (name) async {
                      called = true;
                      return 'circle-id';
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap Create Team with empty field
      await tester.tap(find.text('Create Team'));
      await tester.pump();

      expect(called, isFalse);
      expect(find.text('New Team'), findsOneWidget);
    });
  });
}
