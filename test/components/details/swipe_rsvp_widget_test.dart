import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/swipe_rsvp_widget.dart';

void main() {
  Widget buildWidget({
    required String currentStatus,
    bool isLocked = false,
    required Function(String) onRsvp,
    double width = 360,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SwipeRsvpWidget(
              currentStatus: currentStatus,
              isLocked: isLocked,
              onRsvp: onRsvp,
            ),
          ),
        ),
      ),
    );
  }

  group('SwipeRsvpWidget Tests', () {
    testWidgets('Locked & Pending state renders RSVP Closed banner and disables swipe', (tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          currentStatus: 'pending',
          isLocked: true,
          onRsvp: (val) => rsvpResult = val,
        ),
      );

      expect(find.text('RSVP Closed'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('SWIPE'), findsNothing);
      expect(rsvpResult, isNull);
    });

    testWidgets('Going state renders "You\'re in! 🤗" and "Change" button resets to pending', (tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          currentStatus: 'going',
          isLocked: false,
          onRsvp: (val) => rsvpResult = val,
        ),
      );

      expect(find.text("You're in! 🤗"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      await tester.tap(find.text('Change'));
      await tester.pump();

      expect(rsvpResult, 'pending');
    });

    testWidgets('Declined state renders "You\'re missing out." and "Change" resets to pending', (tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          currentStatus: 'declined',
          isLocked: false,
          onRsvp: (val) => rsvpResult = val,
        ),
      );

      expect(find.text("You're missing out."), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      await tester.tap(find.text('Change'));
      await tester.pump();

      expect(rsvpResult, 'pending');
    });

    testWidgets('Compact Pending mode (< 280px) renders discrete Decline and I\'m In! buttons', (tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          currentStatus: 'pending',
          isLocked: false,
          onRsvp: (val) => rsvpResult = val,
          width: 260, // Compact threshold is < 280
        ),
      );

      expect(find.text('Decline'), findsOneWidget);
      expect(find.text("I'm In!"), findsOneWidget);
      expect(find.text('SWIPE'), findsNothing);

      await tester.tap(find.text("I'm In!"));
      await tester.pump();
      expect(rsvpResult, 'going');

      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(rsvpResult, 'declined');
    });

    testWidgets('Full Pending slider mode drag right triggers going status', (tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          currentStatus: 'pending',
          isLocked: false,
          onRsvp: (val) => rsvpResult = val,
          width: 360,
        ),
      );

      expect(find.text("« I'M OUT"), findsOneWidget);
      expect(find.text("LET'S GO »"), findsOneWidget);
      expect(find.text('SWIPE'), findsOneWidget);

      // Dragging right (> 70% threshold)
      await tester.drag(find.text('SWIPE'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(rsvpResult, 'going');
    });

    testWidgets('Full Pending slider mode drag left triggers declined status', (tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          currentStatus: 'pending',
          isLocked: false,
          onRsvp: (val) => rsvpResult = val,
          width: 360,
        ),
      );

      // Dragging left (< -70% threshold)
      await tester.drag(find.text('SWIPE'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(rsvpResult, 'declined');
    });

    testWidgets('Full Pending slider mode small nudge below threshold snaps back without RSVP trigger', (tester) async {
      String? rsvpResult;

      await tester.pumpWidget(
        buildWidget(
          currentStatus: 'pending',
          isLocked: false,
          onRsvp: (val) => rsvpResult = val,
          width: 360,
        ),
      );

      // Small nudge below 70% threshold snaps back
      await tester.drag(find.text('SWIPE'), const Offset(20, 0));
      await tester.pumpAndSettle();
      expect(rsvpResult, isNull);
    });
  });
}
