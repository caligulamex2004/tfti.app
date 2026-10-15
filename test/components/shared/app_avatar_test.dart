import 'package:cached_network_image/cached_network_image.dart';
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

    testWidgets('renders monogram initial when avatarUrl is empty or whitespace', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              avatarUrl: '   ',
              avatarColor: Colors.green,
              displayName: 'Chloe',
              radius: 20,
            ),
          ),
        ),
      );

      expect(find.text('C'), findsOneWidget);
      final circleAvatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circleAvatar.backgroundColor, Colors.green);
    });

    testWidgets('mobile uses CachedNetworkImage and imageBuilder does NOT superimpose monogram', (tester) async {
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

      final cachedImageFinder = find.byType(CachedNetworkImage);
      expect(cachedImageFinder, findsOneWidget);

      final cachedImage = tester.widget<CachedNetworkImage>(cachedImageFinder);

      // 1. Verify placeholder renders fallback with monogram
      final context = tester.element(cachedImageFinder);
      final placeholderWidget = cachedImage.placeholder!(context, 'https://example.com/photo.jpg');
      expect(placeholderWidget, isA<CircleAvatar>());
      final placeholderAvatar = placeholderWidget as CircleAvatar;
      expect(placeholderAvatar.backgroundColor, Colors.purple);
      expect(placeholderAvatar.child, isNotNull);

      // 2. Verify errorWidget renders fallback with monogram
      final errorWidget = cachedImage.errorWidget!(context, 'https://example.com/photo.jpg', Exception('404'));
      expect(errorWidget, isA<CircleAvatar>());
      final errorAvatar = errorWidget as CircleAvatar;
      expect(errorAvatar.backgroundColor, Colors.purple);
      expect(errorAvatar.child, isNotNull);

      // 3. Verify imageBuilder produces CircleAvatar WITHOUT child (monogram is NOT superimposed)
      const fakeProvider = AssetImage('assets/test.png');
      final builtImageWidget = cachedImage.imageBuilder!(context, fakeProvider);
      expect(builtImageWidget, isA<CircleAvatar>());
      final builtAvatar = builtImageWidget as CircleAvatar;
      expect(builtAvatar.backgroundImage, fakeProvider);
      expect(builtAvatar.child, isNull, reason: 'Monogram must NOT be superimposed on loaded image');
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
