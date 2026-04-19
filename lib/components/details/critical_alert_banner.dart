import 'package:flutter/material.dart';

class CriticalAlertBanner extends StatelessWidget {
  final Map<String, dynamic> eventData;

  const CriticalAlertBanner({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Exact match from the working event_details_page.dart
    final change = eventData['latestCriticalChange'];
    if (change == null) return const SizedBox.shrink();

    // 2. Safe cast to prevent dynamic Map crashes
    final Map<String, dynamic> safeChange = Map<String, dynamic>.from(
      change as Map,
    );

    final field = safeChange['field'] ?? 'Details';
    final original = safeChange['original'] ?? '';
    final newValue = safeChange['new'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "HEADS UP: $field Changed!",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Was: $original\nNow: $newValue",
                  style: TextStyle(
                    color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
