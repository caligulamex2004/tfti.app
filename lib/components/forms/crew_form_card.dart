import 'package:flutter/material.dart';

import '../shared/rpg_glass_card.dart';
import 'team_selection_field.dart';
import 'co_captain_selector.dart';

class CrewFormCard extends StatelessWidget {
  final bool isPast;
  final bool inviteAll;
  final List<String> selectedCircleIds;
  final String? coHostId;
  final String? coHostName;
  final String? coHostUsername;
  final String? coHostAvatarUrl;
  final int? coHostAvatarColor;
  final Function(bool newInviteAll, List<String> newSelectedIds) onTeamChanged;
  final Function(
    String? id,
    String? name,
    String? username,
    String? avatarUrl,
    int? avatarColor,
  )
  onCoCaptainChanged;

  const CrewFormCard({
    super.key,
    required this.isPast,
    required this.inviteAll,
    required this.selectedCircleIds,
    required this.coHostId,
    required this.coHostName,
    required this.coHostUsername,
    required this.coHostAvatarUrl,
    required this.coHostAvatarColor,
    required this.onTeamChanged,
    required this.onCoCaptainChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RpgGlassCard(
      title: "The Crew",
      icon: Icons.group,
      child: Column(
        children: [
          TeamSelectionField(
            inviteAll: inviteAll,
            selectedCircleIds: selectedCircleIds,
            enabled: !isPast,
            onChanged: onTeamChanged,
          ),
          const SizedBox(height: 16),
          CoCaptainSelector(
            isPast: isPast,
            inviteAll: inviteAll,
            selectedCircleIds: selectedCircleIds,
            coHostId: coHostId,
            coHostName: coHostName,
            coHostUsername: coHostUsername,
            coHostAvatarUrl: coHostAvatarUrl,
            coHostAvatarColor: coHostAvatarColor,
            onChanged: onCoCaptainChanged,
          ),
        ],
      ),
    );
  }
}
