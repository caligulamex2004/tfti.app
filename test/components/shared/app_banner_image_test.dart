import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/shared/app_banner_image.dart';

void main() {
  testWidgets('AppBannerImage renders CachedNetworkImage on non-web platform', (tester) async {
    const testUrl = 'https://example.com/banner.jpg';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppBannerImage(
            imageUrl: testUrl,
            width: 300,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    final cachedImageFinder = find.byType(CachedNetworkImage);
    expect(cachedImageFinder, findsOneWidget);

    final cachedImage = tester.widget<CachedNetworkImage>(cachedImageFinder);
    expect(cachedImage.imageUrl, testUrl);
    expect(cachedImage.width, 300);
    expect(cachedImage.height, 150);
    expect(cachedImage.fit, BoxFit.cover);
  });

  testWidgets('AppBannerImage uses custom placeholder and errorWidget when provided', (tester) async {
    const testUrl = 'https://example.com/banner.jpg';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppBannerImage(
            imageUrl: testUrl,
            placeholder: (context, url) => const Text('Custom Placeholder'),
            errorWidget: (context, url, error) => const Text('Custom Error'),
          ),
        ),
      ),
    );

    final cachedImageFinder = find.byType(CachedNetworkImage);
    expect(cachedImageFinder, findsOneWidget);

    final cachedImage = tester.widget<CachedNetworkImage>(cachedImageFinder);
    expect(cachedImage.placeholder, isNotNull);
    expect(cachedImage.errorWidget, isNotNull);
  });
}
