import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../shared/rpg_glass_card.dart';
import 'custom_input_field.dart';
import 'location_input_field.dart';
import 'date_time_row.dart';

class VitalsFormCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController? locController; // Nullable for Vibe Checks
  final bool isPast;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  // Customizable Text Strings
  final String cardTitle;
  final String titleLabel;
  final String titleHint;

  const VitalsFormCard({
    super.key,
    required this.titleController,
    this.locController,
    required this.isPast,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.cardTitle = "The Vitals",
    this.titleLabel = "Hangout Title",
    this.titleHint = "e.g. Bonfire & Chill",
  });

  @override
  Widget build(BuildContext context) {
    return RpgGlassCard(
      title: cardTitle,
      icon: Icons.push_pin,
      child: Column(
        children: [
          CustomInputField(
            controller: titleController,
            label: titleLabel,
            hint: titleHint,
            prefixIcon: Symbols.campaign,
            enabled: !isPast,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),

          // Only render location if a controller is passed!
          if (locController != null) ...[
            const SizedBox(height: 16),
            LocationInputField(controller: locController!, isPast: isPast),
          ],

          const SizedBox(height: 16),
          DateTimeRow(
            selectedDate: selectedDate,
            selectedTime: selectedTime,
            enabled: !isPast,
            onDateChanged: onDateChanged,
            onTimeChanged: onTimeChanged,
          ),
        ],
      ),
    );
  }
}
