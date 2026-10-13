import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tftiapp/components/feed/card_bottom_bar.dart';
import 'package:tftiapp/components/feed/card_hero_banner.dart';
import 'package:tftiapp/components/feed/card_landscape_tile.dart';
import 'package:tftiapp/components/feed/contextual_empty_card.dart';
import 'package:tftiapp/components/feed/empty_feed_states.dart';
import 'package:tftiapp/components/feed/feed_skeleton.dart';
import 'package:tftiapp/components/forms/vitals_form_card.dart';
import 'package:tftiapp/components/shared/event_summary_card.dart';
import 'package:tftiapp/components/shared/shared_sliver_app_bar.dart';
import 'package:tftiapp/models/event_model.dart';
import 'package:tftiapp/models/invitation_model.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  const Size portraitSize = Size(393, 852); // iPhone standard portrait
  const Size landscapeSize = Size(852, 393); // iPhone standard landscape

  group('Navigation Shell Orientation Tests', () {
    Widget buildResponsiveShell({
      required int initialIndex,
      required ValueChanged<int> onTabChanged,
    }) {
      int selectedIndex = initialIndex;
      return StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Builder(
              builder: (ctx) {
                final isLandscape =
                    MediaQuery.orientationOf(ctx) == Orientation.landscape;

                final pages = [
                  const Center(child: Text('Home Page Content')),
                  const Center(child: Text('Teams Page Content')),
                  const Center(child: Text('Squad Page Content')),
                  const Center(child: Text('Account Page Content')),
                ];

                return Scaffold(
                  body: isLandscape
                      ? Row(
                          children: [
                            SafeArea(
                              right: false,
                              child: NavigationRail(
                                selectedIndex: selectedIndex,
                                onDestinationSelected: (i) {
                                  setState(() => selectedIndex = i);
                                  onTabChanged(i);
                                },
                                destinations: const [
                                  NavigationRailDestination(
                                    icon: Icon(Symbols.cottage),
                                    label: Text('Home'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.supervised_user_circle_outlined),
                                    label: Text('Teams'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Symbols.group),
                                    label: Text('Squad'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Symbols.account_circle),
                                    label: Text('Account'),
                                  ),
                                ],
                              ),
                            ),
                            const VerticalDivider(width: 1, thickness: 1),
                            Expanded(
                              child: IndexedStack(
                                index: selectedIndex,
                                children: pages,
                              ),
                            ),
                          ],
                        )
                      : IndexedStack(
                          index: selectedIndex,
                          children: pages,
                        ),
                  bottomNavigationBar: isLandscape
                      ? null
                      : NavigationBar(
                          selectedIndex: selectedIndex,
                          onDestinationSelected: (i) {
                            setState(() => selectedIndex = i);
                            onTabChanged(i);
                          },
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Symbols.cottage),
                              label: 'Home',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.supervised_user_circle_outlined),
                              label: 'Teams',
                            ),
                            NavigationDestination(
                              icon: Icon(Symbols.group),
                              label: 'Squad',
                            ),
                            NavigationDestination(
                              icon: Icon(Symbols.account_circle),
                              label: 'Account',
                            ),
                          ],
                        ),
                );
              },
            ),
          );
        },
      );
    }

    testWidgets('Switches between NavigationBar and NavigationRail on orientation flip and preserves tab state',
        (WidgetTester tester) async {
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int currentTab = 0;
      await tester.pumpWidget(
        buildResponsiveShell(
          initialIndex: 0,
          onTabChanged: (i) => currentTab = i,
        ),
      );
      await tester.pumpAndSettle();

      // Portrait: NavigationBar exists, NavigationRail does not
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Home Page Content'), findsOneWidget);

      // Switch tab to Teams (index 1) in portrait
      await tester.tap(find.text('Teams'));
      await tester.pumpAndSettle();
      expect(currentTab, 1);
      expect(find.text('Teams Page Content'), findsOneWidget);

      // Rotate to Landscape
      tester.view.physicalSize = landscapeSize;
      await tester.pumpAndSettle();

      // Landscape: NavigationRail exists, NavigationBar is removed
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // State preservation: Still on Teams page
      expect(find.text('Teams Page Content'), findsOneWidget);

      // Switch tab to Squad (index 2) in landscape
      await tester.tap(find.byIcon(Symbols.group));
      await tester.pumpAndSettle();
      expect(currentTab, 2);
      expect(find.text('Squad Page Content'), findsOneWidget);

      // Rotate back to Portrait
      tester.view.physicalSize = portraitSize;
      await tester.pumpAndSettle();

      // Portrait restored: NavigationBar exists, squad tab still active
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Squad Page Content'), findsOneWidget);
    });
  });

  group('SharedSliverAppBar Orientation Tests', () {
    Widget buildAppBarHarness({required bool isLandscape}) {
      return MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SharedSliverAppBar(
                title: "the i's",
                collapsedTitle: "thanks for the invite",
                subtitle: "Good morning, Alex",
                expandedHeight: isLandscape ? 56.0 : 140.0,
                hasBackButton: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {},
                  ),
                ],
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ListTile(title: Text('Item $index')),
                  childCount: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('Adapts between portrait 140px and landscape 56px without layout overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildAppBarHarness(isLandscape: false));
      await tester.pumpAndSettle();

      // Portrait state: Large title and subtitle rendered
      expect(find.text("the i's"), findsOneWidget);
      expect(find.text("Good morning, Alex"), findsOneWidget);

      // Rotate to Landscape
      tester.view.physicalSize = landscapeSize;
      await tester.pumpWidget(buildAppBarHarness(isLandscape: true));
      await tester.pumpAndSettle();

      // Landscape state: Collapsed title rendered cleanly without overflow
      expect(find.text("thanks for the invite"), findsOneWidget);

      // Scroll list down in landscape to verify sliver collapses smoothly
      await tester.drag(find.text('Item 2'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text("thanks for the invite"), findsOneWidget);

      // Rotate back to Portrait
      tester.view.physicalSize = portraitSize;
      await tester.pumpWidget(buildAppBarHarness(isLandscape: false));
      await tester.pumpAndSettle();

      expect(find.byType(SharedSliverAppBar), findsOneWidget);
    });
  });

  group('Home Feed & Empty State Orientation Tests', () {
    testWidgets('ContextualEmptyCard renders without overflow in both portrait and narrow landscape split panes',
        (WidgetTester tester) async {
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget buildEmptyCard(bool isLandscape) {
        return MaterialApp(
          home: Scaffold(
            body: isLandscape
                ? Row(
                    children: [
                      Expanded(
                        flex: 35,
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 240,
                                child: ContextualEmptyCard(
                                  icon: Icons.celebration,
                                  title: 'Nothing on the agenda.',
                                  message:
                                      'Your agenda is looking a bit empty... Tap the + to host a hangout and gather the squad!',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      const Expanded(
                        flex: 65,
                        child: FeedDetailPlaceholder(),
                      ),
                    ],
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 310,
                          child: ContextualEmptyCard(
                            icon: Icons.celebration,
                            title: 'Nothing on the agenda.',
                            message:
                                'Your agenda is looking a bit empty... Tap the + to host a hangout and gather the squad!',
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }

      // Portrait
      await tester.pumpWidget(buildEmptyCard(false));
      await tester.pumpAndSettle();
      expect(find.text('Nothing on the agenda.'), findsOneWidget);
      expect(find.byIcon(Icons.celebration), findsOneWidget);
      expect(find.byType(FeedDetailPlaceholder), findsNothing);

      // Rotate to Landscape
      tester.view.physicalSize = landscapeSize;
      await tester.pumpWidget(buildEmptyCard(true));
      await tester.pumpAndSettle();

      // Landscape: Empty card fits in 35% flex without overflow, and placeholder shows in 65% flex
      expect(find.text('Nothing on the agenda.'), findsOneWidget);
      expect(find.byType(FeedDetailPlaceholder), findsOneWidget);
      expect(find.text('Tap an event to view details'), findsOneWidget);

      // Rotate back to Portrait
      tester.view.physicalSize = portraitSize;
      await tester.pumpWidget(buildEmptyCard(false));
      await tester.pumpAndSettle();

      expect(find.text('Nothing on the agenda.'), findsOneWidget);
      expect(find.byType(FeedDetailPlaceholder), findsNothing);
    });

    testWidgets('FeedSkeleton adapts between portrait single column and landscape split-screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget buildSkeletonView(bool isLandscape) {
        final skeleton = FeedSkeleton(isLandscape: isLandscape);
        return MaterialApp(
          home: Scaffold(
            body: isLandscape
                ? Row(
                    children: [
                      Expanded(flex: 35, child: skeleton),
                      const VerticalDivider(width: 1, thickness: 1),
                      const Expanded(flex: 65, child: FeedDetailPlaceholder()),
                    ],
                  )
                : skeleton,
          ),
        );
      }

      // Portrait
      await tester.pumpWidget(buildSkeletonView(false));
      await tester.pump();
      expect(find.byType(FeedSkeleton), findsOneWidget);
      expect(find.byType(FeedDetailPlaceholder), findsNothing);

      // Landscape
      tester.view.physicalSize = landscapeSize;
      await tester.pumpWidget(buildSkeletonView(true));
      await tester.pump();

      expect(find.byType(FeedSkeleton), findsOneWidget);
      expect(find.byType(FeedDetailPlaceholder), findsOneWidget);

      // Rotate back to portrait
      tester.view.physicalSize = portraitSize;
      await tester.pumpWidget(buildSkeletonView(false));
      await tester.pump();

      expect(find.byType(FeedDetailPlaceholder), findsNothing);
    });
  });

  group('EventSummaryCard Orientation Adaptation Tests', () {
    final testEvent = Event(
      id: 'event-001',
      type: 'event',
      hostId: 'host-user-1',
      title: 'Taco Tuesday Hangout',
      location: 'Downtown Cantina',
      details: 'Come hungry!',
      time: DateTime.now().add(const Duration(days: 1)),
      isPast: false,
    );

    const testInvitation = Invitation(
      uid: 'guest-user-1',
      eventId: 'event-001',
      status: 'pending',
    );

    testWidgets('Renders hero banner card in portrait and adapts to landscape tile when rotated',
        (WidgetTester tester) async {
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool tapped = false;

      Widget buildCard({required bool isLandscape, required bool isHorizontal}) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: isLandscape ? 300 : 340,
                child: EventSummaryCard.fromModel(
                  event: testEvent,
                  invitation: testInvitation,
                  myUid: 'guest-user-1',
                  isLandscape: isLandscape,
                  isHorizontal: isHorizontal,
                  isSelected: false,
                  onTap: () => tapped = true,
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        );
      }

      // Portrait (carousel hero card)
      await tester.pumpWidget(buildCard(isLandscape: false, isHorizontal: true));
      await tester.pumpAndSettle();

      expect(find.byType(CardHeroBanner), findsOneWidget);
      expect(find.byType(CardBottomBar), findsOneWidget);
      expect(find.byType(CardLandscapeTile), findsNothing);
      expect(find.text('Taco Tuesday Hangout'), findsOneWidget);

      // Rotate to Landscape (vertical feed list using compact tile)
      tester.view.physicalSize = landscapeSize;
      await tester.pumpWidget(buildCard(isLandscape: true, isHorizontal: false));
      await tester.pumpAndSettle();

      expect(find.byType(CardLandscapeTile), findsOneWidget);
      expect(find.byType(CardHeroBanner), findsNothing);
      expect(find.byType(CardBottomBar), findsNothing);
      expect(find.text('Taco Tuesday Hangout'), findsOneWidget);

      // Interaction test in landscape
      await tester.tap(find.byType(CardLandscapeTile));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      // Rotate back to Portrait
      tester.view.physicalSize = portraitSize;
      await tester.pumpWidget(buildCard(isLandscape: false, isHorizontal: true));
      await tester.pumpAndSettle();

      expect(find.byType(CardHeroBanner), findsOneWidget);
      expect(find.byType(CardLandscapeTile), findsNothing);
    });
  });

  group('Editor Form Layout Orientation Tests', () {
    testWidgets('VitalsFormCard preserves controller values across orientation change',
        (WidgetTester tester) async {
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final titleController = TextEditingController(text: 'Board Games & Pizza');
      final locController = TextEditingController(text: 'Game Lounge');
      DateTime selectedDate = DateTime(2026, 11, 15);
      TimeOfDay selectedTime = const TimeOfDay(hour: 19, minute: 0);

      Widget buildForm(bool isLandscape) {
        return MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isLandscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: VitalsFormCard(
                            titleController: titleController,
                            locController: locController,
                            isPast: false,
                            selectedDate: selectedDate,
                            selectedTime: selectedTime,
                            onDateChanged: (d) => selectedDate = d,
                            onTimeChanged: (t) => selectedTime = t,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Side Panel Content'),
                            ),
                          ),
                        ),
                      ],
                    )
                  : VitalsFormCard(
                      titleController: titleController,
                      locController: locController,
                      isPast: false,
                      selectedDate: selectedDate,
                      selectedTime: selectedTime,
                      onDateChanged: (d) => selectedDate = d,
                      onTimeChanged: (t) => selectedTime = t,
                    ),
            ),
          ),
        );
      }

      // Portrait
      await tester.pumpWidget(buildForm(false));
      await tester.pumpAndSettle();

      expect(find.text('Board Games & Pizza'), findsOneWidget);
      expect(find.text('Game Lounge'), findsOneWidget);
      expect(find.text('Side Panel Content'), findsNothing);

      // Rotate to Landscape
      tester.view.physicalSize = landscapeSize;
      await tester.pumpWidget(buildForm(true));
      await tester.pumpAndSettle();

      expect(find.text('Board Games & Pizza'), findsOneWidget);
      expect(find.text('Game Lounge'), findsOneWidget);
      expect(find.text('Side Panel Content'), findsOneWidget);

      // Rotate back to Portrait
      tester.view.physicalSize = portraitSize;
      await tester.pumpWidget(buildForm(false));
      await tester.pumpAndSettle();

      expect(find.text('Board Games & Pizza'), findsOneWidget);
      expect(find.text('Side Panel Content'), findsNothing);
    });
  });
}
