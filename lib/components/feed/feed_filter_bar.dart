import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme_provider.dart';

enum FeedFilter {
  all,
  vip,
  thisWeek,
  nextWeek,
  thisMonth,
  nextMonth;

  // Backward compatibility alias
  static const FeedFilter goated = FeedFilter.vip;
}

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
    final filters = [
      {'label': 'All', 'value': FeedFilter.all},
      {'label': '⭐ VIP', 'value': FeedFilter.vip},
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
                      ? themeProvider.pillTextColor
                      : themeProvider.chipUnselectedTextColor,
                ),
              ),
              selected: isSelected,
              selectedColor: themeProvider.pillBackgroundColor,
              backgroundColor: themeProvider.chipUnselectedBackgroundColor,
              side: BorderSide(
                color: isSelected
                    ? themeProvider.pillBackgroundColor
                    : themeProvider.chipBorderColor,
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
