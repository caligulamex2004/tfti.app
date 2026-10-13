import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/squad/squad_requests_section.dart';
import 'package:tftiapp/models/squad_request_model.dart';

void main() {
  group('SquadRequestsSection Widget Tests', () {
    final sampleRequest = SquadRequest(
      id: 'user-gary',
      fromUid: 'user-gary',
      toUid: 'user-ash',
      displayName: 'Gary Oak',
      username: 'gary_champion',
      avatarColor: Colors.purple.toARGB32(),
      createdAt: DateTime(2026, 10, 13, 10, 0),
      addedAt: DateTime(2026, 10, 13, 10, 0),
    );

    testWidgets('Renders nothing when requests list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadRequestsSection(
              requests: const [],
              onSquadUp: (_) {},
              onPass: (_) {},
              onBlock: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Squad Requests'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('Renders request items and header when requests exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadRequestsSection(
              requests: [sampleRequest],
              onSquadUp: (_) {},
              onPass: (_) {},
              onBlock: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Squad Requests (1)'), findsOneWidget);
      expect(find.text('Gary Oak'), findsOneWidget);
      expect(find.text('@gary_champion'), findsOneWidget);
      expect(find.text('Squad Up 🔥'), findsOneWidget);
      expect(find.text('Pass ✌️'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('Tapping Squad Up triggers onSquadUp callback', (WidgetTester tester) async {
      SquadRequest? squaddedUp;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadRequestsSection(
              requests: [sampleRequest],
              onSquadUp: (req) => squaddedUp = req,
              onPass: (_) {},
              onBlock: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('squad_up_button_user-gary')));
      await tester.pump();

      expect(squaddedUp, isNotNull);
      expect(squaddedUp?.fromUid, 'user-gary');
    });

    testWidgets('Tapping Pass triggers onPass callback', (WidgetTester tester) async {
      SquadRequest? passedReq;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadRequestsSection(
              requests: [sampleRequest],
              onSquadUp: (_) {},
              onPass: (req) => passedReq = req,
              onBlock: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('pass_button_user-gary')));
      await tester.pump();

      expect(passedReq, isNotNull);
      expect(passedReq?.fromUid, 'user-gary');
    });

    testWidgets('Tapping Block triggers onBlock callback', (WidgetTester tester) async {
      SquadRequest? blockedReq;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquadRequestsSection(
              requests: [sampleRequest],
              onSquadUp: (_) {},
              onPass: (_) {},
              onBlock: (req) => blockedReq = req,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('block_button_user-gary')));
      await tester.pump();

      expect(blockedReq, isNotNull);
      expect(blockedReq?.fromUid, 'user-gary');
    });
  });
}
