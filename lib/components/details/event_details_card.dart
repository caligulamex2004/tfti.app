import 'package:flutter/material.dart';

import '../shared/info_card.dart';
import 'critical_alert_banner.dart';
import 'details_bottom_sheets.dart';

class EventDetailsCard extends StatelessWidget {
  final Map<String, dynamic> eventData;

  const EventDetailsCard({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    // 1. Exact match to original event_details_page.dart logic
    final String? details = eventData['details'] ?? eventData['description'];
    final bool hasDetailsCondition = details != null && details.isNotEmpty;
    final bool hasCriticalChangeCondition = eventData.containsKey(
      'latestCriticalChange',
    );

    // 2. If neither exist, hide the card entirely
    if (!hasDetailsCondition && !hasCriticalChangeCondition) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InfoCard(
      title: "The Details",
      icon: Icons.notes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3. Render banner if the key exists (regardless of details text)
          if (hasCriticalChangeCondition) ...[
            CriticalAlertBanner(eventData: eventData),
            const SizedBox(height: 8),
          ],

          // 4. Render details text if it exists
          if (hasDetailsCondition)
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (ctx) => FullDetailsSheet(details: details),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade800,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (details.length > 150 || details.contains('\n'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Read more",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
}
