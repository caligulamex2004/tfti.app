import 'package:flutter/material.dart';

import '../shared/rpg_glass_card.dart';
import 'custom_input_field.dart';
import 'tactile_chip_row.dart';

class ExtrasFormCard extends StatelessWidget {
  final TextEditingController detailsController;
  final bool isPast;
  final int rsvpDeadlineOffset;
  final ValueChanged<int> onRsvpChanged;

  // Nullable Hangout-Specific Fields
  final int? keepAliveDays;
  final ValueChanged<int>? onKeepAliveChanged;
  final Widget? togglesRow;

  // Customizable Strings & Flags
  final String cardTitle;
  final String detailsLabel;
  final String detailsHint;
  final String rsvpLabel;
  final bool show48HourOption;

  const ExtrasFormCard({
    super.key,
    required this.detailsController,
    required this.isPast,
    required this.rsvpDeadlineOffset,
    required this.onRsvpChanged,
    this.keepAliveDays,
    this.onKeepAliveChanged,
    this.togglesRow,
    this.cardTitle = "The Extras",
    this.detailsLabel = "Details / Description",
    this.detailsHint = "e.g. Dog friendly, BYOB...",
    this.rsvpLabel = "RSVP Deadline",
    this.show48HourOption = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RpgGlassCard(
      title: cardTitle,
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show if keepAlive logic is requested
          if (keepAliveDays != null && onKeepAliveChanged != null) ...[
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
              selectedValue: keepAliveDays!,
              onSelected: isPast ? (v) {} : onKeepAliveChanged!,
            ),
            const SizedBox(height: 24),
          ],

          TactileChipRow<int>(
            label: rsvpLabel,
            icon: Icons.timer_off_outlined,
            options: [
              {'label': 'On time', 'value': 0},
              {'label': '30 mins before', 'value': -30},
              {'label': '1 hr before', 'value': -60},
              {'label': '2 hrs before', 'value': -120},
              {'label': '4 hrs before', 'value': -240},
              {'label': '24 hrs before', 'value': -1440},
              if (show48HourOption) {'label': '48 hrs before', 'value': -2880},
            ],
            selectedValue: rsvpDeadlineOffset,
            onSelected: isPast ? (v) {} : onRsvpChanged,
          ),
          const SizedBox(height: 24),

          CustomInputField(
            controller: detailsController,
            label: detailsLabel,
            hint: detailsHint,
            prefixIcon: Icons.notes,
            prefixIconColor: isDark ? Colors.grey.shade400 : Colors.grey,
            maxLines: 3,
            enabled: !isPast,
          ),

          // Render togglesRow if provided
          if (togglesRow != null) ...[
            const SizedBox(height: 16),
            togglesRow!,
          ],
        ],
      ),
    );
  }
}
