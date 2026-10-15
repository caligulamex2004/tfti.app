import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A platform-aware avatar widget that displays user profile pictures with robust fallbacks.
///
/// On Web: Uses native [NetworkImage] with browser HTTP caching to prevent
/// blob URL eviction and cache-manager detachment across route transitions.
/// On Mobile: Uses [CachedNetworkImageProvider] for persistent local disk caching.
///
/// Always provides the monogram letter child on top of [avatarColor] so that if
/// an avatar image fails or is loading, the user's monogram is displayed rather
/// than a blank colored circle.
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

  ImageProvider? get _imageProvider {
    if (avatarUrl == null || avatarUrl!.trim().isEmpty) return null;
    final cleanUrl = avatarUrl!.trim();
    if (kIsWeb) {
      // Browser-native HTTP caching without IndexedDB blob URL eviction
      return NetworkImage(cleanUrl);
    }
    // Mobile persistent disk cache
    return CachedNetworkImageProvider(cleanUrl);
  }

  @override
  Widget build(BuildContext context) {
    final monogram = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor,
      backgroundImage: _imageProvider,
      onBackgroundImageError: avatarUrl != null && avatarUrl!.trim().isNotEmpty
          ? (exception, stackTrace) {
              debugPrint("AppAvatar image load error for $avatarUrl: $exception");
            }
          : null,
      // Always provide the monogram child so if image fails or is loading,
      // the monogram is visible against the signature color.
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

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
