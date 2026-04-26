import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) =>
              SquadNeedsSheet(eventId: eventId, hostId: hostId, isPast: isPast),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor,
            width: 2, // Highlighted style for Squad Needs in edit mode
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_box_outlined, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Manage Needs",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
