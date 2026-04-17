import 'package:flutter/material.dart';

import '../shared/info_card.dart';
import 'critical_alert_banner.dart';
import 'details_bottom_sheets.dart';

class EventDetailsCard extends StatelessWidget {
  final String? details;
  final Map<String, dynamic>? latestCriticalChange;

  const EventDetailsCard({super.key, this.details, this.latestCriticalChange});

  @override
  Widget build(BuildContext context) {
    if ((details == null || details!.isEmpty) && latestCriticalChange == null) {
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
          if (latestCriticalChange != null) ...[
            CriticalAlertBanner(changeData: latestCriticalChange!),
            const SizedBox(height: 8),
          ],
          if (details != null && details!.isNotEmpty)
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
                  builder: (ctx) => FullDetailsSheet(details: details!),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details!,
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
                  if (details!.length > 150 || details!.contains('\n'))
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
