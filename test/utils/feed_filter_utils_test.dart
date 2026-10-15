import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tftiapp/components/feed/feed_filter_bar.dart';
import 'package:tftiapp/models/feed_snapshot.dart';
import 'package:tftiapp/utils/feed_filter_utils.dart';

void main() {
  group('FeedFilterUtils Tests', () {
    final DateTime baseTime = DateTime(2026, 9, 23, 12, 0); // Wednesday

    test('getGreeting returns correct greeting for hours', () {
      expect(FeedFilterUtils.getGreeting(DateTime(2026, 9, 23, 8)), 'Good morning');
      expect(FeedFilterUtils.getGreeting(DateTime(2026, 9, 23, 14)), 'Good afternoon');
      expect(FeedFilterUtils.getGreeting(DateTime(2026, 9, 23, 19)), 'Good evening');
    });

    test('getFilterSubtitle returns expected strings', () {
      expect(FeedFilterUtils.getFilterSubtitle(FeedFilter.thisWeek), ' this week');
      expect(FeedFilterUtils.getFilterSubtitle(FeedFilter.nextWeek), ' next week');
      expect(FeedFilterUtils.getFilterSubtitle(FeedFilter.thisMonth), ' this month');
      expect(FeedFilterUtils.getFilterSubtitle(FeedFilter.nextMonth), ' next month');
      expect(FeedFilterUtils.getFilterSubtitle(FeedFilter.vip), ' with your VIP friends');
      expect(FeedFilterUtils.getFilterSubtitle(FeedFilter.all), '');
    });

    test('Buckets pending, going, declined, past, and hidden events properly', () {
      final events = [
        RawFeedEvent(
          id: 'event-pending',
          data: {
            'hostId': 'host1',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 2))),
            'type': 'event',
          },
        ),
        RawFeedEvent(
          id: 'event-going',
          data: {
            'hostId': 'host2',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 3))),
            'type': 'event',
          },
        ),
        RawFeedEvent(
          id: 'event-declined',
          data: {
            'hostId': 'host3',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 4))),
            'type': 'event',
          },
        ),
        RawFeedEvent(
          id: 'event-past',
          data: {
            'hostId': 'host4',
            'time': Timestamp.fromDate(baseTime.subtract(const Duration(hours: 10))),
            'endTime': Timestamp.fromDate(baseTime.subtract(const Duration(hours: 5))),
            'type': 'event',
          },
        ),
        RawFeedEvent(
          id: 'event-hidden',
          data: {
            'hostId': 'host5',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 5))),
            'type': 'event',
          },
        ),
      ];

      final myInvitesMap = {
        'event-pending': {'status': 'pending', 'isHidden': false},
        'event-going': {'status': 'going', 'isHidden': false},
        'event-declined': {'status': 'declined', 'isHidden': false},
        'event-past': {'status': 'going', 'isHidden': false},
        'event-hidden': {'status': 'going', 'isHidden': true},
      };

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: myInvitesMap,
        blockedUids: [],
        goatedUids: [],
        currentUserId: 'my-uid',
        filter: FeedFilter.all,
        currentTime: baseTime,
      );

      expect(result.actionNeeded.length, 1);
      expect(result.actionNeeded.first['id'], 'event-pending');

      expect(result.agenda.length, 1);
      expect(result.agenda.first['id'], 'event-going');

      expect(result.declined.length, 1);
      expect(result.declined.first['id'], 'event-declined');

      expect(result.past.length, 1);
      expect(result.past.first['id'], 'event-past');

      expect(result.hidden.length, 1);
      expect(result.hidden.first['id'], 'event-hidden');
    });

    test('Filters out events from blocked users', () {
      final events = [
        RawFeedEvent(
          id: 'event-blocked',
          data: {
            'hostId': 'blocked-user-id',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 1))),
          },
        ),
        RawFeedEvent(
          id: 'event-clean',
          data: {
            'hostId': 'clean-user-id',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 2))),
          },
        ),
      ];

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: {},
        blockedUids: ['blocked-user-id'],
        goatedUids: [],
        currentUserId: 'my-uid',
        filter: FeedFilter.all,
        currentTime: baseTime,
      );

      expect(result.actionNeeded.length, 1);
      expect(result.actionNeeded.first['id'], 'event-clean');
    });

    test('VIP filter only includes events from VIP hosts', () {
      final events = [
        RawFeedEvent(
          id: 'event-regular',
          data: {
            'hostId': 'friend-regular',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 1))),
          },
        ),
        RawFeedEvent(
          id: 'event-vip',
          data: {
            'hostId': 'friend-vip',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 2))),
          },
        ),
      ];

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: {},
        blockedUids: [],
        goatedUids: ['friend-vip'],
        currentUserId: 'my-uid',
        filter: FeedFilter.vip,
        currentTime: baseTime,
      );

      expect(result.actionNeeded.length, 1);
      expect(result.actionNeeded.first['id'], 'event-vip');
    });

    test('Pending events scheduled for future dates remain in Action Needed when filtering by This Week (Decoupled)', () {
      // Event happening 10 days later (next week)
      final futureTime = baseTime.add(const Duration(days: 10));
      final events = [
        RawFeedEvent(
          id: 'future-pending-invite',
          data: {
            'hostId': 'friend-1',
            'time': Timestamp.fromDate(futureTime),
            'type': 'event',
          },
        ),
        RawFeedEvent(
          id: 'future-confirmed-agenda',
          data: {
            'hostId': 'friend-2',
            'time': Timestamp.fromDate(futureTime),
            'type': 'event',
          },
        ),
      ];

      final myInvitesMap = {
        'future-pending-invite': {'status': 'pending', 'isHidden': false},
        'future-confirmed-agenda': {'status': 'going', 'isHidden': false},
      };

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: myInvitesMap,
        blockedUids: [],
        goatedUids: [],
        currentUserId: 'my-uid',
        filter: FeedFilter.thisWeek,
        currentTime: baseTime,
      );

      // Pending action item should be retained in Action Needed despite date filter
      expect(result.actionNeeded.length, 1);
      expect(result.actionNeeded.first['id'], 'future-pending-invite');

      // The Agenda strictly respects date filtering and excludes future confirmed events
      expect(result.agenda, isEmpty);
    });

    test('Pending events for next month remain in Action Needed when filtering by This Month', () {
      final nextMonthTime = baseTime.add(const Duration(days: 45));
      final events = [
        RawFeedEvent(
          id: 'next-month-pending',
          data: {
            'hostId': 'friend-1',
            'time': Timestamp.fromDate(nextMonthTime),
            'type': 'event',
          },
        ),
      ];

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: {
          'next-month-pending': {'status': 'pending', 'isHidden': false},
        },
        blockedUids: [],
        goatedUids: [],
        currentUserId: 'my-uid',
        filter: FeedFilter.thisMonth,
        currentTime: baseTime,
      );

      expect(result.actionNeeded.length, 1);
      expect(result.actionNeeded.first['id'], 'next-month-pending');
      expect(result.agenda, isEmpty);
    });

    test('VIP filter restricts Action Needed to only VIP hosts', () {
      final events = [
        RawFeedEvent(
          id: 'pending-regular',
          data: {
            'hostId': 'regular-user',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 2))),
            'type': 'event',
          },
        ),
        RawFeedEvent(
          id: 'pending-vip',
          data: {
            'hostId': 'vip-user',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 2))),
            'type': 'event',
          },
        ),
      ];

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: {
          'pending-regular': {'status': 'pending', 'isHidden': false},
          'pending-vip': {'status': 'pending', 'isHidden': false},
        },
        blockedUids: [],
        goatedUids: ['vip-user'],
        currentUserId: 'my-uid',
        filter: FeedFilter.vip,
        currentTime: baseTime,
      );

      expect(result.actionNeeded.length, 1);
      expect(result.actionNeeded.first['id'], 'pending-vip');
    });

    test('Pending events automatically decline when past RSVP deadline for hangouts', () {
      final events = [
        RawFeedEvent(
          id: 'event-expired-hangout',
          data: {
            'hostId': 'host1',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 4))),
            'rsvpDeadline': -300, // 5 hours before event => 1 hour before baseTime
            'type': 'event',
          },
        ),
        RawFeedEvent(
          id: 'event-expired-vibe-check',
          data: {
            'hostId': 'host2',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 4))),
            'rsvpDeadline': -300,
            'type': 'vibe_check',
          },
        ),
      ];

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: {},
        blockedUids: [],
        goatedUids: [],
        currentUserId: 'my-uid',
        filter: FeedFilter.all,
        currentTime: baseTime,
      );

      // Hangout should expire to declined
      expect(result.declined.any((e) => e['id'] == 'event-expired-hangout'), isTrue);
      // Vibe check should remain in action needed
      expect(result.actionNeeded.any((e) => e['id'] == 'event-expired-vibe-check'), isTrue);
    });

    test('User own events default to going status', () {
      final events = [
        RawFeedEvent(
          id: 'my-hosted-event',
          data: {
            'hostId': 'my-uid',
            'time': Timestamp.fromDate(baseTime.add(const Duration(hours: 2))),
          },
        ),
      ];

      final result = FeedFilterUtils.filterAndBucket(
        events: events,
        myInvitesMap: {},
        blockedUids: [],
        goatedUids: [],
        currentUserId: 'my-uid',
        filter: FeedFilter.all,
        currentTime: baseTime,
      );

      expect(result.agenda.length, 1);
      expect(result.agenda.first['id'], 'my-hosted-event');
    });
  });
}
