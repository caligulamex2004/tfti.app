import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/feed/contextual_empty_card.dart';
import 'package:tftiapp/components/feed/feed_filter_bar.dart';

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

    await tester.tap(find.text('Next Week'));
    await tester.pump();

    expect(selected, FeedFilter.nextWeek);
  });
}
