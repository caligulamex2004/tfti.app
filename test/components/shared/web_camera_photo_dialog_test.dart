import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/web_camera_photo_dialog.dart';

void main() {
  testWidgets('WebCameraPhotoDialog.show resolves safely on non-web platform', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final result = await WebCameraPhotoDialog.show(context);
                expect(result, isNull);
              },
              child: const Text('Capture'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
