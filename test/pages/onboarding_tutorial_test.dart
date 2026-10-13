import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tftiapp/pages/onboarding_tutorial.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTutorialApp({required VoidCallback onComplete}) {
    return MaterialApp(
      home: OnboardingTutorial(onComplete: onComplete),
    );
  }

  testWidgets('OnboardingTutorial renders first slide and advances to all slides',
      (tester) async {
    bool completed = false;

    await tester.pumpWidget(
      buildTutorialApp(
        onComplete: () {
          completed = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Slide 1: Welcome
    expect(find.text("Welcome to TFTI!"), findsOneWidget);
    expect(find.text("Next"), findsOneWidget);
    expect(find.text("Skip"), findsOneWidget);

    // Advance to Slide 2: Squad & Teams
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();
    expect(find.text("Build Your Squad & Teams"), findsOneWidget);
    expect(find.text("Pickleball Crew"), findsOneWidget);

    // Advance to Slide 3: Hangouts & Seasons
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();
    expect(find.text("Hangouts & Seasons"), findsOneWidget);
    expect(find.text("SEASON"), findsOneWidget);
    expect(find.text("Recurring Season"), findsOneWidget);

    // Advance to Slide 4: Vibe Checks
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();
    expect(find.text("Vote with Vibe Checks"), findsOneWidget);
    expect(find.text("VIBE CHECK"), findsOneWidget);
    expect(find.text("Where should we go Friday?"), findsOneWidget);

    // Advance to Slide 5: Live Feed & RSVPs
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();
    expect(find.text("Live Feed & RSVPs"), findsOneWidget);
    expect(find.text("Let's Go!"), findsOneWidget);

    // Complete on final slide
    await tester.tap(find.text("Let's Go!"));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_seen_tutorial'), isTrue);
  });

  testWidgets('OnboardingTutorial skip button completes tutorial and stores preference',
      (tester) async {
    bool completed = false;

    await tester.pumpWidget(
      buildTutorialApp(
        onComplete: () {
          completed = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Skip"), findsOneWidget);
    await tester.tap(find.text("Skip"));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_seen_tutorial'), isTrue);
  });

  testWidgets('OnboardingTutorial renders in landscape without layout overflow',
      (tester) async {
    tester.view.physicalSize = const Size(852, 393);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      buildTutorialApp(onComplete: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text("Welcome to TFTI!"), findsOneWidget);

    // Iterate through all slides in landscape to verify zero render overflows
    for (int i = 0; i < 4; i++) {
      await tester.tap(find.text("Next"));
      await tester.pumpAndSettle();
    }

    expect(find.text("Live Feed & RSVPs"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
