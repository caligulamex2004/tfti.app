import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:tftiapp/components/squad/qr_duo_sheet.dart';
import 'package:tftiapp/services/app_shortcut_service.dart';

class _FakeQuickActions implements QuickActions {
  QuickActionHandler? capturedHandler;
  List<ShortcutItem> registeredItems = const [];
  bool cleared = false;

  @override
  Future<void> initialize(QuickActionHandler handler) async {
    capturedHandler = handler;
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    registeredItems = items;
  }

  @override
  Future<void> clearShortcutItems() async {
    cleared = true;
    registeredItems = const [];
  }
}

void main() {
  setUp(() {
    AppShortcutService.instance.resetForTest();
  });

  group('AppShortcutService Tests', () {
    test('fromId parses all canonical shortcut IDs and rejects invalid ones', () {
      expect(
        AppShortcutAction.fromId('plan_hangout'),
        AppShortcutAction.planHangout,
      );
      expect(
        AppShortcutAction.fromId(' VIBE_CHECK '),
        AppShortcutAction.vibeCheck,
      );
      expect(AppShortcutAction.fromId('scan_qr'), AppShortcutAction.scanQr);
      expect(AppShortcutAction.fromId('squad'), AppShortcutAction.squad);
      expect(AppShortcutAction.fromId('unknown'), isNull);
      expect(AppShortcutAction.fromId(null), isNull);
    });

    test('init on Web parses ?shortcut= query param and consume clears it', () async {
      await AppShortcutService.instance.init(
        isWebOverride: true,
        initialWebUri: Uri.parse('https://tfti-app.web.app/?shortcut=scan_qr'),
      );

      expect(
        AppShortcutService.instance.pendingAction.value,
        AppShortcutAction.scanQr,
      );
      expect(
        AppShortcutService.instance.consumePendingAction(),
        AppShortcutAction.scanQr,
      );
      expect(AppShortcutService.instance.pendingAction.value, isNull);
    });

    test('init on mobile registers 4 QuickActions and handles callbacks', () async {
      final fake = _FakeQuickActions();

      await AppShortcutService.instance.init(
        isWebOverride: false,
        platformOverride: TargetPlatform.iOS,
        quickActionsOverride: fake,
      );

      expect(fake.registeredItems.length, equals(4));
      expect(
        fake.registeredItems.map((e) => e.type).toList(),
        equals(['plan_hangout', 'vibe_check', 'scan_qr', 'squad']),
      );

      fake.capturedHandler?.call('vibe_check');
      expect(
        AppShortcutService.instance.consumePendingAction(),
        AppShortcutAction.vibeCheck,
      );
    });

    test('requestOpenQrScanner increments scanQrTrigger', () {
      expect(AppShortcutService.instance.scanQrTrigger.value, equals(0));
      AppShortcutService.instance.requestOpenQrScanner();
      expect(AppShortcutService.instance.scanQrTrigger.value, equals(1));
    });
  });

  group('QrDuoSheet initialScanTab Test', () {
    testWidgets('Opens directly on Scan Code tab when initialScanTab is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrDuoSheet(
              username: 'red_trainer',
              displayName: 'Red Champion',
              avatarColor: Colors.red.toARGB32(),
              initialScanTab: true,
              onScanned: (_) {},
            ),
          ),
        ),
      );

      // Copy My Invite Link is only shown on the My Code tab (index 0)
      expect(find.text('Copy My Invite Link'), findsNothing);
      expect(find.text('Scan Code'), findsOneWidget);
    });
  });
}
