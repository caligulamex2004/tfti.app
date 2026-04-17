import 'package:flutter/material.dart';

import '../shared/info_card.dart';
import 'swipe_rsvp_widget.dart';
import 'vibe_check_poll_ui.dart';
import 'vote_tally_sheet.dart';

class EventRsvpCard extends StatelessWidget {
  final bool isVibeCheck;
  final String eventId;
  final Map<String, dynamic> eventData;
  final Map<String, dynamic> myInviteData;
  final String myStatus;
  final String myUid;
  final bool isMainHost;
  final bool isPast;
  final Future<List<Map<String, dynamic>>>? cachedCrewFuture;
  final Function(String) onRsvp;

  const EventRsvpCard({
    super.key,
    required this.isVibeCheck,
    required this.eventId,
    required this.eventData,
    required this.myInviteData,
    required this.myStatus,
    required this.myUid,
    required this.isMainHost,
    required this.isPast,
    required this.cachedCrewFuture,
    required this.onRsvp,
  });

  @override
  Widget build(BuildContext context) {
    if (isVibeCheck) {
      return InfoCard(
        title: "Cast Your Vote",
        icon: Icons.how_to_vote,
        onIconTap: () async {
          if (cachedCrewFuture != null) {
            final guests = await cachedCrewFuture!;
            if (context.mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (ctx) => VoteTallySheet(
                  options: eventData['pollOptions'] ?? [],
                  guests: guests,
                ),
              );
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (myStatus != 'going' && !isMainHost)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Swipe 'LET'S GO' below to cast your vote!",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            VibeCheckPollUI(
              eventId: eventId,
              eventData: eventData,
              myInviteData: myInviteData,
              myUid: myUid,
              isHost: isMainHost,
              isLocked: isPast,
            ),
            const SizedBox(height: 24),
            SwipeRsvpWidget(
              key: ValueKey(myStatus),
              currentStatus: myStatus,
              isLocked: isPast,
              onRsvp: onRsvp,
            ),
          ],
        ),
      );
    }

    // Standard Hangout RSVP
    return InfoCard(
      title: "In or Out?",
      icon: Icons.thumbs_up_down,
      child: SwipeRsvpWidget(
        key: ValueKey(myStatus),
        currentStatus: myStatus,
        isLocked: isPast,
        onRsvp: onRsvp,
      ),
    );
  }
}
