import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VibeCheckPollUI extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;
  final Map<String, dynamic> myInviteData;
  final String myUid;
  final bool isHost;
  final bool isLocked;

  const VibeCheckPollUI({
    super.key,
    required this.eventId,
    required this.eventData,
    required this.myInviteData,
    required this.myUid,
    required this.isHost,
    this.isLocked = false,
  });

  Future<void> _castVote(String optionId) async {
    if (isLocked) return;

    final status = myInviteData['status'] ?? 'pending';
    if (status != 'going' && !isHost) return;

    List<String> currentVotes = List<String>.from(myInviteData['votes'] ?? []);
    if (currentVotes.contains(optionId)) {
      currentVotes.remove(optionId);
    } else {
      currentVotes.add(optionId);
    }

    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);
    final inviteRef = eventRef.collection('invitations').doc(myUid);
    final batch = FirebaseFirestore.instance.batch();

    batch.set(inviteRef, {
      'uid': myUid,
      'votes': currentVotes,
    }, SetOptions(merge: true));

    final evSnap = await eventRef.get();
    if (evSnap.exists) {
      final evData = evSnap.data() as Map<String, dynamic>;
      if (evData['type'] == 'vibe_check' &&
          evData['isTieBreakerNeeded'] == true) {
        batch.update(eventRef, {'isTieBreakerNeeded': false});
      }
    }

    await batch.commit();
  }

  Future<void> _lockInTieBreaker(Map<String, dynamic> option) async {
    if (isLocked) return;

    final batch = FirebaseFirestore.instance.batch();
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);

    batch.update(eventRef, {
      'type': 'event',
      'lockedOptionId': option['id'],
      'title': option['title'],
      'location': option['location'],
      'isTieBreakerNeeded': false,
    });

    final invitesSnap = await eventRef.collection('invitations').get();
    for (var doc in invitesSnap.docs) {
      final data = doc.data();
      if (data['status'] == 'declined') continue;

      final votes = List<String>.from(data['votes'] ?? []);
      String newStatus = votes.contains(option['id']) ? 'going' : 'pending';
      if (data['role'] == 'host' || data['role'] == 'co-host') {
        newStatus = 'going';
      }

      batch.update(doc.reference, {'status': newStatus});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final options = List<dynamic>.from(eventData['pollOptions'] ?? []);

    final now = DateTime.now();
    final Timestamp? ts = eventData['time'];
    final DateTime eventTime = ts?.toDate() ?? now;
    final int deadlineOffset = eventData['rsvpDeadline'] ?? 0;
    final DateTime deadlineTime = eventTime.add(
      Duration(minutes: deadlineOffset),
    );
    final bool isPastDeadline = now.isAfter(deadlineTime);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('invitations')
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, int> voteCounts = {};
        int totalEligibleVoters = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            if (d['status'] == 'declined') continue;

            totalEligibleVoters++;
            final vList = List<String>.from(d['votes'] ?? []);
            for (var v in vList) {
              voteCounts[v] = (voteCounts[v] ?? 0) + 1;
            }
          }
        }

        bool dynamicIsTie = false;
        int maxV = -1;

        if (options.isNotEmpty) {
          int tieCount = 0;
          for (var opt in options) {
            int c = voteCounts[opt['id']] ?? 0;
            if (c > maxV) {
              maxV = c;
              tieCount = 1;
            } else if (c == maxV) {
              tieCount++;
            }
          }
          dynamicIsTie = (tieCount > 1);
        }

        final showTieBreaker = isHost && dynamicIsTie && isPastDeadline;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTieBreaker)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "It's a tie! Lock in your choice below to finalize the event.",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            ...options.map((opt) {
              final optId = opt['id'];
              final count = voteCounts[optId] ?? 0;
              final double percentage = totalEligibleVoters == 0
                  ? 0
                  : (count / totalEligibleVoters);
              final myVotes = List<String>.from(myInviteData['votes'] ?? []);
              final bool iVoted = myVotes.contains(optId);
              final bool isThisOptionTied = showTieBreaker && (count == maxV);

              return GestureDetector(
                onTap: () => _castVote(optId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: iVoted ? primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: percentage > 0 ? percentage : 0.01,
                            heightFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(
                                  alpha: isDark ? 0.3 : 0.15,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              iVoted
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 22,
                              color: iVoted
                                  ? primaryColor
                                  : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['title'],
                                    style: TextStyle(
                                      fontWeight: iVoted
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (opt['location'] != null &&
                                      opt['location'].toString().isNotEmpty &&
                                      opt['location'] != 'TBD')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2.0,
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: isDark
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              opt['location'],
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isThisOptionTied)
                              InkWell(
                                onTap: () => _lockInTieBreaker(opt),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "LOCK IN",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                "$count",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
