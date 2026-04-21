import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/theme_provider.dart';

class SharedSliverAppBar extends StatelessWidget {
  final String title;
  final String collapsedTitle;
  final double expandedHeight;
  final List<Widget>? actions;
  final Widget? background;
  final Widget? topBadges;
  final Widget? bottomContent;
  final bool hasBackButton;

  const SharedSliverAppBar({
    super.key,
    required this.title,
    required this.collapsedTitle,
    required this.expandedHeight,
    this.actions,
    this.background,
    this.topBadges,
    this.bottomContent,
    this.hasBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.7),
      elevation: 0,
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : Colors.black87,
      ),
      actions: actions,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double topPadding = MediaQuery.of(context).padding.top;
              final double leftPadding = MediaQuery.of(context).padding.left;
              final double rightPadding = MediaQuery.of(context).padding.right;
              final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
              
              final double collapsedHeight = kToolbarHeight + topPadding;
              final double expandRatio = expandedHeight <= collapsedHeight 
                  ? 0.0 
                  : ((constraints.maxHeight - collapsedHeight) /
                      (expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);

              final double expandedOpacity =
                  (expandRatio - 0.5).clamp(0.0, 0.5) * 2.0;
              final double collapsedOpacity =
                  (0.5 - expandRatio).clamp(0.0, 0.5) * 2.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Optional custom background that fades out as it collapses
                  Opacity(
                    opacity: expandRatio,
                    child: background ??
                        Container(
                          decoration: BoxDecoration(
                            gradient: themeProvider.appGradient,
                          ),
                        ),
                  ),

                  // Collapsed Title
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: 16.0, 
                        left: (hasBackButton ? 56.0 : (isLandscape ? 8.0 : 20.0)) + leftPadding,
                      ),
                      child: Opacity(
                        opacity: collapsedOpacity,
                        child: Text(
                          collapsedTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),

                  // Expanded Content Area
                  Positioned(
                    left: ((isLandscape && hasBackButton) ? 56.0 : (isLandscape ? 8.0 : 20.0)) + leftPadding,
                    right: (isLandscape ? 8.0 : 20.0) + rightPadding,
                    bottom: 20 + (expandRatio * 20),
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (topBadges != null) ...[
                            topBadges!,
                            const SizedBox(height: 8),
                          ],
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (bottomContent != null) ...[
                            const SizedBox(height: 12),
                            bottomContent!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
