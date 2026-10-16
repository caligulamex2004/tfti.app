import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/web_update_banner.dart';
import 'package:tftiapp/services/web_update_service.dart';
import 'package:tftiapp/utils/app_version.dart';

void main() {
  group('WebUpdateService & Banner Tests', () {
    tearDown(() {
      WebUpdateService.instance.dismiss();
    });

    test('AppVersion matches pubspec.yaml version and buildNumber', () {
      expect(AppVersion.version, isNotEmpty);
      expect(AppVersion.buildNumber, isA<int>());
      expect(AppVersion.buildNumber, greaterThanOrEqualTo(1));

      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([^\s+]+)\+(\d+)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml must declare version: x.y.z+n');
      expect(AppVersion.version, equals(match!.group(1)));
      expect(AppVersion.buildNumber, equals(int.parse(match.group(2)!)));
    });

    test('WebUpdateService singleton initializes with updateAvailable false', () {
      final service = WebUpdateService.instance;
      service.dismiss();
      expect(service.updateAvailable.value, isFalse);
    });

    test('WebUpdateService dismiss() resets updateAvailable to false', () {
      final service = WebUpdateService.instance;
      service.updateAvailable.value = true;
      expect(service.updateAvailable.value, isTrue);

      service.dismiss();
      expect(service.updateAvailable.value, isFalse);
    });

    testWidgets(
      'WebUpdateBannerWrapper renders child widget without crashing',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: WebUpdateBannerWrapper(
              child: Scaffold(
                body: Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        expect(find.text('App Content'), findsOneWidget);
      },
    );

    testWidgets(
      'Hovering and clicking close button inside MaterialApp.builder (no Overlay) does not distort or crash',
      (WidgetTester tester) async {
        WebUpdateService.instance.updateAvailable.value = true;

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, widget) {
              return WebUpdateBannerWrapper(
                debugForceWeb: true,
                child: widget ?? const SizedBox.shrink(),
              );
            },
            home: const Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        );

        expect(find.text('Update Available'), findsOneWidget);
        expect(find.text('Update Now'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Verify banner is compact before hover
        final initialBannerSize = tester.getSize(
          find.ancestor(
            of: find.text('Update Available'),
            matching: find.byType(Container),
          ).first,
        );
        expect(initialBannerSize.height, lessThan(120));

        // Simulate mouse hover over the close button (where Tooltip previously threw No Overlay found)
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.byIcon(Icons.close)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.close), findsOneWidget);

        final hoveredBannerSize = tester.getSize(
          find.ancestor(
            of: find.text('Update Available'),
            matching: find.byType(Container),
          ).first,
        );
        expect(hoveredBannerSize.height, equals(initialBannerSize.height));

        // Clicking close dismisses the banner
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(WebUpdateService.instance.updateAvailable.value, isFalse);
        expect(find.text('Update Available'), findsNothing);
      },
    );

    testWidgets(
      'Clicking Update Now hides the banner and triggers reload cleanly',
      (WidgetTester tester) async {
        WebUpdateService.instance.updateAvailable.value = true;

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, widget) {
              return WebUpdateBannerWrapper(
                debugForceWeb: true,
                child: widget ?? const SizedBox.shrink(),
              );
            },
            home: const Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        );

        expect(find.text('Update Now'), findsOneWidget);
        await tester.tap(find.text('Update Now'));
        await tester.pump();

        expect(WebUpdateService.instance.updateAvailable.value, isFalse);
        expect(find.text('Update Available'), findsNothing);
      },
    );
  });
}
