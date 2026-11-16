import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:tftiapp/components/squad/qr_duo_sheet.dart';
import 'package:tftiapp/models/user_profile.dart';
import 'package:tftiapp/services/app_shortcut_service.dart';
import 'package:tftiapp/services/app_toast.dart';

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

    testWidgets(
      'QrDuoSheet.show opens Scan Code tab without warning when initialScanTab is true and username is empty',
      (WidgetTester tester) async {
        final toasts = <AppToastMessage>[];
        final StreamSubscription<AppToastMessage> sub = AppToast.onToast.listen(
          toasts.add,
        );
        addTearDown(sub.cancel);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      QrDuoSheet.show(
                        context,
                        username: '',
                        displayName: '',
                        avatarColor: Colors.blue.toARGB32(),
                        initialScanTab: true,
                        onScanned: (_) {},
                      );
                    },
                    child: const Text('Open Scan'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Scan'));
        await tester.pumpAndSettle();

        expect(find.byType(QrDuoSheet), findsOneWidget);
        expect(find.text("Point at a friend's TFTI QR Code"), findsOneWidget);
        expect(toasts, isEmpty);
      },
    );

    testWidgets(
      'QrDuoSheet.show warns and stays closed when initialScanTab is false and username is empty',
      (WidgetTester tester) async {
        final toasts = <AppToastMessage>[];
        final StreamSubscription<AppToastMessage> sub = AppToast.onToast.listen(
          toasts.add,
        );
        addTearDown(sub.cancel);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      QrDuoSheet.show(
                        context,
                        username: '',
                        displayName: '',
                        avatarColor: Colors.blue.toARGB32(),
                        initialScanTab: false,
                        onScanned: (_) {},
                      );
                    },
                    child: const Text('Open QR'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open QR'));
        await tester.pumpAndSettle();

        expect(find.byType(QrDuoSheet), findsNothing);
        expect(toasts.length, equals(1));
        expect(
          toasts.single.message,
          equals('Please set a username in Account first to use QR!'),
        );
      },
    );

    testWidgets(
      'QrDuoSheet updates My Code tab reactively when profileListenable resolves',
      (WidgetTester tester) async {
        final profileNotifier = ValueNotifier<UserProfile?>(null);
        addTearDown(profileNotifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QrDuoSheet(
                username: '',
                displayName: '',
                avatarColor: Colors.blue.toARGB32(),
                initialScanTab: true,
                profileListenable: profileNotifier,
                onScanned: (_) {},
              ),
            ),
          ),
        );

        // Switch to My Code tab while profile is still loading/empty
        await tester.tap(find.text('My Code'));
        await tester.pump();
        expect(
          find.text(
            'Please set a username in Account first to share your QR code.',
          ),
          findsOneWidget,
        );

        // Profile arrives asynchronously
        profileNotifier.value = const UserProfile(
          uid: 'u1',
          displayName: 'Alex Rivera',
          username: 'arivera',
        );
        await tester.pump();

        expect(find.text('@arivera'), findsOneWidget);
        expect(find.text('Copy My Invite Link'), findsOneWidget);
      },
    );
  });
}
