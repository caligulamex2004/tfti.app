import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/rpg_glass_card.dart';
import 'squad_needs_sheet.dart';

/// A form card for the HangoutEditorPage that lets the host manage Squad Needs
/// (roles/items) while editing an existing event.
class SquadNeedsFormCard extends StatelessWidget {
  final String eventId;
  final String hostId;
  final bool isPast;

  const SquadNeedsFormCard({
    super.key,
    required this.eventId,
    required this.hostId,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return RpgGlassCard(
      title: "Squad Needs",
      icon: Icons.check_box_outlined,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) => SquadNeedsSheet(
              eventId: eventId,
              hostId: hostId,
              isPast: isPast,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.pan_tool, color: primaryColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isPast
                      ? "View items you needed help with"
                      : "Manage items you need help with",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
