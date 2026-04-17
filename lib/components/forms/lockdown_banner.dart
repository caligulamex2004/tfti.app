import 'package:flutter/material.dart';

class LockdownBanner extends StatelessWidget {
  final bool isPast;

  const LockdownBanner({super.key, required this.isPast});

  @override
  Widget build(BuildContext context) {
    if (!isPast) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "This hangout has already passed. It can no longer be edited.",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
