import 'package:flutter/material.dart';

/// Global maximum interactive width for the application on desktop and large screens.
const double kMaxAppWidth = 1600.0;

/// Comfortable content width for single-column reading and messaging views (e.g. Chat, VIP Places).
const double kMaxSingleColumnContentWidth = 800.0;

/// Breakpoint width where multi-column desktop layouts and side navigation rails engage.
const double kWideScreenBreakpoint = 840.0;

/// Responsive extensions for [BuildContext].
extension ResponsiveContext on BuildContext {
  /// Returns `true` if the current viewport is considered a wide screen.
  ///
  /// This engages multi-column layouts whenever the available width exceeds
  /// [kWideScreenBreakpoint] (regardless of height), or when the device is in
  /// landscape orientation with width > 600.
  bool get isWideScreen {
    final size = MediaQuery.sizeOf(this);
    return size.width > kWideScreenBreakpoint ||
        (MediaQuery.orientationOf(this) == Orientation.landscape && size.width > 600);
  }
}

/// A wrapper that centers its [child] and constrains its maximum interactive width
/// to [maxWidth] (defaults to [kMaxAppWidth]).
///
/// When the available viewport width exceeds [maxWidth], the surrounding area is
/// filled with the current theme's scaffold background, and subtle vertical borders
/// delineate the active app canvas. It also adjusts the [MediaQuery] size so child
/// widgets receive clamped layout constraints.
class AppMaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppMaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = kMaxAppWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final bool isCapped = availableWidth > maxWidth;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

        Widget content = child;

        if (isCapped) {
          final mediaQuery = MediaQuery.maybeOf(context);
          if (mediaQuery != null) {
            content = MediaQuery(
              data: mediaQuery.copyWith(
                size: Size(maxWidth, mediaQuery.size.height),
              ),
              child: content,
            );
          }
        }

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                content,
                if (isCapped)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            vertical: BorderSide(
                              color: borderColor,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A wrapper for single-column views (like Chat and VIP Places) that constrains content
/// to [maxWidth] (defaults to [kMaxSingleColumnContentWidth]) and centers it horizontally.
class CenteredContentColumn extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CenteredContentColumn({
    super.key,
    required this.child,
    this.maxWidth = kMaxSingleColumnContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
