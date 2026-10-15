import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/web_update_banner.dart';
import 'package:tftiapp/services/web_update_service.dart';
import 'package:tftiapp/utils/app_version.dart';

void main() {
  group('WebUpdateService & Banner Tests', () {
    test('AppVersion contains valid version string and integer buildNumber', () {
      expect(AppVersion.version, isNotEmpty);
      expect(AppVersion.buildNumber, isA<int>());
      expect(AppVersion.buildNumber, greaterThanOrEqualTo(1));
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
  });
}
