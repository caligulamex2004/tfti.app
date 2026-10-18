import 'package:flutter/material.dart';

import '../shared/info_card.dart';
import 'details_bottom_sheets.dart';
import 'host_team_badge.dart';
import 'crew_attendees_rail.dart';

class EventCrewCard extends StatelessWidget {
  final bool inviteDocsEmpty;
  final Future<List<Map<String, dynamic>>>? cachedCrewFuture;
  final String currentUserId;
  final String hostId;
  final String? coHostId;
  final List<String> invitedCircles;
  final bool inviteAll;
  final List<String>? coHostInvitedCircles;
  final bool coHostInviteAll;
  final VoidCallback? onEditTeamsTap;
  final Function(String uid, String phone, String name) onAddFriend;
  final Function(String uid, String name) onReportUser;
  final String? eventId;

  const EventCrewCard({
    super.key,
    required this.inviteDocsEmpty,
    required this.cachedCrewFuture,
    required this.currentUserId,
    required this.hostId,
    required this.coHostId,
    this.invitedCircles = const [],
    this.inviteAll = true,
    this.coHostInvitedCircles,
    this.coHostInviteAll = false,
    this.onEditTeamsTap,
    required this.onAddFriend,
    required this.onReportUser,
    this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    if (inviteDocsEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text("No invitations found."),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: cachedCrewFuture,
      builder: (context, sortedSnap) {
        if (sortedSnap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                "Connection lost. Please reopen the event.",
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!sortedSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final guests = sortedSnap.data!;
        final seenGuests = guests.where((g) {
          return g['hasSeen'] == true && g['uid'] != currentUserId;
        }).toList();

        void openSeenBySheet() {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            builder: (ctx) => SeenBySheet(seenGuests: seenGuests),
          );
        }

        return InfoCard(
          title: "The Crew",
          icon: Icons.group,
          onIconTap: seenGuests.isNotEmpty ? openSeenBySheet : null,
          trailing: seenGuests.isNotEmpty
              ? InkWell(
                  onTap: openSeenBySheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 13,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Seen (${seenGuests.length})",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upfront Team Visibility for Host & Co-host
              HostTeamBadge(
                currentUserId: currentUserId,
                hostId: hostId,
                coHostId: coHostId,
                invitedCircles: invitedCircles,
                inviteAll: inviteAll,
                coHostInvitedCircles: coHostInvitedCircles,
                coHostInviteAll: coHostInviteAll,
                onEditTap: onEditTeamsTap,
                eventId: eventId,
              ),

              // Horizontal Attendees Rail with status filters and View All toggle
              CrewAttendeesRail(
                guests: guests,
                currentUserId: currentUserId,
                hostId: hostId,
                coHostId: coHostId,
                onAddFriend: onAddFriend,
                onReportUser: onReportUser,
              ),
            ],
          ),
        );
      },
    );
  }
}
