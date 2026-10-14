import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/teams/team_card.dart';
import 'package:tftiapp/models/team_model.dart';

void main() {
  const team = TeamCircle(
    id: 'circle-warriors',
    name: 'Weekend Warriors',
    memberCount: 4,
  );

  Widget buildTeamCard({
    bool isSelected = false,
    bool isLandscape = false,
    VoidCallback? onTap,
    VoidCallback? onRename,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TeamCard(
          team: team,
          myUid: 'my-uid',
          isSelected: isSelected,
          isLandscape: isLandscape,
          onTap: onTap ?? () {},
          onRename: onRename ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    );
  }

  group('TeamCard Tests', () {
    testWidgets('Renders team name and handles tap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTeamCard(onTap: () => tapped = true),
      );

      expect(find.text('Weekend Warriors'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      await tester.tap(find.text('Weekend Warriors'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('Opening options menu and tapping Rename triggers onRename callback', (tester) async {
      bool renamed = false;

      await tester.pumpWidget(
        buildTeamCard(onRename: () => renamed = true),
      );

      // Open the options sheet
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Rename Team'), findsOneWidget);
      expect(find.text('Delete Team'), findsOneWidget);

      await tester.tap(find.text('Rename Team'));
      await tester.pumpAndSettle();

      expect(renamed, isTrue);
    });

    testWidgets('Opening options menu, selecting Delete Team and confirming calls onDelete', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        buildTeamCard(onDelete: () => deleted = true),
      );

      // Open sheet
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Delete Team option in sheet
      await tester.tap(find.text('Delete Team'));
      await tester.pumpAndSettle();

      // Verify Delete confirmation dialog
      expect(find.text('Delete Team?'), findsOneWidget);
      expect(find.text("Are you sure you want to delete 'Weekend Warriors'? Your friends will not be deleted from your account."), findsOneWidget);

      // Confirm deletion in dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });
  });
}
