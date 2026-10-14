import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/banner_picker.dart';

void main() {
  group('BannerPicker Tests', () {
    testWidgets(
      'Renders empty state with Add Event Banner when no image is provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BannerPicker(
                isPast: false,
                onImageChanged: (path, isRemoved) {},
              ),
            ),
          ),
        );

        expect(find.text('Add Event Banner'), findsOneWidget);
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping opens options bottom sheet with Take a Photo and Choose from Gallery',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BannerPicker(
                isPast: false,
                onImageChanged: (path, isRemoved) {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Add Event Banner'));
        await tester.pumpAndSettle();

        expect(find.text('Take a Photo'), findsOneWidget);
        expect(find.text('Choose from Gallery'), findsOneWidget);
        // "Remove Banner" should not be visible when no image exists
        expect(find.text('Remove Banner'), findsNothing);
      },
    );

    testWidgets('Does not open options sheet when isPast is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BannerPicker(
              isPast: true,
              onImageChanged: (path, isRemoved) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Event Banner'));
      await tester.pumpAndSettle();

      expect(find.text('Take a Photo'), findsNothing);
      expect(find.text('Choose from Gallery'), findsNothing);
    });

    testWidgets(
      'Renders edit icon when existingImageUrl is provided and allows banner removal',
      (tester) async {
        String? changedPath = 'initial';
        bool? wasRemoved;
        Uint8List? changedBytes = Uint8List.fromList([1, 2, 3]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BannerPicker(
                existingImageUrl: 'https://example.com/existing-banner.jpg',
                isPast: false,
                onImageChanged: (path, isRemoved) {
                  changedPath = path;
                  wasRemoved = isRemoved;
                },
                onBytesChanged: (bytes) {
                  changedBytes = bytes;
                },
              ),
            ),
          ),
        );

        // Should display edit overlay icon instead of empty state
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.text('Add Event Banner'), findsNothing);

        // Tap banner to open options
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        // Options sheet should include "Remove Banner"
        expect(find.text('Remove Banner'), findsOneWidget);

        // Tap Remove Banner
        await tester.tap(find.text('Remove Banner'));
        await tester.pumpAndSettle();

        // Options sheet should dismiss
        expect(find.text('Remove Banner'), findsNothing);

        // Callbacks should be triggered
        expect(changedPath, isNull);
        expect(wasRemoved, isTrue);
        expect(changedBytes, isNull);

        // UI should transition back to empty state
        expect(find.text('Add Event Banner'), findsOneWidget);
      },
    );
  });
}
