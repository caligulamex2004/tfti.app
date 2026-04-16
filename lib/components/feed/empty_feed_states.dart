import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class EmptyFeedState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;

  const EmptyFeedState({super.key, this.title, this.subtitle, this.icon});

  // --- NAMED CONSTRUCTORS FOR SPECIFIC TABS ---

  factory EmptyFeedState.hosting() {
    return const EmptyFeedState(
      title: "You aren't hosting any hangouts.",
      subtitle: "Tap + to throw a hangout or a vibe check!",
      icon: Symbols.celebration,
    );
  }

  factory EmptyFeedState.past() {
    return const EmptyFeedState(
      title: "No past hangouts.",
      subtitle: "Your history is clean.",
      icon: Icons.history,
    );
  }

  factory EmptyFeedState.hidden() {
    return const EmptyFeedState(
      title: "No hidden events.",
      subtitle: "You haven't archived anything.",
      icon: Icons.visibility_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.event_available,
            size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title ?? "You're all caught up!",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? "Tap + to start something.",
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class FeedDetailPlaceholder extends StatelessWidget {
  const FeedDetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Tap an event to view details",
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
