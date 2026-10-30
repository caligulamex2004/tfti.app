import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tftiapp/components/shared/app_logo.dart';

void main() {
  testWidgets('AppLogo renders SvgPicture with specified size and color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(
            size: 64,
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);

    final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svgPicture.width, 64);
    expect(svgPicture.height, 64);
  });

  testWidgets('AppLogo inherits size and color from IconTheme when omitted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IconTheme(
            data: IconThemeData(
              size: 48,
              color: Colors.red,
            ),
            child: AppLogo(),
          ),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svgPicture.width, 48);
    expect(svgPicture.height, 48);
  });
}
