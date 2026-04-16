import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../shared/rpg_glass_card.dart';
import 'custom_input_field.dart';
import 'location_input_field.dart';
import 'date_time_row.dart';

class VitalsFormCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController locController;
  final bool isPast;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const VitalsFormCard({
    super.key,
    required this.titleController,
    required this.locController,
    required this.isPast,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RpgGlassCard(
      title: "The Vitals",
      icon: Icons.push_pin,
      child: Column(
        children: [
          CustomInputField(
            controller: titleController,
            label: "Hangout Title",
            hint: "e.g. Bonfire & Chill",
            prefixIcon: Symbols.campaign,
            enabled: !isPast,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          LocationInputField(controller: locController, isPast: isPast),
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
