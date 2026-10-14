import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../utils/theme_provider.dart';

/// A platform-aware banner image renderer.
///
/// On Web: Uses native [Image.network] with browser-level HTTP caching to avoid
/// blob URL eviction and cache-manager detachment across route transitions.
/// On Mobile: Uses [CachedNetworkImage] for persistent local disk caching.
class AppBannerImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const AppBannerImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          if (placeholder != null) {
            return placeholder!(context, imageUrl);
          }
          return Container(
            decoration: BoxDecoration(
              gradient: themeProvider.appGradient,
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint("AppBannerImage web load error for $imageUrl: $error");
          if (errorWidget != null) {
            return errorWidget!(context, imageUrl, error);
          }
          return Container(
            decoration: BoxDecoration(
              gradient: themeProvider.appGradient,
            ),
          );
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder ??
          (context, url) => Container(
                decoration: BoxDecoration(
                  gradient: themeProvider.appGradient,
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      errorWidget: errorWidget ??
          (context, url, error) {
            debugPrint("AppBannerImage load error for $url: $error");
            return Container(
              decoration: BoxDecoration(
                gradient: themeProvider.appGradient,
              ),
            );
          },
    );
  }
}
