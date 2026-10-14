import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tftiapp/components/shared/shared_sliver_app_bar.dart';
import 'package:tftiapp/pages/team_members_page.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('TeamMembersPage & SharedSliverAppBar Layout Tests', () {
    testWidgets('TeamMembersPage configures SafeArea(top: true, bottom: false) for device notch clearance', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(top: 48, left: 0, right: 0, bottom: 48); // 24 logical px status bar
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      // Pump TeamMembersPage inside MaterialApp
      await tester.pumpWidget(
        const MaterialApp(
          home: TeamMembersPage(
            circleId: 'test-circle-id',
            circleName: 'Test Circle',
          ),
        ),
      );

      // Verify SafeArea is present with top: true and bottom: false
      final safeAreaFinder = find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(SafeArea),
      );
      expect(safeAreaFinder, findsOneWidget);

      final safeArea = tester.widget<SafeArea>(safeAreaFinder);
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isFalse);
    });

    testWidgets('Uncollapsed title in portrait is spaced to right of back button (x >= 56.0) when hasBackButton is true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(top: 48, left: 0, right: 0, bottom: 48);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          theme: ThemeData(platform: TargetPlatform.android),
          home: const Scaffold(body: Text('Root')),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: CustomScrollView(
              slivers: [
                SharedSliverAppBar(
                  title: 'Team Alpha',
                  collapsedTitle: 'Team Alpha',
                  expandedHeight: 140.0,
                  hasBackButton: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify back button is present
      final backButtonFinder = find.byType(BackButton);
      expect(backButtonFinder, findsOneWidget);
      final backButtonRect = tester.getRect(backButtonFinder);
      expect(backButtonRect.left, lessThanOrEqualTo(4.0));
      expect(backButtonRect.right, lessThanOrEqualTo(56.0));

      // Find the uncollapsed (expanded) title text widget
      final titleFinder = find.text('Team Alpha');
      expect(titleFinder, findsWidgets); // Collapsed and expanded instances

      // The visible expanded title must start at x >= 56.0 (comfortably spaced to the right of the back button)
      final titleRects = tester.widgetList(titleFinder).map((w) => tester.getRect(find.byWidget(w))).toList();
      for (final rect in titleRects) {
        expect(rect.left, greaterThanOrEqualTo(56.0), reason: 'Title at $rect overlaps back button');
      }
    });

    testWidgets('Uncollapsed title starts at x = 20.0 when hasBackButton is false in portrait', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = FakeViewPadding.zero;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SharedSliverAppBar(
                  title: 'Teams Root',
                  collapsedTitle: 'Teams Root',
                  expandedHeight: 140.0,
                  hasBackButton: false,
                ),
              ],
            ),
          ),
        ),
      );

      final titleFinder = find.text('Teams Root');
      expect(titleFinder, findsWidgets);

      // In portrait without back button, expanded title starts at 20.0
      final titleRects = tester.widgetList(titleFinder).map((w) => tester.getRect(find.byWidget(w))).toList();
      final expandedTitleRect = titleRects.firstWhere((r) => r.left == 20.0);
      expect(expandedTitleRect.left, equals(20.0));
    });
  });
}
