import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tftiapp/models/event_model.dart';
import 'package:tftiapp/models/user_profile.dart';
import 'package:tftiapp/models/hangout_submission_request.dart';
import 'package:tftiapp/models/vibe_check_submission_request.dart';

void main() {
  group('Event Model Tests', () {
    test('Serialization and deserialization roundtrip', () {
      final now = DateTime(2026, 9, 25, 18, 30);
      final event = Event(
        id: 'evt-123',
        type: 'event',
        hostId: 'host-abc',
        title: 'Friday Night Tacos',
        location: 'Taco Haven',
        details: 'Bring your appetite',
        time: now,
        isPast: false,
        visibleTo: ['host-abc', 'guest-1'],
        invitedCircles: ['circle-squad'],
        rsvpDeadline: -60,
      );

      final map = event.toMap();
      expect(map['title'], 'Friday Night Tacos');
      expect(map['hostId'], 'host-abc');
      expect(map['location'], 'Taco Haven');
      expect(map['rsvpDeadline'], -60);
      expect((map['time'] as Timestamp).toDate(), now);

      final fromMap = Event.fromMap(map, id: 'evt-123');
      expect(fromMap.id, 'evt-123');
      expect(fromMap.title, 'Friday Night Tacos');
      expect(fromMap.hostId, 'host-abc');
      expect(fromMap.visibleTo, contains('guest-1'));
    });
  });

  group('UserProfile Model Tests', () {
    test('UserProfile defaults and field extraction', () {
      final profile = UserProfile.fromMap(
        {
          'displayName': 'Antigravity User',
          'username': 'antigravity',
          'avatarColor': 4280391411,
          'blockedUids': ['bad-actor'],
        },
        uid: 'user-1',
      );

      expect(profile.uid, 'user-1');
      expect(profile.displayName, 'Antigravity User');
      expect(profile.username, 'antigravity');
      expect(profile.blockedUids, contains('bad-actor'));
      expect(profile.showPhoneNumber, isFalse);
    });
  });

  group('Submission Request Tests', () {
    test('HangoutSubmissionRequest combinedDateTime correctly merges date and time', () {
      final req = HangoutSubmissionRequest(
        selectedDate: DateTime(2026, 10, 15),
        selectedTime: const TimeOfDay(hour: 20, minute: 45),
        isEditing: false,
        isMainHost: true,
        isCoHost: false,
        title: 'Board Game Night',
        location: 'Game Lounge',
        details: 'Settlers of Catan tournament',
        inviteAll: true,
        selectedCircleIds: const [],
        rsvpDeadlineOffset: 0,
        keepAliveDays: 1,
        isImportantDetails: false,
        isRecurring: false,
      );

      final combined = req.combinedDateTime;
      expect(combined.year, 2026);
      expect(combined.month, 10);
      expect(combined.day, 15);
      expect(combined.hour, 20);
      expect(combined.minute, 45);
    });

    test('VibeCheckSubmissionRequest combinedDateTime correctly merges date and time', () {
      final req = VibeCheckSubmissionRequest(
        selectedDate: DateTime(2026, 11, 20),
        selectedTime: const TimeOfDay(hour: 17, minute: 15),
        isEditing: false,
        title: 'Where should we eat?',
        details: 'Vote on options',
        pollOptions: const [
          {'id': '1', 'text': 'Sushi'},
          {'id': '2', 'text': 'Burgers'},
        ],
        inviteAll: true,
        selectedCircleIds: const [],
        rsvpDeadlineOffset: 0,
      );

      final combined = req.combinedDateTime;
      expect(combined.year, 2026);
      expect(combined.month, 11);
      expect(combined.day, 20);
      expect(combined.hour, 17);
      expect(combined.minute, 15);
    });
  });

  group('Seasons & Recurring Events Tests', () {
    test('Event serializes and deserializes seasonId, seasonInstance, and seasonTotal', () {
      final eventTime = DateTime(2026, 11, 1, 19, 0);
      final event = Event(
        id: 'evt-season-002',
        type: 'event',
        hostId: 'host-user-1',
        title: 'Trivia League Week 2',
        location: 'Local Pub',
        time: eventTime,
        seasonId: 'season-trivia-2026',
        seasonInstance: 2,
        seasonTotal: 8,
      );

      final map = event.toMap();
      expect(map['seasonId'], 'season-trivia-2026');
      expect(map['seasonInstance'], 2);
      expect(map['seasonTotal'], 8);

      final restored = Event.fromMap(map, id: 'evt-season-002');
      expect(restored.seasonId, 'season-trivia-2026');
      expect(restored.seasonInstance, 2);
      expect(restored.seasonTotal, 8);
    });

    test('Event.copyWith preserves or updates season fields', () {
      final event = Event(
        id: 'evt-season-001',
        type: 'event',
        hostId: 'host-user-1',
        title: 'Weekly Run Club',
        location: 'City Park',
        time: DateTime(2026, 10, 1),
        seasonId: 'season-run-club',
        seasonInstance: 1,
        seasonTotal: 4,
      );

      // Preserves season fields by default
      final copySame = event.copyWith(title: 'Updated Run Club');
      expect(copySame.seasonId, 'season-run-club');
      expect(copySame.seasonInstance, 1);
      expect(copySame.seasonTotal, 4);

      // Updates seasonInstance
      final copyNext = event.copyWith(seasonInstance: 2);
      expect(copyNext.seasonInstance, 2);
      expect(copyNext.seasonTotal, 4);
      expect(copyNext.seasonId, 'season-run-club');
    });

    test('Generates a recurring event series linked with seasonId and sequential instances', () {
      final baseDate = DateTime(2026, 10, 5, 18, 0);
      const totalInstances = 4;
      const seasonId = 'season-dnd-campaign';

      // Simulate recurring dates generator (weekly)
      final recurringDates = List.generate(
        totalInstances,
        (i) => baseDate.add(Duration(days: i * 7)),
      );

      // Create recurring events batch
      final List<Event> seasonEvents = List.generate(totalInstances, (i) {
        return Event(
          id: 'evt-dnd-$i',
          type: 'event',
          hostId: 'dm-user-42',
          title: 'D&D Campaign Session ${i + 1}',
          location: 'Castle Basement',
          time: recurringDates[i],
          seasonId: seasonId,
          seasonInstance: i + 1,
          seasonTotal: totalInstances,
          keepAliveDays: 1,
        );
      });

      expect(seasonEvents.length, 4);

      // Verify each event in the recurring season
      for (int i = 0; i < seasonEvents.length; i++) {
        final ev = seasonEvents[i];
        expect(ev.seasonId, seasonId);
        expect(ev.seasonInstance, i + 1);
        expect(ev.seasonTotal, 4);
        expect(ev.time, baseDate.add(Duration(days: i * 7)));
        // Verify duration applies to each recurring event
        expect(ev.calculatedEndTime, ev.time.add(const Duration(days: 1)));
      }
    });

    test('Recurring date generator produces correct dates for weekly, biweekly, and monthly', () {
      final start = DateTime(2026, 1, 10, 14, 0);

      List<DateTime> generateDates(String frequency, int count) {
        final List<DateTime> dates = [start];
        int daysToAdd = frequency == 'weekly' ? 7 : (frequency == 'biweekly' ? 14 : 0);
        DateTime current = start;

        for (int i = 1; i < count; i++) {
          if (frequency == 'monthly') {
            int newYear = current.year;
            int newMonth = current.month + 1;
            if (newMonth > 12) {
              newMonth = 1;
              newYear++;
            }
            int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
            int newDay = current.day > daysInNewMonth ? daysInNewMonth : current.day;
            current = DateTime(newYear, newMonth, newDay, current.hour, current.minute);
          } else {
            current = current.add(Duration(days: daysToAdd));
          }
          dates.add(current);
        }
        return dates;
      }

      // Weekly: spaced 7 days
      final weekly = generateDates('weekly', 3);
      expect(weekly, [
        DateTime(2026, 1, 10, 14, 0),
        DateTime(2026, 1, 17, 14, 0),
        DateTime(2026, 1, 24, 14, 0),
      ]);

      // Biweekly: spaced 14 days
      final biweekly = generateDates('biweekly', 3);
      expect(biweekly, [
        DateTime(2026, 1, 10, 14, 0),
        DateTime(2026, 1, 24, 14, 0),
        DateTime(2026, 2, 7, 14, 0),
      ]);

      // Monthly: spaced 1 month
      final monthly = generateDates('monthly', 3);
      expect(monthly, [
        DateTime(2026, 1, 10, 14, 0),
        DateTime(2026, 2, 10, 14, 0),
        DateTime(2026, 3, 10, 14, 0),
      ]);
    });

    test('SeasonUpdateScope enum converts to string and back correctly', () {
      expect(SeasonUpdateScope.single.value, 'single');
      expect(SeasonUpdateScope.future.value, 'future');
      expect(SeasonUpdateScope.toggleOff.value, 'toggle_off');

      expect(SeasonUpdateScope.fromString('single'), SeasonUpdateScope.single);
      expect(SeasonUpdateScope.fromString('future'), SeasonUpdateScope.future);
      expect(SeasonUpdateScope.fromString('toggle_off'), SeasonUpdateScope.toggleOff);
      expect(SeasonUpdateScope.fromString('unknown_val'), SeasonUpdateScope.single);
    });
  });

  group('Duration & Event Expiration Tests', () {
    final baseTime = DateTime(2026, 10, 20, 15, 0);

    test('calculatedEndTime defaults to 4 hours (240 minutes) when keepAliveDays is 0', () {
      final event = Event(
        id: 'evt-dur-default',
        type: 'event',
        hostId: 'host-1',
        title: 'Quick Coffee Chat',
        location: 'Café',
        time: baseTime,
        keepAliveDays: 0,
      );

      // Default duration is 240 minutes (4 hours)
      expect(event.calculatedEndTime, baseTime.add(const Duration(hours: 4)));
    });

    test('calculatedEndTime calculates 24 hours when keepAliveDays is 1 (1 Day)', () {
      final event = Event(
        id: 'evt-dur-1day',
        type: 'event',
        hostId: 'host-1',
        title: 'All-Day Hackathon',
        location: 'Innovation Lab',
        time: baseTime,
        keepAliveDays: 1,
      );

      expect(event.calculatedEndTime, baseTime.add(const Duration(days: 1)));
    });

    test('calculatedEndTime calculates 7 days when keepAliveDays is 7 (1 Week)', () {
      final event = Event(
        id: 'evt-dur-1week',
        type: 'event',
        hostId: 'host-1',
        title: 'Week-long Beach House Trip',
        location: 'Sunny Beach',
        time: baseTime,
        keepAliveDays: 7,
      );

      expect(event.calculatedEndTime, baseTime.add(const Duration(days: 7)));
    });

    test('calculatedEndTime calculates arbitrary multi-day duration (e.g. 3 days)', () {
      final event = Event(
        id: 'evt-dur-3days',
        type: 'event',
        hostId: 'host-1',
        title: 'Weekend Camping Trip',
        location: 'Yosemite',
        time: baseTime,
        keepAliveDays: 3,
      );

      expect(event.calculatedEndTime, baseTime.add(const Duration(days: 3)));
    });

    test('explicit endTime takes precedence over keepAliveDays', () {
      final customEndTime = baseTime.add(const Duration(hours: 2, minutes: 30));
      final event = Event(
        id: 'evt-dur-custom-end',
        type: 'event',
        hostId: 'host-1',
        title: 'Dinner Party',
        location: 'Bistro',
        time: baseTime,
        endTime: customEndTime,
        keepAliveDays: 2, // Even if keepAliveDays is set, explicit endTime wins
      );

      expect(event.calculatedEndTime, customEndTime);
    });

    test('isCurrentlyPast accurately determines event expiration status relative to calculatedEndTime', () {
      final event = Event(
        id: 'evt-dur-past',
        type: 'event',
        hostId: 'host-1',
        title: 'Afternoon BBQ',
        location: 'Backyard',
        time: baseTime,
        keepAliveDays: 1, // End time is baseTime + 24 hours
      );

      final endTime = event.calculatedEndTime;

      // 1 minute before end time: active (not past)
      final beforeEnd = endTime.subtract(const Duration(minutes: 1));
      expect(event.isCurrentlyPast(beforeEnd), isFalse);

      // 1 minute after end time: expired (is past)
      final afterEnd = endTime.add(const Duration(minutes: 1));
      expect(event.isCurrentlyPast(afterEnd), isTrue);

      // Explicit isPast flag overrides time
      final explicitPastEvent = event.copyWith(isPast: true);
      expect(explicitPastEvent.isCurrentlyPast(beforeEnd), isTrue);
    });

    test('HangoutSubmissionRequest calculatedEndTime mirrors Event duration calculation', () {
      final reqDefault = HangoutSubmissionRequest(
        selectedDate: DateTime(2026, 10, 20),
        selectedTime: const TimeOfDay(hour: 15, minute: 0),
        isEditing: false,
        isMainHost: true,
        isCoHost: false,
        title: 'Default Duration Hangout',
        location: 'Park',
        details: 'Picnic',
        inviteAll: true,
        selectedCircleIds: const [],
        rsvpDeadlineOffset: 0,
        keepAliveDays: 0,
        isImportantDetails: false,
        isRecurring: false,
      );
      // Default: 4 hours
      expect(
        reqDefault.calculatedEndTime,
        reqDefault.combinedDateTime.add(const Duration(hours: 4)),
      );

      final reqMultiDay = HangoutSubmissionRequest(
        selectedDate: DateTime(2026, 10, 20),
        selectedTime: const TimeOfDay(hour: 15, minute: 0),
        isEditing: false,
        isMainHost: true,
        isCoHost: false,
        title: 'Multi-day Hangout',
        location: 'Cabin',
        details: 'Retreat',
        inviteAll: true,
        selectedCircleIds: const [],
        rsvpDeadlineOffset: 0,
        keepAliveDays: 3,
        isImportantDetails: false,
        isRecurring: false,
      );
      // 3 days: 72 hours
      expect(
        reqMultiDay.calculatedEndTime,
        reqMultiDay.combinedDateTime.add(const Duration(days: 3)),
      );
    });
  });
}
