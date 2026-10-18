import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/info_card.dart';

class EventVitalsCard extends StatelessWidget {
  final DateTime eventTime;
  final int keepAliveDays;
  final String location;
  final bool isVibeCheck;
  final VoidCallback onCalendarTap;
  final VoidCallback onMapTap;
  final EdgeInsetsGeometry? margin;

  const EventVitalsCard({
    super.key,
    required this.eventTime,
    required this.keepAliveDays,
    required this.location,
    required this.isVibeCheck,
    required this.onCalendarTap,
    required this.onMapTap,
    this.margin,
  });

  String _formatCountdown(DateTime target) {
    final now = DateTime.now();
    final diff = target.difference(now);

    if (diff.isNegative) {
      if (diff.inHours.abs() < 6) {
        return "Happening Now! 🔥";
      }
      return "Past Hangout";
    }

    if (target.year == now.year &&
        target.month == now.month &&
        target.day == now.day) {
      return "Today";
    }

    final tomorrow = now.add(const Duration(days: 1));
    if (target.year == tomorrow.year &&
        target.month == tomorrow.month &&
        target.day == tomorrow.day) {
      return "Tomorrow";
    }

    final days = diff.inDays;
    if (days < 7) {
      return "In $days ${days == 1 ? 'day' : 'days'}";
    }

    final weeks = (days / 7).floor();
    return "In $weeks ${weeks == 1 ? 'week' : 'weeks'}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    const months = [
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
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final monthStr = months[eventTime.month - 1];
    final weekdayStr = weekdays[eventTime.weekday - 1];
    final int hour12 = eventTime.hour > 12
        ? eventTime.hour - 12
        : (eventTime.hour == 0 ? 12 : eventTime.hour);
    final String minuteStr = eventTime.minute.toString().padLeft(2, '0');
    final String amPm = eventTime.hour >= 12 ? "PM" : "AM";
    final String timeStr = "$hour12:$minuteStr $amPm";
    final String countdownStr = _formatCountdown(eventTime);

    return InfoCard(
      title: "The Vitals",
      icon: Icons.calendar_month_outlined,
      margin: margin,
      trailing: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onCalendarTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                "+ Calendar",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Time Row
          Row(
            children: [
              // Modern Date Tile
              Container(
                width: 58,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade900
                      : primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(
                        alpha: isDark ? 0.2 : 0.06,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      monthStr,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      eventTime.day.toString(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Date details & chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$weekdayStr, $monthStr ${eventTime.day}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Countdown Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: countdownStr.contains("Happening") ||
                                    countdownStr.contains("Today")
                                ? Colors.orange.withValues(alpha: 0.15)
                                : primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            countdownStr,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: countdownStr.contains("Happening") ||
                                      countdownStr.contains("Today")
                                  ? Colors.orange
                                  : primaryColor,
                            ),
                          ),
                        ),

                        // Keep Alive / Duration Chip
                        if (keepAliveDays > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              keepAliveDays == 1
                                  ? "⏱️ 1 Day"
                                  : (keepAliveDays == 7
                                      ? "⏱️ 1 Week"
                                      : "⏱️ $keepAliveDays Days"),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Location / Venue Card
          if (!isVibeCheck)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onMapTap();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade900.withValues(alpha: 0.6)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final String trimmedLoc = location.trim();
                    String? line1;
                    String? line2;

                    if (trimmedLoc.isNotEmpty) {
                      int splitIdx = trimmedLoc.indexOf('\n');
                      if (splitIdx != -1) {
                        line1 = trimmedLoc.substring(0, splitIdx).trim();
                        line2 = trimmedLoc.substring(splitIdx + 1).trim();
                      } else {
                        splitIdx = trimmedLoc.indexOf(',');
                        if (splitIdx != -1) {
                          line1 = trimmedLoc.substring(0, splitIdx + 1).trim();
                          line2 = trimmedLoc.substring(splitIdx + 1).trim();
                        } else if (trimmedLoc.length > 30) {
                          final spaceIdx = trimmedLoc.lastIndexOf(' ', 30);
                          if (spaceIdx > 10) {
                            line1 = trimmedLoc.substring(0, spaceIdx).trim();
                            line2 = trimmedLoc.substring(spaceIdx + 1).trim();
                          } else {
                            line1 = trimmedLoc;
                          }
                        } else {
                          line1 = trimmedLoc;
                        }
                      }
                    }

                    final bool hasTwoLines = line2 != null && line2.isNotEmpty;

                    return Row(
                      crossAxisAlignment: hasTwoLines
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiary
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: Theme.of(context).colorScheme.tertiary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: hasTwoLines
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line1!,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            line2,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildGoButton(
                                          context,
                                          primaryColor,
                                          isDark,
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        trimmedLoc.isEmpty
                                            ? "Location TBD"
                                            : trimmedLoc,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          height: 1.25,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (trimmedLoc.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      _buildGoButton(
                                        context,
                                        primaryColor,
                                        isDark,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Time & location decided by crew vote below!",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoButton(
    BuildContext context,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: primaryColor.withValues(
          alpha: isDark ? 0.2 : 0.1,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: primaryColor.withValues(
            alpha: isDark ? 0.35 : 0.2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Go",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.open_in_new,
            size: 11,
            color: primaryColor,
          ),
        ],
      ),
    );
  }
}
