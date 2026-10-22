import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../shared/app_banner_image.dart';
import '../shared/app_avatar.dart';
import '../shared/event_type_pill.dart';
import 'default_event_banner.dart';
import '../../models/user_profile.dart';
import '../../services/contact_resolver.dart';
import '../../services/contact_service.dart';
import '../../services/user_cache_repository.dart';

/// The 16:9 hero image banner with date badge, status pill, title, location and host pill.
class CardHeroBanner extends StatelessWidget {
  final String? bannerUrl;
  final String month;
  final String day;
  final String timeString;
  final IconData statusIcon;
  final Color statusColor;
  final String statusText;
  final bool isPending;
  final bool isImportantDetails;
  final bool isVibeCheck;
  final int keepAliveDays;
  final String title;
  final String location;
  final String? hostId;
  final Function(String hostId, Map<String, dynamic> hostData)? onHostTap;
  final bool isExpanded;

  const CardHeroBanner({
    super.key,
    required this.bannerUrl,
    required this.month,
    required this.day,
    required this.timeString,
    required this.statusIcon,
    required this.statusColor,
    required this.statusText,
    required this.isPending,
    required this.isImportantDetails,
    required this.isVibeCheck,
    required this.keepAliveDays,
    required this.title,
    required this.location,
    this.hostId,
    this.onHostTap,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCustomBanner =
        bannerUrl != null && bannerUrl!.isNotEmpty;

    final content = Stack(
        fit: StackFit.expand,
        children: [
          if (hasCustomBanner)
            AppBannerImage(
              imageUrl: bannerUrl!,
              fit: BoxFit.cover,
            )
          else
            DefaultEventBanner(
              isVibeCheck: isVibeCheck,
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: hasCustomBanner
                    ? [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.85),
                      ]
                    : [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                stops: hasCustomBanner
                    ? const [0.4, 0.7, 1.0]
                    : const [0.4, 0.75, 1.0],
              ),
            ),
          ),
          // Top-right Date badge
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    month,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    day,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    timeString,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Top-left Status pill
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isPending
                    ? statusColor
                    : Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: isPending
                    ? null
                    : Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusIcon,
                    color: isPending ? Colors.white : statusColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: isPending ? Colors.white : statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom overlay: Badges, Title, Location, Host
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isImportantDetails)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.priority_high,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "READ DETAILS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    EventTypePill(isVibeCheck: isVibeCheck),
                    if (keepAliveDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              keepAliveDays == 1
                                  ? "1 DAY"
                                  : (keepAliveDays == 7
                                      ? "1 WEEK"
                                      : "$keepAliveDays DAYS"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hostId != null)
                  FutureBuilder<UserProfile?>(
                    future: UserCacheRepository.instance.getUser(hostId!),
                    builder: (context, hostSnap) {
                      if (!hostSnap.hasData || hostSnap.data == null) {
                        return const SizedBox.shrink();
                      }
                      final hostProfile = hostSnap.data!;
                      String? currentUid;
                      try {
                        currentUid = FirebaseAuth.instance.currentUser?.uid;
                      } catch (_) {}
                      final bool isMe =
                          currentUid != null && hostId == currentUid;
                      final fallbackHost = hostProfile.displayName.isNotEmpty
                          ? hostProfile.displayName
                          : 'Someone';
                      final hostName = isMe
                          ? ContactHelper.extractFirstName(fallbackHost)
                          : (ContactResolver.instance.resolveFirstName(
                                hostProfile.phoneNumber,
                                fallbackName: fallbackHost,
                              ) ??
                              fallbackHost);
                      final avatarUrl = hostProfile.avatarUrl;
                      final avatarColor = hostProfile.resolvedColor;
                      return GestureDetector(
                        onTap: () {
                          if (onHostTap != null) {
                            onHostTap!(hostId!, hostProfile.toMap());
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAvatar(
                              radius: 10,
                              avatarColor: avatarColor,
                              avatarUrl: avatarUrl,
                              displayName: hostName,
                              fontSize: 8,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Led by $hostName",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      );

    if (isExpanded) {
      return content;
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: content,
    );
  }
}
