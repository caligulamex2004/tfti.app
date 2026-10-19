import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tftiapp/components/shared/shared_sliver_app_bar.dart';
import 'package:tftiapp/components/forms/vitals_form_card.dart';
import 'package:tftiapp/components/forms/vibe_options_card.dart';
import 'package:tftiapp/components/forms/extras_form_card.dart';
import 'package:tftiapp/components/forms/crew_form_card.dart';
import 'package:tftiapp/pages/vibe_check_editor_page.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('VibeCheckEditorPage Tests', () {
    testWidgets('Renders SharedSliverAppBar with Send pill and all cards in create mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: VibeCheckEditorPage(),
        ),
      );
      await tester.pump();

      // Header & Quick Action Pill
      expect(find.byType(SharedSliverAppBar), findsOneWidget);
      expect(find.text('Vibe Check'), findsWidgets);
      expect(find.text('Send'), findsWidgets);

      // Core Form Cards
      expect(find.byType(VitalsFormCard), findsOneWidget);
      expect(find.byType(VibeOptionsCard), findsOneWidget);
      expect(find.byType(ExtrasFormCard), findsOneWidget);
      expect(find.byType(CrewFormCard), findsOneWidget);

      // Card Titles uppercased
      expect(find.text('THE VITALS'), findsOneWidget);
      expect(find.text('VIBE OPTIONS'), findsOneWidget);
      expect(find.text('THE EXTRAS'), findsOneWidget);
      expect(find.text('THE CREW'), findsOneWidget);
    });

    testWidgets('Wide-screen engages balanced dual columns constrained to 1000px', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: VibeCheckEditorPage(),
        ),
      );
      await tester.pump();

      // Find ConstrainedBox with maxWidth: 1000
      final constrainedFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.maxWidth == 1000,
      );
      expect(constrainedFinder, findsOneWidget);

      // Verify Vitals, VibeOptionsCard, Extras, Crew are rendered
      expect(find.byType(VitalsFormCard), findsOneWidget);
      expect(find.byType(VibeOptionsCard), findsOneWidget);
      expect(find.byType(ExtrasFormCard), findsOneWidget);
      expect(find.byType(CrewFormCard), findsOneWidget);
    });
  });
}
