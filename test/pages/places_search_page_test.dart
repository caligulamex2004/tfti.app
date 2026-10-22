import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/pages/places_search_page.dart';

void main() {
  Widget buildPlacesSearchPage({bool showFavorites = false}) {
    return MaterialApp(
      home: PlacesSearchPage(showFavorites: showFavorites),
    );
  }

  group('PlacesSearchPage UI Tests', () {
    testWidgets('Renders search bar with hint text and icon', (tester) async {
      await tester.pumpWidget(buildPlacesSearchPage());

      expect(find.text('Search Places'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('e.g. Starbucks, Central Park'), findsOneWidget);
      expect(find.text('Search for an address'), findsOneWidget);
    });

    testWidgets('Entering and clearing text updates input controller', (tester) async {
      await tester.pumpWidget(buildPlacesSearchPage());

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Blue Bottle Coffee');
      await tester.pump();

      expect(find.text('Blue Bottle Coffee'), findsOneWidget);

      final clearButton = find.byIcon(Icons.cancel_rounded);
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pump();

      expect(find.text('Blue Bottle Coffee'), findsNothing);
    });

    testWidgets('Accepts fallbackLocation parameter gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlacesSearchPage(
            showFavorites: false,
            fallbackLocation: {'lat': 40.7128, 'lng': -74.0060},
          ),
        ),
      );

      expect(find.text('Search Places'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
