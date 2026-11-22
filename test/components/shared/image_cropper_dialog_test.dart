import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/image_cropper_dialog.dart';

/// Creates a synthetic split-color [ui.Image] where the left half is pure red
/// (`0xFFFF0000`) and the right half is pure blue (`0xFF0000FF`).
Future<ui.Image> _createRedBlueImage({
  int width = 200,
  int height = 100,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
    Paint()..color = const Color(0xFF0000FF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<Uint8List> _imageToPngBytes(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<(int r, int g, int b, int a)> _samplePixel(
  ui.Image image,
  int x,
  int y,
) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final idx = (y * image.width + x) * 4;
  return (bytes[idx], bytes[idx + 1], bytes[idx + 2], bytes[idx + 3]);
}

void main() {
  group('CropTransformMath unit tests', () {
    test('effectiveImageSize swaps width and height on odd quarter turns', () {
      const size = Size(400, 200);
      expect(CropTransformMath.effectiveImageSize(size, 0), const Size(400, 200));
      expect(CropTransformMath.effectiveImageSize(size, 1), const Size(200, 400));
      expect(CropTransformMath.effectiveImageSize(size, 2), const Size(400, 200));
      expect(CropTransformMath.effectiveImageSize(size, 3), const Size(200, 400));
      expect(CropTransformMath.effectiveImageSize(size, -1), const Size(200, 400));
    });

    test('computeBaseScale guarantees cover fit for landscape and portrait', () {
      // 200x100 image into 100x100 square crop => scale = 1.0 (height matches)
      expect(
        CropTransformMath.computeBaseScale(
          imageSize: const Size(200, 100),
          quarterTurns: 0,
          cropSize: const Size(100, 100),
        ),
        closeTo(1.0, 1e-6),
      );
      // 200x100 rotated 90 deg => 100x200 into 160x90 crop => width needs 1.6x
      expect(
        CropTransformMath.computeBaseScale(
          imageSize: const Size(200, 100),
          quarterTurns: 1,
          cropSize: const Size(160, 90),
        ),
        closeTo(1.6, 1e-6),
      );
    });

    test('computeCropSize preserves aspect ratio inside stage bounds', () {
      final square = CropTransformMath.computeCropSize(
        stageSize: const Size(744, 600),
        aspectRatio: 1.0,
      );
      expect(square.width / square.height, closeTo(1.0, 1e-6));
      expect(square.width, lessThanOrEqualTo(600));

      final banner = CropTransformMath.computeCropSize(
        stageSize: const Size(744, 600),
        aspectRatio: 16 / 9,
      );
      expect(banner.width / banner.height, closeTo(16 / 9, 1e-6));
      expect(banner.width, lessThanOrEqualTo(600));
    });

    test('clampNormalizedOffset prevents exposed borders', () {
      // 200x100 image in 1:1 crop at scale 1.0 covers 2.0x width and 1.0x height.
      // Max normalized dx is (2.0 - 1.0) / 2 = 0.5; max dy is 0.0.
      final clamped = CropTransformMath.clampNormalizedOffset(
        normalizedOffset: const Offset(2.0, 1.0),
        imageSize: const Size(200, 100),
        quarterTurns: 0,
        aspectRatio: 1.0,
        scale: 1.0,
      );
      expect(clamped.dx, closeTo(0.5, 1e-6));
      expect(clamped.dy, closeTo(0.0, 1e-6));

      // At scale 2.0, covers 4.0x width and 2.0x height => max dx = 1.5, max dy = 0.5.
      final zoomedClamped = CropTransformMath.clampNormalizedOffset(
        normalizedOffset: const Offset(-5.0, -5.0),
        imageSize: const Size(200, 100),
        quarterTurns: 0,
        aspectRatio: 1.0,
        scale: 2.0,
      );
      expect(zoomedClamped.dx, closeTo(-1.5, 1e-6));
      expect(zoomedClamped.dy, closeTo(-0.5, 1e-6));
    });

    test('computeFocalZoomOffset pins focal point and performs 1:1 drag', () {
      // Pure 1-finger drag (scale unchanged)
      final dragged = CropTransformMath.computeFocalZoomOffset(
        startOffsetPx: const Offset(10, -20),
        startScale: 2.0,
        newScale: 2.0,
        startFocalFromCropCenter: const Offset(30, 40),
        currentFocalFromCropCenter: const Offset(55, 50),
      );
      expect(dragged, const Offset(35, -10));

      // Pure pinch zoom at (+50, 0) from 1.0x to 2.0x shifts center to (-50, 0)
      final pinched = CropTransformMath.computeFocalZoomOffset(
        startOffsetPx: Offset.zero,
        startScale: 1.0,
        newScale: 2.0,
        startFocalFromCropCenter: const Offset(50, 0),
        currentFocalFromCropCenter: const Offset(50, 0),
      );
      expect(pinched, const Offset(-50, 0));
    });
  });

  group('CropTransformMath pixel-accuracy tests', () {
    test('panning and rotating crop the exact expected pixels', () async {
      final src = await _createRedBlueImage(width: 200, height: 100);
      addTearDown(src.dispose);

      // 1. Centered 1:1 crop -> left edge red, right edge blue
      final centeredBytes = await CropTransformMath.cropImageToPng(
        image: src,
        quarterTurns: 0,
        aspectRatio: 1.0,
        scale: 1.0,
        normalizedOffset: Offset.zero,
        outputWidth: 64,
        outputHeight: 64,
      );
      final centeredImg = await decodeImageFromList(centeredBytes);
      addTearDown(centeredImg.dispose);
      expect(centeredImg.width, 64);
      expect(centeredImg.height, 64);
      final leftPx = await _samplePixel(centeredImg, 8, 32);
      final rightPx = await _samplePixel(centeredImg, 56, 32);
      expect(leftPx.$1, greaterThan(240));
      expect(leftPx.$3, lessThan(15));
      expect(rightPx.$3, greaterThan(240));
      expect(rightPx.$1, lessThan(15));

      // 2. Pan image right (+0.5) => brings left (red) half fully into crop box
      final redBytes = await CropTransformMath.cropImageToPng(
        image: src,
        quarterTurns: 0,
        aspectRatio: 1.0,
        scale: 1.0,
        normalizedOffset: const Offset(0.5, 0.0),
        outputWidth: 64,
        outputHeight: 64,
      );
      final redImg = await decodeImageFromList(redBytes);
      addTearDown(redImg.dispose);
      final redRightEdge = await _samplePixel(redImg, 56, 32);
      expect(redRightEdge.$1, greaterThan(240));
      expect(redRightEdge.$3, lessThan(15));

      // 3. Pan image left (-0.5) => brings right (blue) half fully into crop box
      final blueBytes = await CropTransformMath.cropImageToPng(
        image: src,
        quarterTurns: 0,
        aspectRatio: 1.0,
        scale: 1.0,
        normalizedOffset: const Offset(-0.5, 0.0),
        outputWidth: 64,
        outputHeight: 64,
      );
      final blueImg = await decodeImageFromList(blueBytes);
      addTearDown(blueImg.dispose);
      final blueLeftEdge = await _samplePixel(blueImg, 8, 32);
      expect(blueLeftEdge.$3, greaterThan(240));
      expect(blueLeftEdge.$1, lessThan(15));

      // 4. Rotate 90 deg clockwise => left (red) becomes top, right (blue) becomes bottom
      final rotatedBytes = await CropTransformMath.cropImageToPng(
        image: src,
        quarterTurns: 1,
        aspectRatio: 1.0,
        scale: 1.0,
        normalizedOffset: Offset.zero,
        outputWidth: 64,
        outputHeight: 64,
      );
      final rotatedImg = await decodeImageFromList(rotatedBytes);
      addTearDown(rotatedImg.dispose);
      final topPx = await _samplePixel(rotatedImg, 32, 8);
      final bottomPx = await _samplePixel(rotatedImg, 32, 56);
      expect(topPx.$1, greaterThan(240));
      expect(bottomPx.$3, greaterThan(240));

      // 5. 16:9 banner output dimensions
      final bannerBytes = await CropTransformMath.cropImageToPng(
        image: src,
        quarterTurns: 0,
        aspectRatio: 16 / 9,
        scale: 1.0,
        normalizedOffset: Offset.zero,
        outputWidth: 160,
        outputHeight: 90,
      );
      final bannerImg = await decodeImageFromList(bannerBytes);
      addTearDown(bannerImg.dispose);
      expect(bannerImg.width, 160);
      expect(bannerImg.height, 90);
    });
  });

  group('ImageCropperDialog widget tests', () {
    testWidgets('allows drag, zoom, rotate, reset, and saving cropped bytes', (
      tester,
    ) async {
      late Uint8List sourcePng;
      await tester.runAsync(() async {
        final img = await _createRedBlueImage(width: 200, height: 100);
        sourcePng = await _imageToPngBytes(img);
        img.dispose();
      });

      Uint8List? croppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    croppedResult = await ImageCropperDialog.show(
                      context,
                      imageBytes: sourcePng,
                      aspectRatio: 1.0,
                      isCircle: true,
                      title: 'Adjust Profile Photo',
                      outputWidth: 64,
                      outputHeight: 64,
                    );
                  },
                  child: const Text('Open Cropper'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cropper'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Adjust Profile Photo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Rotate Left'), findsOneWidget);
      expect(find.text('Rotate Right'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Drag on the stage to pan
      final stageFinder = find.byType(GestureDetector).first;
      await tester.drag(stageFinder, const Offset(80, 0));
      await tester.pump();

      // Zoom in via icon button
      await tester.tap(find.byTooltip('Zoom In'));
      await tester.pump();

      // Rotate right then reset
      await tester.tap(find.text('Rotate Right'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await tester.pump();

      // Drag right so left (red) side moves into the crop box, then save
      await tester.drag(stageFinder, const Offset(200, 0));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(croppedResult, isNotNull);
      expect(croppedResult!.isNotEmpty, isTrue);

      await tester.runAsync(() async {
        final outImg = await decodeImageFromList(croppedResult!);
        expect(outImg.width, 64);
        expect(outImg.height, 64);
        final centerPx = await _samplePixel(outImg, 32, 32);
        expect(centerPx.$1, greaterThan(240));
        expect(centerPx.$3, lessThan(15));
        outImg.dispose();
      });
    });

    testWidgets('returns null when cancelled', (tester) async {
      late Uint8List sourcePng;
      await tester.runAsync(() async {
        final img = await _createRedBlueImage(width: 100, height: 100);
        sourcePng = await _imageToPngBytes(img);
        img.dispose();
      });

      Uint8List? croppedResult = Uint8List.fromList([1]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  croppedResult = await ImageCropperDialog.show(
                    context,
                    imageBytes: sourcePng,
                    title: 'Adjust Banner',
                    aspectRatio: 16 / 9,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(croppedResult, isNull);
    });

    testWidgets('shows graceful error state for corrupt image bytes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageCropperDialog(
            imageBytes: Uint8List.fromList([0, 1, 2, 3]),
            title: 'Adjust Profile Photo',
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load this image. Please try another photo.'),
        findsOneWidget,
      );
      expect(find.text('Go Back'), findsOneWidget);
    });
  });
}
