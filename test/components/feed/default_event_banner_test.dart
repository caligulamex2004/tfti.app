import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tftiapp/components/feed/default_event_banner.dart';
import 'package:tftiapp/utils/event_type_visuals.dart';

void main() {
  group('DefaultEventBanner Widget Tests', () {
    testWidgets('renders Hangout hero default banner with Icons.how_to_vote glyph', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: DefaultEventBanner(isVibeCheck: false),
            ),
          ),
        ),
      );

      expect(find.byType(DefaultEventBanner), findsOneWidget);
      expect(find.byIcon(Icons.how_to_vote), findsOneWidget);

      final visuals = EventTypeVisuals.forType(isVibeCheck: false);
      expect(visuals.label, 'HANGOUT');
      expect(visuals.icon, Icons.how_to_vote);
      expect(visuals.primaryColor, const Color(0xFF3B82F6));
    });

    testWidgets('renders Vibe Check hero default banner with Symbols.earthquake glyph', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: DefaultEventBanner(isVibeCheck: true),
            ),
          ),
        ),
      );

      expect(find.byType(DefaultEventBanner), findsOneWidget);
      expect(find.byIcon(Symbols.earthquake), findsOneWidget);

      final visuals = EventTypeVisuals.forType(isVibeCheck: true);
      expect(visuals.label, 'VIBE CHECK');
      expect(visuals.icon, Symbols.earthquake);
      expect(visuals.primaryColor, const Color(0xFFF59E0B));
    });

    testWidgets('renders thumbnail mode in 60x60 constraints without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultEventBanner.thumbnail(
              isVibeCheck: false,
              thumbnailSize: 60,
            ),
          ),
        ),
      );

      expect(find.byType(DefaultEventBanner), findsOneWidget);
      expect(find.byIcon(Icons.how_to_vote), findsOneWidget);
    });

    testWidgets('renders thumbnail mode for Vibe Check in 60x60 constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultEventBanner.thumbnail(
              isVibeCheck: true,
              thumbnailSize: 60,
            ),
          ),
        ),
      );

      expect(find.byType(DefaultEventBanner), findsOneWidget);
      expect(find.byIcon(Symbols.earthquake), findsOneWidget);
    });
  });
}
