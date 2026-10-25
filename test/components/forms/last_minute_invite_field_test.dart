import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tftiapp/components/forms/last_minute_invite_field.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('LastMinuteInviteField Widget Tests', () {
    testWidgets(
      'Renders SizedBox.shrink when no user is authenticated and userUidOverride is null',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LastMinuteInviteField(
                inviteAll: false,
                selectedCircleIds: const ['circle_1'],
                lastMinuteInviteIds: const [],
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Last Minute Invite'), findsNothing);
      },
    );

    testWidgets(
      'Disabled (opacity 0.5) when inviteAll is true and shows snackbar on tap',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LastMinuteInviteField(
                userUidOverride: 'user_123',
                inviteAll: true,
                selectedCircleIds: const [],
                lastMinuteInviteIds: const [],
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Last Minute Invite'), findsOneWidget);
        expect(find.text('Entire Squad Invited'), findsOneWidget);

        final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacityWidget.opacity, 0.5);

        await tester.tap(find.text('Entire Squad Invited'));
        await tester.pump();

        expect(
          find.text('Entire Squad is selected — everyone is already invited!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Disabled (opacity 0.5) when selectedCircleIds is empty and shows snackbar on tap',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LastMinuteInviteField(
                userUidOverride: 'user_123',
                inviteAll: false,
                selectedCircleIds: const [],
                lastMinuteInviteIds: const [],
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Last Minute Invite'), findsOneWidget);
        expect(find.text('Select a Team first...'), findsOneWidget);

        final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacityWidget.opacity, 0.5);

        await tester.tap(find.text('Select a Team first...'));
        await tester.pump();

        expect(find.text('Please select a Team first.'), findsOneWidget);
      },
    );

    testWidgets(
      'Enabled (opacity 1.0) when a Team is selected and shows info message on info icon tap',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LastMinuteInviteField(
                userUidOverride: 'user_123',
                inviteAll: false,
                selectedCircleIds: const ['circle_1'],
                lastMinuteInviteIds: const [],
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Last Minute Invite'), findsOneWidget);
        expect(find.text('None selected'), findsOneWidget);

        final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacityWidget.opacity, 1.0);

        await tester.tap(find.byIcon(Icons.info_outline));
        await tester.pump();

        expect(
          find.text('Select one or more to join the Crew on this one.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Shows fallback count when lastMinuteInviteIds is non-empty',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LastMinuteInviteField(
                userUidOverride: 'user_123',
                inviteAll: false,
                selectedCircleIds: const ['circle_1'],
                lastMinuteInviteIds: const ['friend_1', 'friend_2'],
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('2 Selected'), findsOneWidget);
      },
    );
  });
}
