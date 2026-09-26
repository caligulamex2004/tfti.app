import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/event_model.dart';
import '../../models/invitation_model.dart';
import '../feed/card_hero_banner.dart';
import '../feed/card_bottom_bar.dart';
import '../feed/card_landscape_tile.dart';

class EventSummaryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Event? event;
  final Invitation? invitation;
  final String myUid;
  final bool isLandscape;
  final bool isHorizontal;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(String hostId, Map<String, dynamic> hostData)? onHostTap;

  const EventSummaryCard({
    super.key,
    required this.item,
    required this.myUid,
    required this.isLandscape,
    this.isHorizontal = false,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.onHostTap,
    this.event,
    this.invitation,
  });

  const EventSummaryCard.fromModel({
    Key? key,
    required Event event,
    required Invitation invitation,
    required String myUid,
    required bool isLandscape,
    bool isHorizontal = false,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    Function(String hostId, Map<String, dynamic> hostData)? onHostTap,
  }) : this(
         key: key,
         item: const {},
         event: event,
         invitation: invitation,
         myUid: myUid,
         isLandscape: isLandscape,
         isHorizontal: isHorizontal,
         isSelected: isSelected,
         onTap: onTap,
         onLongPress: onLongPress,
         onHostTap: onHostTap,
       );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String eventId = event?.id ?? item['id'] ?? '';
    final Map<String, dynamic> data =
        event?.toMap() ?? (item['eventData'] as Map<String, dynamic>? ?? {});
    final Map<String, dynamic> inviteData =
        invitation?.toMap() ??
        (item['inviteData'] as Map<String, dynamic>? ?? {});

    final bool isPast = item.containsKey('isPast')
        ? item['isPast'] == true
        : (event?.isCurrentlyPast() ?? false);
    final bool isStartingSoon = item['isStartingSoon'] ?? false;
    final bool isHappeningNow = item['isHappeningNow'] ?? false;
    final String status = invitation?.status ?? item['status'] ?? 'pending';

    final bool isVibeCheck =
        event?.isVibeCheck ?? (data['type'] == 'vibe_check');
    final bool isPending = status == 'pending';
    final bool isImportantDetails =
        event?.isImportantDetails ?? (data['isImportantDetails'] == true);

    final String? bannerUrl = event?.bannerUrl ?? data['bannerUrl'];
    final String? lastMessageSnippet =
        event?.lastMessageSnippet ?? data['lastMessageSnippet'];

    final int keepAliveDays =
        event?.keepAliveDays ?? data['keepAliveDays'] ?? 0;

    final DateTime dt =
        event?.time ?? (item['time'] as DateTime? ?? DateTime.now());
    const List<String> shortMonths = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final String month = shortMonths[dt.month - 1];
    final String day = dt.day.toString();

    int hour = dt.hour;
    final String period = hour >= 12 ? "PM" : "AM";
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final String timeString =
        "$hour:${dt.minute.toString().padLeft(2, '0')} $period";

    final (IconData statusIcon, Color statusColor, String statusText) =
        switch ((
          isPast,
          status,
          isHappeningNow,
          isStartingSoon,
          isPending,
        )) {
          (true, _, _, _, _) => (Icons.history, Colors.grey.shade600, "Wrapped up"),
          (_, 'declined', _, _, _) => (Icons.cancel, Colors.redAccent, "Missing out"),
          (_, _, true, _, _) => (
            Icons.whatshot,
            Colors.orangeAccent,
            "Happening Now!",
          ),
          (_, _, _, true, _) => (
            Icons.directions_run,
            Colors.amberAccent,
            "Starting Soon",
          ),
          (_, _, _, _, true) => (
            isVibeCheck ? Icons.how_to_vote : Symbols.mail,
            Colors.orangeAccent,
            isVibeCheck ? "Vote Needed" : "Action Needed",
          ),
          _ => (Icons.check_circle, Colors.greenAccent, "You're going"),
        };

    final Timestamp? lastMsgTime = data['lastMessageAt'] as Timestamp?;
    final Timestamp? lastReadTime = inviteData['lastReadChat'] as Timestamp?;
    final bool hasUnreadChat =
        lastMsgTime != null &&
        (lastReadTime == null || lastMsgTime.seconds > lastReadTime.seconds);

    final double safeHorizontalWidth =
        (MediaQuery.of(context).size.width * 0.85).clamp(0.0, 340.0);

    // Landscape compact card
    if (isLandscape && !isHorizontal) {
      return CardLandscapeTile(
        isSelected: isSelected,
        onTap: onTap,
        onLongPress: onLongPress,
        bannerUrl: bannerUrl,
        statusIcon: statusIcon,
        statusColor: statusColor,
        statusText: statusText,
        isImportantDetails: isImportantDetails,
        hasUnreadChat: hasUnreadChat,
        title: data['title'] ?? "Untitled Event",
        month: month,
        day: day,
        timeString: timeString,
        isPending: isPending,
        isVibeCheck: isVibeCheck,
      );
    }

    // Default Hero Card (Portrait & Horizontal Carousel)
    return Container(
      width: isHorizontal ? safeHorizontalWidth : double.infinity,
      margin: EdgeInsets.only(
        bottom: isHorizontal ? 0 : 24,
        right: isHorizontal ? 8 : 0,
        left: isHorizontal ? 8 : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onLongPress: onLongPress,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CardHeroBanner(
                bannerUrl: bannerUrl,
                month: month,
                day: day,
                timeString: timeString,
                statusIcon: statusIcon,
                statusColor: statusColor,
                statusText: statusText,
                isPending: isPending,
                isImportantDetails: isImportantDetails,
                isVibeCheck: isVibeCheck,
                keepAliveDays: keepAliveDays,
                title: data['title'] ?? "Untitled Event",
                location: data['location'] ?? "TBD",
                hostId: data['hostId'],
                onHostTap: onHostTap,
              ),
              CardBottomBar(
                isPending: isPending,
                isVibeCheck: isVibeCheck,
                hasUnreadChat: hasUnreadChat,
                lastMessageSnippet: lastMessageSnippet,
                eventId: eventId,
                lastMessageAt: data['lastMessageAt'] as Timestamp?,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
