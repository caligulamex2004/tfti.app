import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/details/event_vitals_card.dart';

void main() {
  final DateTime mockDate = DateTime(2027, 8, 15, 19, 30); // Sunday Aug 15 @ 7:30 PM

  Widget buildWidget({
    String location = 'Pebble Beach Golf Links',
    bool isVibeCheck = false,
    EdgeInsetsGeometry? margin,
    VoidCallback? onCalendarTap,
    VoidCallback? onMapTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EventVitalsCard(
            eventTime: mockDate,
            keepAliveDays: 3,
            location: location,
            isVibeCheck: isVibeCheck,
            margin: margin,
            onCalendarTap: onCalendarTap ?? () {},
            onMapTap: onMapTap ?? () {},
          ),
        ),
      ),
    );
  }

  group('EventVitalsCard Widget Tests', () {
    testWidgets('Renders date badge, time, and prominent location with Directions chip',
        (WidgetTester tester) async {
      bool mapTapped = false;
      bool calendarTapped = false;

      await tester.pumpWidget(
        buildWidget(
          location: '1700 17-Mile Drive, Pebble Beach',
          onMapTap: () => mapTapped = true,
          onCalendarTap: () => calendarTapped = true,
        ),
      );

      // Card Title (uppercased by InfoCard)
      expect(find.text('THE VITALS'), findsOneWidget);

      // Date badge: AUG and 15
      expect(find.text('AUG'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      // Weekday & Time: Sunday, AUG 15 and 7:30 PM
      expect(find.text('Sunday, AUG 15'), findsOneWidget);
      expect(find.text('7:30 PM'), findsOneWidget);

      // Prominent location text (Line 1: 1700 17-Mile Drive,, Line 2: Pebble Beach)
      expect(find.text('1700 17-Mile Drive,'), findsOneWidget);
      expect(find.text('Pebble Beach'), findsOneWidget);

      // No redundant subtitle
      expect(find.text('Tap for map & navigation'), findsNothing);

      // Go button present
      expect(find.text('Go'), findsOneWidget);

      // Tap Go / Location tile
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(mapTapped, isTrue);

      // + Calendar button present
      expect(find.text('+ Calendar'), findsOneWidget);
      await tester.tap(find.text('+ Calendar'));
      await tester.pump();
      expect(calendarTapped, isTrue);
    });

    testWidgets('Vibe check mode hides venue card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildWidget(isVibeCheck: true),
      );

      expect(find.text('Go'), findsNothing);
      expect(find.text('Pebble Beach Golf Links'), findsNothing);
    });
  });
}
