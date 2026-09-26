import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/feed/feed_filter_bar.dart';
import '../models/feed_snapshot.dart';

class FeedFilterUtils {
  /// Filters, calculates status flags, and buckets raw events into categories:
  /// Action Needed, Agenda, Declined, Past, and Hidden.
  static FilteredFeedData filterAndBucket({
    required List<RawFeedEvent> events,
    required Map<String, Map<String, dynamic>> myInvitesMap,
    required List<String> blockedUids,
    required List<String> goatedUids,
    required String currentUserId,
    required FeedFilter filter,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final int daysSinceMonday = now.weekday - 1;
    final startOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day - daysSinceMonday,
    );
    final int daysToSunday = 7 - now.weekday;
    final endOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day + daysToSunday,
      23,
      59,
      59,
    );

    final startOfNextWeek = endOfThisWeek.add(
      const Duration(seconds: 1),
    );
    final endOfNextWeek = startOfNextWeek.add(
      const Duration(
        days: 6,
        hours: 23,
        minutes: 59,
        seconds: 59,
      ),
    );

    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final endOfThisMonth = DateTime(
      now.year,
      now.month + 1,
      0,
      23,
      59,
      59,
    );

    final startOfNextMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    );
    final endOfNextMonth = DateTime(
      now.year,
      now.month + 2,
      0,
      23,
      59,
      59,
    );

    final List<Map<String, dynamic>> actionNeededEvents = [];
    final List<Map<String, dynamic>> agendaEvents = [];
    final List<Map<String, dynamic>> declinedEvents = [];
    final List<Map<String, dynamic>> pastEvents = [];
    final List<Map<String, dynamic>> hiddenEvents = [];

    for (final event in events) {
      final eventId = event.id;
      final eventData = event.data;
      final String hostId = eventData['hostId'] ?? '';

      // Skip blocked users
      if (blockedUids.contains(hostId)) continue;

      // Filter by Goated status
      if (filter == FeedFilter.goated && !goatedUids.contains(hostId)) {
        continue;
      }

      final dynamic rawTime = eventData['time'];
      final DateTime eventTime = rawTime is Timestamp
          ? rawTime.toDate()
          : (rawTime is DateTime ? rawTime : now);

      // Date range filters
      if (filter == FeedFilter.thisWeek &&
          (eventTime.isBefore(startOfThisWeek) ||
              eventTime.isAfter(endOfThisWeek))) {
        continue;
      } else if (filter == FeedFilter.nextWeek &&
          (eventTime.isBefore(startOfNextWeek) ||
              eventTime.isAfter(endOfNextWeek))) {
        continue;
      } else if (filter == FeedFilter.thisMonth &&
          (eventTime.isBefore(startOfThisMonth) ||
              eventTime.isAfter(endOfThisMonth))) {
        continue;
      } else if (filter == FeedFilter.nextMonth &&
          (eventTime.isBefore(startOfNextMonth) ||
              eventTime.isAfter(endOfNextMonth))) {
        continue;
      }

      final bool isMyEvent = hostId == currentUserId;
      final inviteData = myInvitesMap[eventId] ?? {};
      String status =
          inviteData['status'] ?? (isMyEvent ? 'going' : 'pending');
      final bool isHidden = inviteData['isHidden'] ?? false;

      // RSVP Deadline Expiration (non-vibe-checks only)
      final int deadlineOffset = eventData['rsvpDeadline'] ?? 0;
      final DateTime deadlineTime = eventTime.add(
        Duration(minutes: deadlineOffset),
      );
      if (status == 'pending' &&
          now.isAfter(deadlineTime) &&
          eventData['type'] != 'vibe_check') {
        status = 'declined';
      }

      final dynamic rawEndTime = eventData['endTime'];
      DateTime endTime;
      if (rawEndTime is Timestamp) {
        endTime = rawEndTime.toDate();
      } else if (rawEndTime is DateTime) {
        endTime = rawEndTime;
      } else {
        final int keepAliveDays = eventData['keepAliveDays'] ?? 0;
        final int durationMinutes =
            keepAliveDays > 0 ? (keepAliveDays * 24 * 60) : 240;
        endTime = eventTime.add(
          Duration(minutes: durationMinutes),
        );
      }

      final bool isPast =
          (eventData['isPast'] == true) || now.isAfter(endTime);
      final bool isStartingSoon =
          eventTime.isAfter(now) &&
          eventTime.difference(now).inMinutes <= 60;
      final bool isHappeningNow =
          !eventTime.isAfter(now) && !now.isAfter(endTime);

      final eventItem = {
        'id': eventId,
        'eventData': eventData,
        'inviteData': inviteData,
        'isPast': isPast,
        'isStartingSoon': isStartingSoon,
        'isHappeningNow': isHappeningNow,
        'status': status,
        'time': eventTime,
      };

      if (isHidden) {
        hiddenEvents.add(eventItem);
      } else if (isPast) {
        pastEvents.add(eventItem);
      } else if (status == 'pending') {
        actionNeededEvents.add(eventItem);
      } else if (status == 'going') {
        agendaEvents.add(eventItem);
      } else if (status == 'declined') {
        declinedEvents.add(eventItem);
      }
    }

    actionNeededEvents.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );
    agendaEvents.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );
    declinedEvents.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );
    pastEvents.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );
    hiddenEvents.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );

    return FilteredFeedData(
      actionNeeded: actionNeededEvents,
      agenda: agendaEvents,
      declined: declinedEvents,
      past: pastEvents,
      hidden: hiddenEvents,
    );
  }

  /// Format subtitle text for the empty state cards based on selected filter
  static String getFilterSubtitle(FeedFilter filter) {
    switch (filter) {
      case FeedFilter.thisWeek:
        return " this week";
      case FeedFilter.nextWeek:
        return " next week";
      case FeedFilter.thisMonth:
        return " this month";
      case FeedFilter.nextMonth:
        return " next month";
      case FeedFilter.goated:
        return " with your Goated friends";
      case FeedFilter.all:
        return "";
    }
  }

  /// Get time-of-day greeting (e.g. "Good morning", "Good afternoon", "Good evening")
  static String getGreeting([DateTime? time]) {
    final hour = (time ?? DateTime.now()).hour;
    if (hour < 12) {
      return "Good morning";
    } else if (hour < 17) {
      return "Good afternoon";
    } else {
      return "Good evening";
    }
  }
}
