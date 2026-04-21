import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../pages/hangout_editor_page.dart';
import '../../pages/vibe_check_editor_page.dart';

class FeedSliverAppBar extends StatelessWidget {
  final String firstName;

  const FeedSliverAppBar({
    super.key,
    required this.firstName,
  });

  void _showAddMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  Icons.how_to_vote,
                  size: 28,
                  color: primaryColor,
                ),
                title: const Text(
                  "Hangout",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text("Let the squad know what's happening."),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HangoutEditorPage(),
                    ),
                  );
                },
              ),
              Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ListTile(
                leading: Icon(
                  Symbols.earthquake,
                  size: 28,
                  color: primaryColor,
                ),
                title: const Text(
                  "Vibe Check",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text("Give options and let the squad decide."),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VibeCheckEditorPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = "Good morning";
    } else if (hour < 17) {
      greeting = "Good afternoon";
    } else {
      greeting = "Good evening";
    }

    return SliverAppBar(
      expandedHeight: isLandscape ? 56.0 : 140.0,
      pinned: true,
      stretch: false,
      backgroundColor: isDark 
          ? Colors.black.withValues(alpha: 0.6) 
          : Colors.white.withValues(alpha: 0.7),
      elevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Center(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _showAddMenu(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: primaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Create",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double topPadding = MediaQuery.of(context).padding.top;
              final double collapsedHeight = kToolbarHeight + topPadding;
              final double expandRatio = isLandscape 
                  ? 0.0 
                  : ((constraints.maxHeight - collapsedHeight) / (140.0 - collapsedHeight)).clamp(0.0, 1.0);
              
              final double expandedOpacity = (expandRatio - 0.5).clamp(0.0, 0.5) * 2.0;
              final double collapsedOpacity = (0.5 - expandRatio).clamp(0.0, 0.5) * 2.0;
              
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Dynamic Background Gradient fading out as it collapses
                  Opacity(
                    opacity: expandRatio,
                    child: Container(
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
                  if (!isLandscape)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0, left: 20.0),
                        child: Opacity(
                          opacity: collapsedOpacity,
                          child: Text(
                            "thanks for the invite",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              fontSize: 18,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Expanded Personalized Greeting
                  Positioned(
                    left: 20,
                    bottom: 50 + (expandRatio * 15), 
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: Text(
                        "$greeting, $firstName",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),

                  // Expanded "the i's" Title
                  Positioned(
                    left: 20,
                    bottom: 16,
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: Text(
                        "the i's",
                        style: TextStyle(
                          fontSize: 32 + (expandRatio * 4),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
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
