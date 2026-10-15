import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A platform-aware avatar widget that displays user profile pictures with robust fallbacks.
///
/// Order of operations:
/// 1. If [avatarUrl] is null or empty, displays [avatarColor] with the user's [monogram].
/// 2. If [avatarUrl] is provided:
///    - While loading or on error: displays [avatarColor] with the [monogram].
///    - When successfully loaded: displays the image cleanly WITHOUT superimposing the monogram.
///
/// Platform considerations:
/// - On Web: Uses native [Image.network] with browser HTTP caching to prevent
///   blob URL eviction and IndexedDB cache-manager detachment across route transitions.
/// - On Mobile: Uses [CachedNetworkImage] for persistent local disk caching.
class AppAvatar extends StatelessWidget {
  final String? avatarUrl;
  final Color avatarColor;
  final String displayName;
  final double radius;
  final double? fontSize;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.avatarUrl,
    required this.avatarColor,
    required this.displayName,
    this.radius = 20,
    this.fontSize,
    this.textStyle,
    this.onTap,
  });

  /// Factory constructor that handles raw color values (e.g. int from Firestore or Color).
  factory AppAvatar.fromColorValue({
    Key? key,
    required String? avatarUrl,
    required dynamic avatarColor,
    required String displayName,
    double radius = 20,
    double? fontSize,
    TextStyle? textStyle,
    VoidCallback? onTap,
    Color fallbackColor = const Color(0xFF9E9E9E),
  }) {
    Color resolvedColor = fallbackColor;
    if (avatarColor is Color) {
      resolvedColor = avatarColor;
    } else if (avatarColor is int) {
      resolvedColor = Color(avatarColor);
    } else if (avatarColor is String) {
      final parsed = int.tryParse(avatarColor);
      if (parsed != null) resolvedColor = Color(parsed);
    }

    return AppAvatar(
      key: key,
      avatarUrl: avatarUrl,
      avatarColor: resolvedColor,
      displayName: displayName,
      radius: radius,
      fontSize: fontSize,
      textStyle: textStyle,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monogram = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    final Widget fallback = CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor,
      child: Text(
        monogram,
        style: textStyle ??
            TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize ?? (radius * 0.75),
            ),
      ),
    );

    final cleanUrl = avatarUrl?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) {
      return _wrapTap(fallback);
    }

    Widget avatar;
    if (kIsWeb) {
      // On Web: Native Image.network with browser HTTP caching.
      // While loading or on error, display the fallback monogram.
      // Once loaded, display the circular image without the monogram.
      avatar = SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          cleanUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return ClipOval(
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  color: avatarColor,
                  child: child,
                ),
              );
            }
            return fallback;
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    } else {
      // On Mobile: CachedNetworkImage with persistent disk cache.
      // imageBuilder renders without child so monogram is never superimposed.
      // placeholder and errorWidget display fallback monogram.
      avatar = SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: CachedNetworkImage(
          imageUrl: cleanUrl,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: radius,
            backgroundColor: avatarColor,
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => fallback,
          errorWidget: (context, url, error) => fallback,
        ),
      );
    }

    return _wrapTap(avatar);
  }

  Widget _wrapTap(Widget child) {
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return child;
  }
}
