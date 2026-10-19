import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      padding: const EdgeInsets.only(top: 8.0),
      child: RpgGlassCard(
        title: "Host Actions",
        icon: Icons.admin_panel_settings_outlined,
        iconColor: Colors.amber,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onConvert();
                },
                icon: const Icon(Icons.workspace_premium, size: 20),
                label: const Text(
                  "Lock In Winner & Convert",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.green.shade800
                      : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onDelete();
                },
                icon: Icon(
                  Icons.delete_outline,
                  color: isDark ? Colors.redAccent : Colors.red,
                  size: 20,
                ),
                label: Text(
                  "Delete Vibe Check",
                  style: TextStyle(
                    color: isDark ? Colors.redAccent : Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: (isDark ? Colors.redAccent : Colors.red)
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
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
