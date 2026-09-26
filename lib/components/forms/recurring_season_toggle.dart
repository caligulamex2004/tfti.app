import 'package:flutter/material.dart';

/// Reusable widget for configuring recurring season frequency and instances.
class RecurringSeasonToggle extends StatelessWidget {
  final bool isRecurring;
  final String recurringFrequency;
  final int recurringInstances;
  final int maxRecurringInstances;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<int> onInstancesChanged;

  const RecurringSeasonToggle({
    super.key,
    required this.isRecurring,
    required this.recurringFrequency,
    required this.recurringInstances,
    required this.maxRecurringInstances,
    required this.onToggle,
    required this.onFrequencyChanged,
    required this.onInstancesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Divider(height: 1),
          SwitchListTile(
            activeThumbColor: primaryColor,
            title: const Text(
              "Turn this into a recurring Season",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Creates multiple hangouts automatically",
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            value: isRecurring,
            onChanged: onToggle,
          ),
          if (isRecurring)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Repeats",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      DropdownButton<String>(
                        value: recurringFrequency,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        dropdownColor: Theme.of(context).cardColor,
                        items: const [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text("Weekly"),
                          ),
                          DropdownMenuItem(
                            value: 'biweekly',
                            child: Text("Every 2 Weeks"),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text("Monthly"),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) onFrequencyChanged(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Total Events",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            "Max: $maxRecurringInstances",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: recurringInstances > 2
                                ? () => onInstancesChanged(recurringInstances - 1)
                                : null,
                            color: recurringInstances > 2
                                ? primaryColor
                                : Colors.grey,
                          ),
                          Text(
                            "$recurringInstances",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: recurringInstances < maxRecurringInstances
                                ? () => onInstancesChanged(recurringInstances + 1)
                                : null,
                            color: recurringInstances < maxRecurringInstances
                                ? primaryColor
                                : Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
