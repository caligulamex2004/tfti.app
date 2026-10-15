import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/feed/carousel_feed_list.dart';
import 'package:tftiapp/components/feed/contextual_empty_card.dart';
import 'package:tftiapp/components/feed/feed_filter_bar.dart';
import 'package:tftiapp/components/details/event_vitals_card.dart';
import 'package:tftiapp/components/forms/recurring_season_toggle.dart';

void main() {
  testWidgets('ContextualEmptyCard renders title and message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContextualEmptyCard(
            icon: Icons.celebration,
            title: 'No upcoming hangouts',
            message: 'Tap the create button to start a hangout.',
          ),
        ),
      ),
    );

    expect(find.text('No upcoming hangouts'), findsOneWidget);
    expect(find.text('Tap the create button to start a hangout.'), findsOneWidget);
    expect(find.byIcon(Icons.celebration), findsOneWidget);
  });

  testWidgets('FeedFilterBar renders all filters and triggers onFilterChanged', (WidgetTester tester) async {
    FeedFilter selected = FeedFilter.thisWeek;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedFilterBar(
            selectedFilter: selected,
            onFilterChanged: (newFilter) {
              selected = newFilter;
            },
          ),
        ),
      ),
    );

    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Next Week'), findsOneWidget);
    expect(find.text('⭐ VIP'), findsOneWidget);

    await tester.tap(find.text('Next Week'));
    await tester.pump();
    expect(selected, FeedFilter.nextWeek);

    await tester.tap(find.text('⭐ VIP'));
    await tester.pump();
    expect(selected, FeedFilter.vip);
  });

  testWidgets('CarouselFeedList renders items safely without assertion error', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 310,
            child: CarouselFeedList(
              itemCount: 2,
              itemBuilder: (context, index) => Container(
                key: ValueKey('item_$index'),
                child: Text('Item $index'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Item 0'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsOneWidget);
  });

  testWidgets('EventVitalsCard displays correct duration label for keepAliveDays (1 Day, 1 Week, N Days)', (WidgetTester tester) async {
    Widget buildVitals(int days) {
      return MaterialApp(
        home: Scaffold(
          body: EventVitalsCard(
            eventTime: DateTime(2026, 10, 15, 18, 0),
            keepAliveDays: days,
            location: 'Central Park',
            isVibeCheck: false,
            onCalendarTap: () {},
            onMapTap: () {},
          ),
        ),
      );
    }

    // keepAliveDays: 1 -> "1 Day"
    await tester.pumpWidget(buildVitals(1));
    expect(find.text('1 Day'), findsOneWidget);

    // keepAliveDays: 7 -> "1 Week"
    await tester.pumpWidget(buildVitals(7));
    expect(find.text('1 Week'), findsOneWidget);

    // keepAliveDays: 3 -> "3 Days"
    await tester.pumpWidget(buildVitals(3));
    expect(find.text('3 Days'), findsOneWidget);

    // keepAliveDays: 0 -> no duration pill
    await tester.pumpWidget(buildVitals(0));
    expect(find.text('1 Day'), findsNothing);
    expect(find.text('1 Week'), findsNothing);
  });

  testWidgets('RecurringSeasonToggle configures recurring frequency and instance limits', (WidgetTester tester) async {
    bool isRecurring = false;
    String frequency = 'weekly';
    int instances = 4;

    Widget buildToggle() {
      return StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: RecurringSeasonToggle(
                isRecurring: isRecurring,
                recurringFrequency: frequency,
                recurringInstances: instances,
                maxRecurringInstances: 8,
                onToggle: (val) => setState(() => isRecurring = val),
                onFrequencyChanged: (f) => setState(() => frequency = f),
                onInstancesChanged: (n) => setState(() => instances = n),
              ),
            ),
          );
        },
      );
    }

    await tester.pumpWidget(buildToggle());
    expect(find.text('Turn this into a recurring Season'), findsOneWidget);
    // When off, dropdown & counter are hidden
    expect(find.text('Repeats'), findsNothing);

    // Toggle switch on
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(isRecurring, isTrue);
    expect(find.text('Repeats'), findsOneWidget);
    expect(find.text('Total Events'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    // Increment instance count
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(instances, 5);
    expect(find.text('5'), findsOneWidget);
  });
}
