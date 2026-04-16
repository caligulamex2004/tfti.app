import 'package:flutter/material.dart';

import '../shared/rpg_glass_card.dart';
import 'custom_input_field.dart';
import 'important_details_toggle.dart';
import 'tactile_chip_row.dart';

class ExtrasFormCard extends StatelessWidget {
  final TextEditingController detailsController;
  final bool isPast;
  final bool isImportantDetails;
  final int rsvpDeadlineOffset;
  final int keepAliveDays;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<int> onRsvpChanged;
  final ValueChanged<int> onKeepAliveChanged;

  const ExtrasFormCard({
    super.key,
    required this.detailsController,
    required this.isPast,
    required this.isImportantDetails,
    required this.rsvpDeadlineOffset,
    required this.keepAliveDays,
    required this.onImportantChanged,
    required this.onRsvpChanged,
    required this.onKeepAliveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RpgGlassCard(
      title: "The Extras",
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomInputField(
            controller: detailsController,
            label: "Details / Description",
            prefixIcon: Icons.notes,
            prefixIconColor: isDark ? Colors.grey.shade400 : Colors.grey,
            maxLines: 3,
            enabled: !isPast,
          ),
          const SizedBox(height: 16),
          ImportantDetailsToggle(
            isImportant: isImportantDetails,
            isPast: isPast,
            onChanged: onImportantChanged,
          ),
          const SizedBox(height: 24),
          TactileChipRow<int>(
            label: "RSVP Deadline",
            icon: Icons.timer_off_outlined,
            options: const [
              {'label': 'On time', 'value': 0},
              {'label': '30 mins before', 'value': -30},
              {'label': '1 hr before', 'value': -60},
              {'label': '2 hrs before', 'value': -120},
              {'label': '4 hrs before', 'value': -240},
              {'label': '24 hrs before', 'value': -1440},
            ],
            selectedValue: rsvpDeadlineOffset,
            onSelected: isPast ? (v) {} : onRsvpChanged,
          ),
          const SizedBox(height: 24),
          TactileChipRow<int>(
            label: "Active for...",
            icon: Icons.timelapse,
            options: const [
              {'label': 'A few hours', 'value': 0},
              {'label': '1 Day', 'value': 1},
              {'label': '2 Days', 'value': 2},
              {'label': '3 Days', 'value': 3},
              {'label': '4 Days', 'value': 4},
              {'label': '5 Days', 'value': 5},
              {'label': '1 Week', 'value': 7},
              {'label': '10 Days', 'value': 10},
              {'label': '2 Weeks', 'value': 14},
            ],
            selectedValue: keepAliveDays,
            onSelected: isPast ? (v) {} : onKeepAliveChanged,
          ),
        ],
      ),
    );
  }
}
