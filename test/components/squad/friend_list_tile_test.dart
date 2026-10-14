import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tftiapp/components/squad/friend_list_tile.dart';

void main() {
  final sampleUserData = {
    'uid': 'user-brock',
    'displayName': 'Brock',
    'username': 'pewter_gym',
    'avatarColor': Colors.blue.toARGB32(),
    'hp': 85,
    'mana': 40,
  };

  Widget buildTile({
    Map<String, dynamic>? userData,
    bool isGoated = false,
    bool isBlocked = false,
    bool sortByScore = false,
    Future<bool> Function(DismissDirection)? confirmDismiss,
    Function(DismissDirection)? onDismissed,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FriendListTile(
          userData: userData ?? sampleUserData,
          currentUserId: 'my-uid',
          isGoated: isGoated,
          isBlocked: isBlocked,
          sortByScore: sortByScore,
          confirmDismiss: confirmDismiss ?? (_) async => true,
          onDismissed: onDismissed ?? (_) {},
        ),
      ),
    );
  }

  group('FriendListTile Tests', () {
    testWidgets('Renders display name, username, and initials avatar', (tester) async {
      await tester.pumpWidget(buildTile());

      expect(find.text('Brock'), findsOneWidget);
      expect(find.text('@pewter_gym'), findsOneWidget);
      expect(find.text('B'), findsOneWidget); // Initial in CircleAvatar
      expect(find.byIcon(Symbols.star), findsNothing);
      expect(find.byIcon(Icons.block), findsNothing);
    });

    testWidgets('Renders goated star icon when friend isGoated is true', (tester) async {
      await tester.pumpWidget(buildTile(isGoated: true));

      expect(find.text('Brock'), findsOneWidget);
      expect(find.byIcon(Symbols.star), findsOneWidget);
      expect(find.byIcon(Icons.block), findsNothing);
    });

    testWidgets('Renders block icon when friend isBlocked is true', (tester) async {
      await tester.pumpWidget(buildTile(isBlocked: true));

      expect(find.text('Brock'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(find.byIcon(Symbols.star), findsNothing);
    });

    testWidgets('Renders HP and Mana score columns when sortByScore is true', (tester) async {
      await tester.pumpWidget(buildTile(sortByScore: true));

      expect(find.text('85'), findsOneWidget); // HP
      expect(find.text('40'), findsOneWidget); // Mana
    });

    testWidgets('Swipe to dismiss triggers confirmDismiss and onDismissed', (tester) async {
      bool confirmCalled = false;
      bool dismissedCalled = false;

      await tester.pumpWidget(
        buildTile(
          confirmDismiss: (_) async {
            confirmCalled = true;
            return true;
          },
          onDismissed: (_) {
            dismissedCalled = true;
          },
        ),
      );

      // Drag from right to left to trigger dismissal
      await tester.drag(find.text('Brock'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(confirmCalled, isTrue);
      expect(dismissedCalled, isTrue);
    });
  });
}
