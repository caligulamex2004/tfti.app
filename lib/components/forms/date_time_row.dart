import 'package:flutter/material.dart';

// This cleanly encapsulates the native Flutter Date and Time picker dialogs,
// while keeping the exact matching UI styling of your CustomInputField.
class DateTimeRow extends StatelessWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final bool enabled;

  const DateTimeRow({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.enabled = true,
  });

  Future<void> _pickDate(BuildContext context) async {
    if (!enabled) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) onDateChanged(picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    if (!enabled) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) onTimeChanged(picked);
  }

  InputDecoration _buildDecoration(
    BuildContext context,
    String label,
    IconData icon,
    Color iconColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      prefixIcon: Icon(icon, color: iconColor),
      filled: true,
      fillColor: fillColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pickDate(context),
            child: InputDecorator(
              decoration: _buildDecoration(
                context,
                "Date",
                Icons.calendar_today,
                isDark ? Colors.lightBlueAccent : Colors.blue,
              ),
              child: Text(
                selectedDate == null
                    ? 'Select Date'
                    : "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pickTime(context),
            child: InputDecorator(
              decoration: _buildDecoration(
                context,
                "Time",
                Icons.access_time,
                isDark ? Colors.orangeAccent : Colors.orange,
              ),
              child: Text(
                selectedTime == null
                    ? 'Select Time'
                    : selectedTime!.format(context),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
