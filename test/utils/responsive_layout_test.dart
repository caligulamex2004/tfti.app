import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/utils/responsive_layout.dart';

void main() {
  group('ResponsiveLayout Utilities & Extension Tests', () {
    testWidgets('isWideScreen returns true when width > 840 even if height > width (tall desktop window)', (tester) async {
      late bool isWide;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1000, 1400), // width > 840, but height > width (portrait aspect ratio)
            ),
            child: Builder(
              builder: (context) {
                isWide = context.isWideScreen;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(isWide, isTrue);
    });

    testWidgets('isWideScreen returns true for landscape orientation when width > 600', (tester) async {
      late bool isWide;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(720, 450), // landscape aspect ratio & width > 600
            ),
            child: Builder(
              builder: (context) {
                isWide = context.isWideScreen;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(isWide, isTrue);
    });

    testWidgets('isWideScreen returns false for mobile portrait screen', (tester) async {
      late bool isWide;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844), // typical mobile portrait
            ),
            child: Builder(
              builder: (context) {
                isWide = context.isWideScreen;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(isWide, isFalse);
    });
  });

  group('AppMaxWidthContainer Widget Tests', () {
    testWidgets('Caps layout width at 1600px on ultrawide viewports (2560px) and updates child MediaQuery', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Size? childReportedSize;
      BoxConstraints? childConstraints;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppMaxWidthContainer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  childConstraints = constraints;
                  childReportedSize = MediaQuery.sizeOf(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      expect(childConstraints?.maxWidth, equals(kMaxAppWidth));
      expect(childReportedSize?.width, equals(kMaxAppWidth));
      expect(childReportedSize?.height, equals(1440));
    });

    testWidgets('Does not clamp or add borders on viewports under 1600px', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Size? childReportedSize;
      BoxConstraints? childConstraints;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppMaxWidthContainer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  childConstraints = constraints;
                  childReportedSize = MediaQuery.sizeOf(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      expect(childConstraints?.maxWidth, equals(1200));
      expect(childReportedSize?.width, equals(1200));
    });
  });

  group('CenteredContentColumn Widget Tests', () {
    testWidgets('Constrains child width to kMaxSingleColumnContentWidth (800) and centers it', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      BoxConstraints? innerConstraints;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CenteredContentColumn(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  innerConstraints = constraints;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      expect(innerConstraints?.maxWidth, equals(kMaxSingleColumnContentWidth));
    });
  });
}
