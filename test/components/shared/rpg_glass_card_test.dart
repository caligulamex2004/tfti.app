import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/rpg_glass_card.dart';

void main() {
  group('RpgGlassCard Widget Tests', () {
    testWidgets('Renders uppercase title, icon badge, and trailing widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RpgGlassCard(
              title: 'The Vitals',
              icon: Icons.calendar_today,
              trailing: Text('TRAILING_BADGE'),
              child: Text('CHILD_CONTENT'),
            ),
          ),
        ),
      );

      // Uppercased title
      expect(find.text('THE VITALS'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.text('TRAILING_BADGE'), findsOneWidget);
      expect(find.text('CHILD_CONTENT'), findsOneWidget);
    });
  });
}
