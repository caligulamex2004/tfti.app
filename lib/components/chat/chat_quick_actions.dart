import 'package:flutter/material.dart';
import '../../utils/theme_provider.dart';

class ChatQuickActions extends StatelessWidget {
  final VoidCallback onMention;
  final VoidCallback onWhisper;
  final VoidCallback onPhoto;
  final VoidCallback onOmw;
  final VoidCallback onDibs;
  final VoidCallback onBringItem;

  const ChatQuickActions({
    super.key,
    required this.onMention,
    required this.onWhisper,
    required this.onPhoto,
    required this.onOmw,
    required this.onDibs,
    required this.onBringItem,
  });

  @override
  Widget build(BuildContext context) {
    final pillBg = themeProvider.pillBackgroundColor;
    final pillFg = themeProvider.pillTextColor;
    final chipBg = themeProvider.chipUnselectedBackgroundColor;
    final chipFg = themeProvider.chipUnselectedTextColor;
    final chipBorder = themeProvider.chipBorderColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ActionChip(
            avatar: Icon(Icons.alternate_email, size: 16, color: pillFg),
            label: Text(
              "Mention",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: pillFg,
              ),
            ),
            backgroundColor: pillBg,
            side: BorderSide(color: pillBg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: onMention,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.hearing_outlined,
              size: 16,
              color: chipFg,
            ),
            label: Text(
              "Whisper",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: chipFg,
              ),
            ),
            backgroundColor: chipBg,
            side: BorderSide(color: chipBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: onWhisper,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.camera_alt,
              size: 16,
              color: chipFg,
            ),
            label: Text(
              "Photo",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: chipFg,
              ),
            ),
            backgroundColor: chipBg,
            side: BorderSide(color: chipBorder),
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
              color: chipFg,
            ),
            label: Text(
              "On my way",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: chipFg,
              ),
            ),
            backgroundColor: chipBg,
            side: BorderSide(color: chipBorder),
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
              color: chipFg,
            ),
            label: Text(
              "I call dibs on...",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: chipFg,
              ),
            ),
            backgroundColor: chipBg,
            side: BorderSide(color: chipBorder),
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
              color: pillFg,
            ),
            label: Text(
              "I'm bringing...",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: pillFg,
              ),
            ),
            backgroundColor: pillBg,
            side: BorderSide(color: pillBg),
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
