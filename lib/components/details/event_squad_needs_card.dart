import 'package:flutter/material.dart';

import '../shared/info_card.dart';
import '../forms/squad_needs_sheet.dart';

class EventSquadNeedsCard extends StatelessWidget {
  final bool hasRoles;
  final bool canEdit;
  final String eventId;
  final String hostId;
  final bool isPast;

  const EventSquadNeedsCard({
    super.key,
    required this.hasRoles,
    required this.canEdit,
    required this.eventId,
    required this.hostId,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasRoles) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InfoCard(
      title: "Squad Needs",
      icon: Icons.check_box_outlined,
      child: InkWell(
        onTap: () {
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
                  canEdit
                      ? "Manage items you need help with"
                      : "See what the captain needs!",
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
