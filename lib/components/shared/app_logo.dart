import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the BearMoose branded vector logo (cute bear face crowned with moose antlers).
///
/// If [size] or [color] are omitted, they will default to the current [IconTheme]
/// or the theme's primary color.
class AppLogo extends StatelessWidget {
  /// The width and height of the logo in logical pixels.
  final double? size;

  /// The tint color applied to the monochrome vector silhouette.
  final Color? color;

  /// Semantic label for screen readers.
  final String? semanticsLabel;

  const AppLogo({
    super.key,
    this.size,
    this.color,
    this.semanticsLabel = 'BearMoose logo',
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size ?? 24.0;
    final effectiveColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.primary;

    return SvgPicture.asset(
      'assets/icon/app_logo.svg',
      width: effectiveSize,
      height: effectiveSize,
      semanticsLabel: semanticsLabel,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}
