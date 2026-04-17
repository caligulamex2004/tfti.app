import 'package:flutter/material.dart';
import '../shared/info_card.dart';

class EventVitalsCard extends StatelessWidget {
  final DateTime eventTime;
  final int keepAliveDays;
  final String location;
  final bool isVibeCheck;
  final VoidCallback onCalendarTap;
  final VoidCallback onMapTap;

  const EventVitalsCard({
    super.key,
    required this.eventTime,
    required this.keepAliveDays,
    required this.location,
    required this.isVibeCheck,
    required this.onCalendarTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InfoCard(
      title: "The Vitals",
      icon: Icons.calendar_month,
      onIconTap: onCalendarTap,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 55,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        [
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
                        ][eventTime.month - 1],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        eventTime.day.toString(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          [
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                            'Sunday',
                          ][eventTime.weekday - 1],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (keepAliveDays > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              keepAliveDays == 1
                                  ? "1 Day"
                                  : (keepAliveDays == 7
                                        ? "1 Week"
                                        : "$keepAliveDays Days"),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${eventTime.hour > 12 ? eventTime.hour - 12 : (eventTime.hour == 0 ? 12 : eventTime.hour)}:${eventTime.minute.toString().padLeft(2, '0')} ${eventTime.hour >= 12 ? "PM" : "AM"}",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isVibeCheck) ...[
            const SizedBox(height: 24),
            InkWell(
              onTap: onMapTap,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: isDark
                          ? Colors.white
                          : Theme.of(context).colorScheme.tertiary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Tap for directions",
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
