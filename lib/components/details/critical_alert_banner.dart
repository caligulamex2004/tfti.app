import 'package:flutter/material.dart';

class CriticalAlertBanner extends StatelessWidget {
  final Map<String, dynamic> eventData;

  const CriticalAlertBanner({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    // 1. Exact match to original logic
    final change = eventData['latestCriticalChange'] as Map<String, dynamic>?;

    if (change == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  "HEADS UP: ${change['field'] ?? 'Details'} Changed!",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Was: ${change['original'] ?? ''}\nNow: ${change['new'] ?? ''}",
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
