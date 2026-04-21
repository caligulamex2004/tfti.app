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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900.withOpacity(0.5) : Colors.grey.shade50.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon ?? Icons.event_available,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                title ?? "You're all caught up!",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                subtitle ?? "Tap + to start something.",
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
