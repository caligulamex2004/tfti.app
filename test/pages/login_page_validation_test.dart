import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/pages/login_page.dart';

void main() {
  Widget buildLoginPage() {
    return const MaterialApp(
      home: LoginPage(),
    );
  }

  group('LoginPage UI & Validation Tests', () {
    testWidgets('Initial render displays Login mode UI', (tester) async {
      await tester.pumpWidget(buildLoginPage());

      expect(find.text('tfti.app'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Enter your number to login.'), findsOneWidget);
      expect(find.text('Get Login Code'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);

      // Sign-up exclusive fields must not be visible
      expect(find.text('Pick a display name'), findsNothing);
      expect(find.text('Pick a username'), findsNothing);
      expect(find.text('I agree to the Terms of Service'), findsNothing);
      expect(find.text('I agree to the Privacy Policy'), findsNothing);
    });

    testWidgets('Tapping Sign Up footer switches to Join the Squad mode', (tester) async {
      await tester.pumpWidget(buildLoginPage());

      // Tap Sign Up toggle in footer
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Join the Squad'), findsOneWidget);
      expect(find.text('Create an account to get started.'), findsOneWidget);
      expect(find.text('Pick a display name'), findsOneWidget);
      expect(find.text('Pick a username'), findsOneWidget);
      expect(find.text('I agree to the Terms of Service'), findsOneWidget);
      expect(find.text('I agree to the Privacy Policy'), findsOneWidget);
      expect(find.text('Sign Up & Get Login Code'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('Sign Up button is disabled until all inputs, username regex, and checkboxes are valid', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildLoginPage());

      // Switch to sign up mode
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      final signUpBtnFinder = find.widgetWithText(ElevatedButton, 'Sign Up & Get Login Code');
      expect(signUpBtnFinder, findsOneWidget);

      // 1. Initially disabled (no name, no username, no checkboxes)
      ElevatedButton button = tester.widget<ElevatedButton>(signUpBtnFinder);
      expect(button.onPressed, isNull);

      // 2. Fill name only -> still disabled
      await tester.enterText(find.widgetWithText(TextField, 'Pick a display name'), 'Misty Waterflower');
      await tester.pumpAndSettle();
      button = tester.widget<ElevatedButton>(signUpBtnFinder);
      expect(button.onPressed, isNull);

      // 3. Fill invalid username (< 3 chars) -> still disabled
      await tester.enterText(find.widgetWithText(TextField, 'Pick a username'), 'mi');
      await tester.pumpAndSettle();
      button = tester.widget<ElevatedButton>(signUpBtnFinder);
      expect(button.onPressed, isNull);

      // 4. Fill valid username -> still disabled without checkboxes
      await tester.enterText(find.widgetWithText(TextField, 'Pick a username'), 'misty_cerulean');
      await tester.pumpAndSettle();
      button = tester.widget<ElevatedButton>(signUpBtnFinder);
      expect(button.onPressed, isNull);

      // 5. Check ToS only -> still disabled without Privacy
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      button = tester.widget<ElevatedButton>(signUpBtnFinder);
      expect(button.onPressed, isNull);

      // 6. Check Privacy Policy -> now all valid, button becomes ENABLED!
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      button = tester.widget<ElevatedButton>(signUpBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Tapping Log In footer in Sign Up mode toggles back to Login mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildLoginPage());

      // Switch to sign up mode
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Join the Squad'), findsOneWidget);

      // Switch back to login mode
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Pick a display name'), findsNothing);
      expect(find.text('Pick a username'), findsNothing);
    });

    testWidgets('Card width is constrained to max 440px on iPad and web desktop screens', (tester) async {
      // Simulate 1440x900 desktop/web window
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildLoginPage());
      await tester.pumpAndSettle();

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);
      final cardSize = tester.getSize(cardFinder);

      // Must be capped at 440px instead of stretching to 1440px
      expect(cardSize.width, equals(440.0));
    });

    testWidgets('Card adapts to mobile portrait screens without overflow', (tester) async {
      // Standard iPhone portrait size
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildLoginPage());
      await tester.pumpAndSettle();

      final cardFinder = find.byType(Card);
      final cardSize = tester.getSize(cardFinder);

      // Width is screenWidth - 48px padding = 342px
      expect(cardSize.width, equals(390.0 - 48.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders gracefully in landscape mode without layout overflow', (tester) async {
      // iPhone landscape size (wide but short)
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildLoginPage());
      await tester.pumpAndSettle();

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);
      final cardSize = tester.getSize(cardFinder);
      expect(cardSize.width, equals(440.0));
      expect(tester.takeException(), isNull);
    });
  });
}
