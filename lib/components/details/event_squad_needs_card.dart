import 'package:flutter/material.dart';

import 'squad_needs_rail.dart';

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
    // If there are no roles and the user cannot edit, hide completely
    if (!hasRoles && !canEdit) {
      return const SizedBox.shrink();
    }

    return SquadNeedsRail(
      eventId: eventId,
      hostId: hostId,
      canEdit: canEdit,
      isPast: isPast,
    );
  }
}
