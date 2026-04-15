import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FeedFilter { all, goated, thisWeek, nextWeek, thisMonth, nextMonth }

class FeedFilterBar extends StatelessWidget {
  final FeedFilter selectedFilter;
  final ValueChanged<FeedFilter> onFilterChanged;

  const FeedFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final filters = [
      {'label': 'All', 'value': FeedFilter.all},
      {'label': '🐐 Goated', 'value': FeedFilter.goated},
      {'label': 'This Week', 'value': FeedFilter.thisWeek},
      {'label': 'Next Week', 'value': FeedFilter.nextWeek},
      {'label': 'This Month', 'value': FeedFilter.thisMonth},
      {'label': 'Next Month', 'value': FeedFilter.nextMonth},
    ];

    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final bool isSelected = selectedFilter == filter['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filter['label'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey.shade300 : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
              side: BorderSide(
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (bool selected) {
                if (selected) {
                  HapticFeedback.lightImpact();
                  onFilterChanged(filter['value'] as FeedFilter);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
