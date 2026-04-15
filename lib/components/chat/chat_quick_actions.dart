import 'package:flutter/material.dart';

class ChatQuickActions extends StatelessWidget {
  final VoidCallback onMention;
  final VoidCallback onPhoto;
  final VoidCallback onOmw;
  final VoidCallback onDibs;
  final VoidCallback onBringItem;

  const ChatQuickActions({
    super.key,
    required this.onMention,
    required this.onPhoto,
    required this.onOmw,
    required this.onDibs,
    required this.onBringItem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ActionChip(
            avatar: Icon(Icons.alternate_email, size: 16, color: primaryColor),
            label: Text(
              "Mention",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: onMention,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.camera_alt,
              size: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            label: Text(
              "Photo",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: onPhoto,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.directions_car,
              size: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            label: Text(
              "On my way",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: onOmw,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.pan_tool,
              size: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            label: Text(
              "I call dibs on...",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: onDibs,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.volunteer_activism,
              size: 16,
              color: primaryColor,
            ),
            label: Text(
              "I'm bringing...",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: onBringItem,
          ),
        ],
      ),
    );
  }
}
