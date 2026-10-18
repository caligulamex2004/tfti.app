import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/app_avatar.dart';
import '../shared/info_card.dart';
import '../../services/contact_resolver.dart';
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
  final EdgeInsetsGeometry? margin;

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
    this.margin,
  });

  DateTime? _getDeadlineTime() {
    final dynamic timeVal = eventData['time'];
    if (timeVal == null) return null;
    DateTime eventDt;
    if (timeVal is Timestamp) {
      eventDt = timeVal.toDate();
    } else if (timeVal is DateTime) {
      eventDt = timeVal;
    } else {
      return null;
    }
    final int offset = eventData['rsvpDeadline'] ?? 0;
    return eventDt.add(Duration(minutes: offset));
  }

  String _formatDeadline(DateTime deadline) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[deadline.weekday - 1];
    final int hour12 = deadline.hour > 12
        ? deadline.hour - 12
        : (deadline.hour == 0 ? 12 : deadline.hour);
    final String minuteStr = deadline.minute.toString().padLeft(2, '0');
    final String amPm = deadline.hour >= 12 ? 'PM' : 'AM';
    return "Let the crew know by $weekday @ $hour12:$minuteStr $amPm";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final DateTime? deadlineTime = _getDeadlineTime();
    final now = DateTime.now();
    final bool isPastDeadline =
        isPast || (deadlineTime != null && now.isAfter(deadlineTime));

    if (isVibeCheck) {
      return InfoCard(
        title: "Cast Your Vote",
        icon: Icons.how_to_vote_outlined,
        margin: margin,
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
        trailing: cachedCrewFuture != null
            ? InkWell(
                onTap: () async {
                  final guests = await cachedCrewFuture!;
                  if (context.mounted) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (ctx) => VoteTallySheet(
                        options: eventData['pollOptions'] ?? [],
                        guests: guests,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 13,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Tally",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
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
            // Deadline Row
            if (deadlineTime != null) ...[
              _buildDeadlineRow(deadlineTime, isPastDeadline, isDark),
              const SizedBox(height: 12),
            ],

            // Prompt banner for non-going guests
            if (myStatus != 'going' && !isMainHost)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.how_to_vote_outlined,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tap 'Count Me In' below to cast your vote!",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Poll UI
            VibeCheckPollUI(
              eventId: eventId,
              eventData: eventData,
              myInviteData: myInviteData,
              myUid: myUid,
              isHost: isMainHost,
              isLocked: isPastDeadline,
            ),
            const SizedBox(height: 16),

            // Action Row
            _buildActionControls(context, isDark, primaryColor, isPastDeadline),
          ],
        ),
      );
    }

    // Standard Hangout RSVP
    return InfoCard(
      title: "Can You Make It?",
      icon: Icons.check_circle_outline_rounded,
      margin: margin,
      trailing: cachedCrewFuture != null
          ? FutureBuilder<List<Map<String, dynamic>>>(
              future: cachedCrewFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                final goingCount =
                    snapshot.data!.where((g) => g['status'] == 'going').length;
                if (goingCount == 0) return const SizedBox.shrink();

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          Colors.green.withValues(alpha: isDark ? 0.4 : 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: isDark
                            ? Colors.greenAccent
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$goingCount In",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.greenAccent
                              : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deadline Row
          if (deadlineTime != null) ...[
            _buildDeadlineRow(deadlineTime, isPastDeadline, isDark),
            const SizedBox(height: 12),
          ],

          // Social proof avatar stack
          if (cachedCrewFuture != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: cachedCrewFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                final goingList = snapshot.data!
                    .where((g) => g['status'] == 'going')
                    .toList();
                if (goingList.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: _buildSocialProofRow(context, goingList, isDark),
                );
              },
            ),

          // Interactive action buttons
          _buildActionControls(context, isDark, primaryColor, isPastDeadline),
        ],
      ),
    );
  }

  Widget _buildDeadlineRow(
    DateTime deadlineTime,
    bool isPastDeadline,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(
          isPastDeadline
              ? Icons.lock_clock_outlined
              : Icons.schedule_rounded,
          size: 14,
          color: isPastDeadline
              ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade700)
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isPastDeadline
                ? "Responses closed"
                : _formatDeadline(deadlineTime),
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  isPastDeadline ? FontWeight.w600 : FontWeight.w500,
              color: isPastDeadline
                  ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade700)
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialProofRow(
    BuildContext context,
    List<Map<String, dynamic>> goingList,
    bool isDark,
  ) {
    final int count = goingList.length;
    final displayAvatars = goingList.take(3).toList();

    String resolveGuestName(Map<String, dynamic> guest) {
      final phone = (guest['phoneNumber'] ?? '').toString();
      final contactName = ContactResolver.instance.resolveName(phone);
      if (contactName != null && contactName.trim().isNotEmpty) {
        return contactName.trim();
      }
      final displayName = (guest['displayName'] ?? '').toString().trim();
      return displayName.isNotEmpty ? displayName : 'Someone';
    }

    String socialText;
    final name0 = resolveGuestName(goingList[0]);
    if (count == 1) {
      socialText = "$name0 is in";
    } else if (count == 2) {
      final name1 = resolveGuestName(goingList[1]);
      socialText = "$name0 and $name1 are in";
    } else {
      final others = count - 1;
      socialText =
          "$name0 and $others ${others == 1 ? 'other' : 'others'} are in";
    }

    final cardBg = isDark ? Colors.grey.shade900 : Colors.white;

    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 18.0 * (displayAvatars.length - 1) + 24,
          child: Stack(
            children: [
              for (int i = 0; i < displayAvatars.length; i++)
                Positioned(
                  left: i * 18.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBg, width: 2),
                    ),
                    child: AppAvatar.fromColorValue(
                      radius: 10,
                      avatarColor: displayAvatars[i]['avatarColor'],
                      avatarUrl: displayAvatars[i]['avatarUrl'],
                      displayName: resolveGuestName(displayAvatars[i]),
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            socialText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionControls(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    bool isPastDeadline,
  ) {
    // If deadline or event has passed
    if (isPastDeadline) {
      if (myStatus == 'going') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.green.withValues(alpha: isDark ? 0.4 : 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: isDark ? Colors.greenAccent : Colors.green.shade700,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're on the list ✓",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark
                            ? Colors.greenAccent
                            : Colors.green.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Responses closed • See you there",
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ],
          ),
        );
      }

      // Past deadline & not going
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Responses closed",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "The crew list has been finalized.",
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Active status: Going
    if (myStatus == 'going') {
      return LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 260;

          final Widget goingInfo = Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: isDark ? Colors.greenAccent : Colors.green.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "You're on the list ✓",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color:
                            isDark ? Colors.greenAccent : Colors.green.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Ready for the hangout",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final Widget changeButton = InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onRsvp('pending');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              alignment: isNarrow ? Alignment.center : null,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                "Change",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withValues(alpha: isDark ? 0.4 : 0.3),
                width: 1.5,
              ),
            ),
            child: isNarrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      goingInfo,
                      const SizedBox(height: 10),
                      changeButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: goingInfo),
                      const SizedBox(width: 8),
                      changeButton,
                    ],
                  ),
          );
        },
      );
    }

    // Active status: Declined
    if (myStatus == 'declined') {
      return LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 260;

          final Widget statusInfo = Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Can't make it this time",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

          final Widget countMeInButton = ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onRsvp('going');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Count Me In ✓",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: isNarrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      statusInfo,
                      const SizedBox(height: 8),
                      countMeInButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: statusInfo),
                      const SizedBox(width: 8),
                      countMeInButton,
                    ],
                  ),
          );
        },
      );
    }

    // Active status: Pending (default)
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isStacked = constraints.maxWidth < 280;

        final Widget countMeInButton = ElevatedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onRsvp('going');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 2,
            shadowColor: primaryColor.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 18),
                SizedBox(width: 6),
                Text(
                  "Count Me In ✓",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );

        final Widget cantMakeItButton = OutlinedButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onRsvp('declined');
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            side: BorderSide(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            foregroundColor:
                isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "Can't Make It",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        );

        if (isStacked) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: countMeInButton,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: cantMakeItButton,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 3,
              child: countMeInButton,
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: cantMakeItButton,
            ),
          ],
        );
      },
    );
  }
}
