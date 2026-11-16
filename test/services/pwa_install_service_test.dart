import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tftiapp/components/account/account_settings_card.dart';
import 'package:tftiapp/components/feed/web_pwa_install_banner.dart';
import 'package:tftiapp/components/shared/pwa_install_guide_sheet.dart';
import 'package:tftiapp/services/pwa_install_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PwaInstallService.instance.resetForTest();
  });

  group('PwaInstallService Tests', () {
    test('resolveMode selects appropriate UX across browser states', () {
      final service = PwaInstallService.instance;

      expect(
        service.resolveMode(
          isWebOverride: false,
          snapshotOverride: const PwaInstallSnapshot(canNativePrompt: true),
        ),
        PwaInstallMode.none,
      );

      expect(
        service.resolveMode(
          isWebOverride: true,
          snapshotOverride: const PwaInstallSnapshot(
            isStandalone: true,
            canNativePrompt: true,
            isIos: true,
            isIosSafari: true,
          ),
        ),
        PwaInstallMode.none,
      );

      expect(
        service.resolveMode(
          isWebOverride: true,
          snapshotOverride: const PwaInstallSnapshot(canNativePrompt: true),
        ),
        PwaInstallMode.nativePrompt,
      );

      expect(
        service.resolveMode(
          isWebOverride: true,
          snapshotOverride: const PwaInstallSnapshot(
            isIos: true,
            isIosSafari: true,
          ),
        ),
        PwaInstallMode.iosSafariGuide,
      );

      expect(
        service.resolveMode(
          isWebOverride: true,
          snapshotOverride: const PwaInstallSnapshot(
            isIos: true,
            isIosSafari: false,
          ),
        ),
        PwaInstallMode.iosOtherBrowserGuide,
      );

      expect(
        service.resolveMode(
          isWebOverride: true,
          snapshotOverride: const PwaInstallSnapshot(),
        ),
        PwaInstallMode.none,
      );
    });
  });

  group('WebPwaInstallBanner & PwaInstallGuideSheet Tests', () {
    testWidgets('Renders SizedBox.shrink on non-web platform', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WebPwaInstallBanner(isWebOverride: false)),
        ),
      );

      expect(find.text('Get the TFTI App Icon'), findsNothing);
    });

    testWidgets('Renders Install button on Chromium and dismisses on close', (
      WidgetTester tester,
    ) async {
      PwaInstallService.instance.setTestState(
        snapshot: const PwaInstallSnapshot(canNativePrompt: true),
        bannerDismissed: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WebPwaInstallBanner(isWebOverride: true)),
        ),
      );
      await tester.pump();

      expect(find.text('Get the TFTI App Icon'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();

      expect(find.text('Get the TFTI App Icon'), findsNothing);
      expect(PwaInstallService.instance.isBannerDismissed, isTrue);
    });

    testWidgets('Opens iOS Safari Add to Home Screen guide from How To CTA', (
      WidgetTester tester,
    ) async {
      PwaInstallService.instance.setTestState(
        snapshot: const PwaInstallSnapshot(isIos: true, isIosSafari: true),
        bannerDismissed: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WebPwaInstallBanner(isWebOverride: true)),
        ),
      );
      await tester.pump();

      expect(find.text('How To'), findsOneWidget);
      await tester.tap(find.text('How To'));
      await tester.pumpAndSettle();

      expect(find.text('Add TFTI to Home Screen'), findsOneWidget);
      expect(find.text('1. Tap the Share button in Safari'), findsOneWidget);
      expect(
        find.text('2. Scroll down & tap "Add to Home Screen"'),
        findsOneWidget,
      );

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Add TFTI to Home Screen'), findsNothing);
    });

    testWidgets('PwaInstallGuideSheet warns about in-app browsers when needed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PwaInstallGuideSheet(
              mode: PwaInstallMode.iosOtherBrowserGuide,
              isInAppBrowser: true,
            ),
          ),
        ),
      );

      expect(find.text('1. Open in Safari first'), findsOneWidget);
    });

    testWidgets(
      'AccountSettingsCard shows Add to Home Screen on iOS Web and hides in standalone',
      (WidgetTester tester) async {
        PwaInstallService.instance.setTestState(
          snapshot: const PwaInstallSnapshot(isIos: true, isIosSafari: true),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AccountSettingsCard(
                  onPreferencesTap: () {},
                  onTipJarTap: () {},
                  isWebOverride: true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Add to Home Screen'), findsOneWidget);

        PwaInstallService.instance.setTestState(
          snapshot: const PwaInstallSnapshot(
            isStandalone: true,
            isIos: true,
            isIosSafari: true,
          ),
        );
        await tester.pump();

        expect(find.text('Add to Home Screen'), findsNothing);
      },
    );
  });
}
