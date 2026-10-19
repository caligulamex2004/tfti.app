import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tftiapp/components/shared/event_type_pill.dart';
import 'package:tftiapp/utils/event_type_visuals.dart';

void main() {
  group('EventTypePill Widget Tests', () {
    testWidgets('renders HANGOUT pill with Royal Blue signature and Icons.how_to_vote', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventTypePill(isVibeCheck: false),
          ),
        ),
      );

      expect(find.text('HANGOUT'), findsOneWidget);
      expect(find.byIcon(Icons.how_to_vote), findsOneWidget);

      final visuals = EventTypeVisuals.forType(isVibeCheck: false);
      expect(visuals.label, 'HANGOUT');
      expect(visuals.icon, Icons.how_to_vote);
      expect(visuals.primaryColor, const Color(0xFF3B82F6));
    });

    testWidgets('renders VIBE CHECK pill with Amber signature and Symbols.earthquake', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventTypePill(isVibeCheck: true),
          ),
        ),
      );

      expect(find.text('VIBE CHECK'), findsOneWidget);
      expect(find.byIcon(Symbols.earthquake), findsOneWidget);

      final visuals = EventTypeVisuals.forType(isVibeCheck: true);
      expect(visuals.label, 'VIBE CHECK');
      expect(visuals.icon, Symbols.earthquake);
      expect(visuals.primaryColor, const Color(0xFFF59E0B));
    });
  });
}
