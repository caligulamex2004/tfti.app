import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/team_model.dart';
import '../../models/user_profile.dart';
import '../../pages/team_members_page.dart';
import '../../services/contact_resolver.dart';
import '../../services/team_service.dart';
import '../../services/user_cache_repository.dart';
import '../../utils/event_service.dart';
import '../forms/last_minute_invite_field.dart';
import '../forms/last_minute_invite_sheet.dart';

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
  final List<String> lastMinuteInvites;
  final List<String>? coHostInvitedCircles;
  final bool coHostInviteAll;
  final List<String>? coHostLastMinuteInvites;
  final bool isPast;
  final VoidCallback? onEditTap;
  final String? eventId;

  const HostTeamBadge({
    super.key,
    required this.currentUserId,
    required this.hostId,
    required this.coHostId,
    required this.invitedCircles,
    required this.inviteAll,
    this.lastMinuteInvites = const [],
    required this.coHostInvitedCircles,
    required this.coHostInviteAll,
    this.coHostLastMinuteInvites,
    this.isPast = false,
    this.onEditTap,
    this.eventId,
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
    final List<String> myLastMinuteIds = isMainHost
        ? lastMinuteInvites
        : (coHostLastMinuteInvites ?? const []);
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

          // Quick-access Last Minute Invite row for Host & Co-Captain
          if (eventId != null) ...[
            const SizedBox(height: 10),
            _buildLastMinuteInviteRow(
              context: context,
              isMainHost: isMainHost,
              isAll: isAll,
              circleIds: circleIds,
              myLastMinuteIds: myLastMinuteIds,
              primaryColor: primaryColor,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Future<String> _resolveLastMinuteNames(List<String> uids) async {
    if (uids.isEmpty) return "Last Minute Invite";
    try {
      final userMap = await UserCacheRepository.instance.getUsers(uids);
      final List<String> names = [];
      for (final uid in uids) {
        final UserProfile? profile = userMap[uid];
        if (profile != null) {
          final resolved =
              ContactResolver.instance.resolveMiniProfileName(
                profile.phoneNumber,
                fallbackName: profile.displayName,
              ) ??
              ContactResolver.instance.formatMiniProfileFallback(
                profile.displayName,
              );
          names.add(resolved);
        }
      }
      if (names.isEmpty) return "Last Minute Invite (${uids.length})";
      return "Last Minute Invite: ${names.join(', ')}";
    } catch (_) {
      return "Last Minute Invite (${uids.length})";
    }
  }

  Widget _buildLastMinuteInviteRow({
    required BuildContext context,
    required bool isMainHost,
    required bool isAll,
    required List<String> circleIds,
    required List<String> myLastMinuteIds,
    required Color primaryColor,
    required bool isDark,
  }) {
    final bool canSelect = !isPast && !isAll && circleIds.isNotEmpty;
    final String fallbackLabel = myLastMinuteIds.isEmpty
        ? "Last Minute Invite"
        : "Last Minute Invite (${myLastMinuteIds.length})";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Opacity(
            opacity: canSelect ? 1.0 : 0.5,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isPast
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      if (isAll) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Entire Squad is selected — everyone is already invited!",
                              ),
                            ),
                          );
                        return;
                      }
                      if (circleIds.isEmpty) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text("Please select a Team first."),
                            ),
                          );
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      LastMinuteInviteSheet.show(
                        context,
                        userUid: currentUserId,
                        selectedCircleIds: circleIds,
                        initialSelectedIds: myLastMinuteIds,
                        excludeUids: isMainHost ? const {} : {hostId},
                        onSaved: (updatedIds) async {
                          await EventService.updateLastMinuteInvites(
                            eventId: eventId!,
                            lastMinuteInviteIds: updatedIds,
                            isMainHost: isMainHost,
                          );
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  updatedIds.isEmpty
                                      ? "Last minute invites cleared."
                                      : "Last minute invites updated (${updatedIds.length})!",
                                ),
                              ),
                            );
                        },
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
                    color: myLastMinuteIds.isNotEmpty && canSelect
                        ? primaryColor.withValues(alpha: 0.6)
                        : (isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300),
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
                      Icons.person_add_alt_1_outlined,
                      size: 15,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: (canSelect && myLastMinuteIds.isNotEmpty)
                          ? FutureBuilder<String>(
                              future: _resolveLastMinuteNames(myLastMinuteIds),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? fallbackLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            )
                          : Text(
                              fallbackLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: "Select one or more to join the Crew on this one.",
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => LastMinuteInviteField.showInfoMessage(context),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ],
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
              onTap: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamMembersPage(
                      circleId: team.id,
                      circleName: team.name,
                      eventId: eventId,
                    ),
                  ),
                );
                if (eventId != null) {
                  await EventService.syncEventInvitesWithTeams(eventId!);
                }
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
