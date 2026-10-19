import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tftiapp/components/shared/shared_sliver_app_bar.dart';
import 'package:tftiapp/components/shared/banner_picker.dart';
import 'package:tftiapp/components/forms/vitals_form_card.dart';
import 'package:tftiapp/components/forms/extras_form_card.dart';
import 'package:tftiapp/components/forms/crew_form_card.dart';
import 'package:tftiapp/components/forms/editor_action_buttons.dart';
import 'package:tftiapp/pages/hangout_editor_page.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('HangoutEditorPage Tests', () {
    testWidgets('Renders SharedSliverAppBar with Go! pill and all cards in create mode', (
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
          home: HangoutEditorPage(),
        ),
      );
      await tester.pump();

      // Header & Quick Action Pill
      expect(find.byType(SharedSliverAppBar), findsOneWidget);
      expect(find.text('Create Hangout'), findsWidgets);
      expect(find.text('Go!'), findsWidgets);

      // Core Form Cards
      expect(find.byType(BannerPicker), findsOneWidget);
      expect(find.byType(VitalsFormCard), findsOneWidget);
      expect(find.byType(ExtrasFormCard), findsOneWidget);
      expect(find.byType(CrewFormCard), findsOneWidget);
      expect(find.byType(EditorActionButtons), findsOneWidget);
      expect(find.text('Throw it out there'), findsWidgets);

      // Verify Card Titles are uppercased matching InfoCard
      expect(find.text('THE VITALS'), findsOneWidget);
      expect(find.text('THE EXTRAS'), findsOneWidget);
      expect(find.text('THE CREW'), findsOneWidget);
    });

    testWidgets('Wide-screen engages balanced dual columns constrained to 1000px', (
      WidgetTester tester,
    ) async {
      // 1200x800 desktop viewport
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HangoutEditorPage(),
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

      // In wide-screen, verify both columns are rendered side by side
      expect(find.byType(BannerPicker), findsOneWidget);
      expect(find.byType(VitalsFormCard), findsOneWidget);
      expect(find.byType(ExtrasFormCard), findsOneWidget);
      expect(find.byType(CrewFormCard), findsOneWidget);
    });
  });
}
