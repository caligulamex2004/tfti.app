import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../shared/app_banner_image.dart';
import '../shared/event_type_pill.dart';
import 'default_event_banner.dart';
import '../../utils/event_type_visuals.dart';

/// The compact tile used for horizontal landscape split view lists.
class CardLandscapeTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? bannerUrl;
  final IconData statusIcon;
  final Color statusColor;
  final String statusText;
  final bool isImportantDetails;
  final bool hasUnreadChat;
  final String title;
  final String month;
  final String day;
  final String timeString;
  final bool isPending;
  final bool isVibeCheck;

  const CardLandscapeTile({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.bannerUrl,
    required this.statusIcon,
    required this.statusColor,
    required this.statusText,
    required this.isImportantDetails,
    required this.hasUnreadChat,
    required this.title,
    required this.month,
    required this.day,
    required this.timeString,
    required this.isPending,
    required this.isVibeCheck,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final typeVisuals = EventTypeVisuals.forType(isVibeCheck: isVibeCheck);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (!isDark && !isSelected)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (bannerUrl != null && bannerUrl!.isNotEmpty)
                        ? AppBannerImage(
                            imageUrl: bannerUrl!,
                            fit: BoxFit.cover,
                          )
                        : DefaultEventBanner.thumbnail(
                            isVibeCheck: isVibeCheck,
                            thumbnailSize: 60,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isImportantDetails) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.priority_high,
                                color: Colors.red,
                                size: 12,
                              ),
                            ],
                            if (hasUnreadChat) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        EventTypePill(
                          isVibeCheck: isVibeCheck,
                          fontSize: 9,
                          iconSize: 10,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          borderRadius: 8,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$month $day • $timeString",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: typeVisuals.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: typeVisuals.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVibeCheck ? Symbols.earthquake : Icons.how_to_vote,
                        color: typeVisuals.primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVibeCheck ? "Tap to Vote" : "Tap to RSVP",
                        style: TextStyle(
                          color: typeVisuals.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
