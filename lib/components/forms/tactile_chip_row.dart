import 'package:flutter/material.dart';

class TactileChipRow<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Map<String, dynamic>>
  options; // e.g. [{'label': '1 Day', 'value': 1}]
  final T selectedValue;
  final ValueChanged<T> onSelected;

  const TactileChipRow({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final T value = opt['value'] as T;
              final isSelected = selectedValue == value;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(opt['label']),
                  selected: isSelected,
                  onSelected: (selected) {
                    FocusScope.of(context).unfocus(); // Drops the keyboard!
                    if (selected) onSelected(value);
                  },
                  selectedColor: primaryColor.withValues(alpha: 0.15),
                  backgroundColor: isDark
                      ? Colors.grey.shade900
                      : Colors.grey.shade50,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? primaryColor
                        : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.5)
                        : (isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
