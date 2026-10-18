import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/team_model.dart';
import '../../pages/team_members_page.dart';
import '../../services/team_service.dart';

/// Shows the host or co-host their personal selected team(s) upfront.
/// Strictly scoped:
/// - Host only sees teams they selected (or "Entire Squad").
/// - Co-host only sees teams they selected (or "Entire Squad").
/// - Regular attendees/guests see nothing.
class HostTeamBadge extends StatelessWidget {
  final String currentUserId;
  final String hostId;
  final String? coHostId;
  final List<String> invitedCircles;
  final bool inviteAll;
  final List<String>? coHostInvitedCircles;
  final bool coHostInviteAll;
  final VoidCallback? onEditTap;

  const HostTeamBadge({
    super.key,
    required this.currentUserId,
    required this.hostId,
    required this.coHostId,
    required this.invitedCircles,
    required this.inviteAll,
    required this.coHostInvitedCircles,
    required this.coHostInviteAll,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMainHost = currentUserId == hostId;
    final bool isCoHost = coHostId != null && currentUserId == coHostId;

    // Strict privacy scoping: only host and co-host can see their scope
    if (!isMainHost && !isCoHost) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final bool isAll = isMainHost ? inviteAll : coHostInviteAll;
    final List<String> circleIds = isMainHost
        ? invitedCircles
        : (coHostInvitedCircles ?? const []);
    final String roleLabel = isMainHost ? "Host" : "Co-Captain";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.6)
            : primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Role privacy pill & Edit button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 11,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "VISIBLE ONLY TO YOU AS ${roleLabel.toUpperCase()}",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (onEditTap != null)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onEditTap!();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        "Edit",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Content: Entire Squad vs. Specific Selected Teams
          if (isAll)
            _buildEntireSquadTile(context, primaryColor, isDark)
          else if (circleIds.isEmpty)
            _buildEmptySelectionTile(context, isDark, primaryColor)
          else
            _buildTeamsStream(context, circleIds, primaryColor, isDark),
        ],
      ),
    );
  }

  Widget _buildEntireSquadTile(
    BuildContext context,
    Color primaryColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.groups_rounded, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Entire Squad",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "All friends in your squad are invited to this hangout.",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySelectionTile(
    BuildContext context,
    bool isDark,
    Color primaryColor,
  ) {
    return Row(
      children: [
        Icon(
          Icons.info_outline,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "No specific teams selected.",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamsStream(
    BuildContext context,
    List<String> circleIds,
    Color primaryColor,
    bool isDark,
  ) {
    return StreamBuilder<List<TeamCircle>>(
      stream: TeamService.teamsStream(currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final allUserTeams = snapshot.data!;
        final selectedTeams = allUserTeams
            .where((team) => circleIds.contains(team.id))
            .toList();

        if (selectedTeams.isEmpty) {
          return Text(
            "${circleIds.length} Team(s) Selected",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectedTeams.map((team) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamMembersPage(
                      circleId: team.id,
                      circleName: team.name,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.04,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      team.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
