import 'dart:ui';
import 'package:flutter/material.dart';

class SharedSliverAppBar extends StatelessWidget {
  final String title;
  final String collapsedTitle;
  final double expandedHeight;
  final List<Widget>? actions;
  final List<Widget> Function(double expandRatio)? actionsBuilder;
  final Widget? background;
  final Widget? topBadges;
  final String? subtitle;
  final Widget? bottomContent;
  final Color? expandedTitleColor;
  final Color? expandedIconColor;
  final bool hasBackButton;

  const SharedSliverAppBar({
    super.key,
    required this.title,
    required this.collapsedTitle,
    required this.expandedHeight,
    this.actions,
    this.actionsBuilder,
    this.background,
    this.topBadges,
    this.subtitle,
    this.bottomContent,
    this.expandedTitleColor,
    this.expandedIconColor,
    this.hasBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final Color titleColor = expandedTitleColor ?? (isDark ? Colors.white : Colors.black87);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: false,
      backgroundColor: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.7),
      elevation: 0,
      iconTheme: IconThemeData(
        color: expandedIconColor ?? (isDark ? Colors.white : Colors.black87),
      ),
      actions: actionsBuilder != null ? null : actions,
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

              final builtActions = actionsBuilder?.call(expandRatio);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Optional custom background that fades out as it collapses
                  Opacity(
                    opacity: expandRatio,
                    child: background ??
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor.withValues(alpha: 0.15),
                                isDark
                                    ? Colors.black.withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.1),
                              ],
                            ),
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
                          if (subtitle != null) ...[
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
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

                  // Dynamic actions (positioned in the collapsed toolbar area)
                  if (builtActions != null)
                    Positioned(
                      right: 0 + rightPadding,
                      bottom: 8.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: builtActions,
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
