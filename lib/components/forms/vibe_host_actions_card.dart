import 'package:flutter/material.dart';
import '../shared/rpg_glass_card.dart';

class VibeHostActionsCard extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onConvert;
  final VoidCallback onDelete;

  const VibeHostActionsCard({
    super.key,
    required this.isEditing,
    required this.onConvert,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: RpgGlassCard(
        title: "Host Actions",
        icon: Icons.admin_panel_settings,
        iconColor: Colors.amber,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: onConvert,
                icon: Icon(
                  Icons.done_all,
                  color: isDark ? Colors.greenAccent : Colors.green,
                ),
                label: Text(
                  "Lock In Winner & Convert",
                  style: TextStyle(
                    color: isDark ? Colors.greenAccent : Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark
                        ? Colors.greenAccent.withValues(alpha: 0.5)
                        : Colors.green.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete,
                  color: isDark ? Colors.redAccent : Colors.red,
                ),
                label: Text(
                  "Delete Vibe Check",
                  style: TextStyle(
                    color: isDark ? Colors.redAccent : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
