import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/app_avatar.dart';

void main() {
  group('AppAvatar Tests', () {
    testWidgets('renders monogram initial and signature color when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              avatarUrl: null,
              avatarColor: Colors.blue,
              displayName: 'Antigravity',
              radius: 24,
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      final circleAvatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circleAvatar.backgroundColor, Colors.blue);
      expect(circleAvatar.radius, 24);
      expect(circleAvatar.backgroundImage, isNull);
    });

    testWidgets('renders monogram child even when avatarUrl is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              avatarUrl: 'https://example.com/photo.jpg',
              avatarColor: Colors.purple,
              displayName: 'Zara',
              radius: 30,
            ),
          ),
        ),
      );

      // Child monogram should always be present as fallback
      expect(find.text('Z'), findsOneWidget);
      final circleAvatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circleAvatar.backgroundColor, Colors.purple);
      expect(circleAvatar.backgroundImage, isNotNull);
    });

    testWidgets('renders fallback question mark when displayName is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              avatarUrl: null,
              avatarColor: Colors.red,
              displayName: '   ',
            ),
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('AppAvatar.fromColorValue parses int, Color, and string values', (tester) async {
      // 1. Int value
      final avatarFromInt = AppAvatar.fromColorValue(
        avatarUrl: null,
        avatarColor: 0xFF4CAF50,
        displayName: 'Bob',
      );
      expect(avatarFromInt.avatarColor, const Color(0xFF4CAF50));

      // 2. Color value
      final avatarFromColor = AppAvatar.fromColorValue(
        avatarUrl: null,
        avatarColor: Colors.orange,
        displayName: 'Bob',
      );
      expect(avatarFromColor.avatarColor, Colors.orange);

      // 3. String representation of int
      final avatarFromString = AppAvatar.fromColorValue(
        avatarUrl: null,
        avatarColor: '4283215696', // 0xFF4CAF50 in decimal
        displayName: 'Bob',
      );
      expect(avatarFromString.avatarColor, const Color(0xFF4CAF50));

      // 4. Fallback on invalid
      final avatarFallback = AppAvatar.fromColorValue(
        avatarUrl: null,
        avatarColor: 'invalid_color',
        displayName: 'Bob',
      );
      expect(avatarFallback.avatarColor, const Color(0xFF9E9E9E));
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              avatarUrl: null,
              avatarColor: Colors.teal,
              displayName: 'Dave',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppAvatar));
      expect(tapped, isTrue);
    });
  });
}
