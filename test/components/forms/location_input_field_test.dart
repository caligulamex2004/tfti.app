import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:tftiapp/components/forms/location_input_field.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('LocationInputField Widget & Regression Tests', () {
    testWidgets('Renders LocationInputField with label and hint when empty', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationInputField(
              controller: controller,
              isPast: false,
            ),
          ),
        ),
      );

      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Tap to search address...'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('Displays location text when controller is populated', (tester) async {
      final controller = TextEditingController(text: '1234 Main St, Atlanta, GA 30301');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationInputField(
              controller: controller,
              isPast: false,
            ),
          ),
        ),
      );

      expect(find.text('1234 Main St, Atlanta, GA 30301'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('Disables interaction when isPast is true', (tester) async {
      final controller = TextEditingController(text: 'Pebble Beach Golf Links');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationInputField(
              controller: controller,
              isPast: true,
            ),
          ),
        ),
      );

      final iconBtn = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconBtn.onPressed, isNull);
    });
  });
}
