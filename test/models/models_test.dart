import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tftiapp/models/event_model.dart';
import 'package:tftiapp/models/user_profile.dart';
import 'package:tftiapp/models/hangout_submission_request.dart';
import 'package:tftiapp/models/vibe_check_submission_request.dart';
import 'package:tftiapp/models/squad_request_model.dart';
import 'package:tftiapp/models/team_model.dart';
import 'package:tftiapp/models/chat_message_model.dart';
import 'package:tftiapp/models/place_model.dart';
import 'package:tftiapp/models/friend_model.dart';
import 'package:tftiapp/models/invitation_model.dart';
import 'package:tftiapp/models/feed_snapshot.dart';

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
      expect(fromMap.lastMinuteInvites, isEmpty);
      expect(fromMap.coHostLastMinuteInvites, isNull);
    });

    test('Event serializes and deserializes lastMinuteInvites and coHostLastMinuteInvites', () {
      final now = DateTime(2026, 9, 25, 18, 30);
      final event = Event(
        id: 'evt-lmi',
        type: 'event',
        hostId: 'host-abc',
        title: 'Last Minute Hangout',
        location: 'Coffee Shop',
        time: now,
        inviteAll: false,
        invitedCircles: ['circle-1'],
        lastMinuteInvites: ['friend-x', 'friend-y'],
        coHostId: 'cohost-def',
        coHostInviteAll: false,
        coHostInvitedCircles: ['circle-2'],
        coHostLastMinuteInvites: ['friend-z'],
      );

      final map = event.toMap();
      expect(map['lastMinuteInvites'], equals(['friend-x', 'friend-y']));
      expect(map['coHostLastMinuteInvites'], equals(['friend-z']));

      final fromMap = Event.fromMap(map, id: 'evt-lmi');
      expect(fromMap.lastMinuteInvites, equals(['friend-x', 'friend-y']));
      expect(fromMap.coHostLastMinuteInvites, equals(['friend-z']));

      final updated = fromMap.copyWith(lastMinuteInvites: ['friend-x']);
      expect(updated.lastMinuteInvites, equals(['friend-x']));
      expect(updated.coHostLastMinuteInvites, equals(['friend-z']));
    });

    test('Event serializes, deserializes, and formats hostLocationLabel privacy correctly', () {
      final now = DateTime(2026, 9, 25, 18, 30);
      final event = Event(
        id: 'evt-vip',
        type: 'event',
        hostId: 'host-adam',
        title: 'Board Game Night',
        location: '1234 Main St, Atlanta, GA 30301',
        hostLocationLabel: 'My house',
        time: now,
      );

      final map = event.toMap();
      expect(map['location'], '1234 Main St, Atlanta, GA 30301');
      expect(map['hostLocationLabel'], 'My house');

      final fromMap = Event.fromMap(map, id: 'evt-vip');
      expect(fromMap.location, '1234 Main St, Atlanta, GA 30301');
      expect(fromMap.hostLocationLabel, 'My house');

      // Host sees private label prefixed to address
      expect(
        fromMap.displayLocation(currentUserId: 'host-adam'),
        'My house • 1234 Main St, Atlanta, GA 30301',
      );

      // Co-host and crew see ONLY the clean address
      expect(
        fromMap.displayLocation(currentUserId: 'cohost-bob'),
        '1234 Main St, Atlanta, GA 30301',
      );
      expect(
        fromMap.displayLocation(currentUserId: 'guest-charlie'),
        '1234 Main St, Atlanta, GA 30301',
      );
      expect(
        fromMap.displayLocation(currentUserId: null),
        '1234 Main St, Atlanta, GA 30301',
      );

      // CopyWith preserves or updates hostLocationLabel
      final modified = fromMap.copyWith(hostLocationLabel: 'The Mancave');
      expect(modified.hostLocationLabel, 'The Mancave');
      expect(
        modified.displayLocation(currentUserId: 'host-adam'),
        'The Mancave • 1234 Main St, Atlanta, GA 30301',
      );
    });
  });

  group('UserProfile Model Tests', () {
    test('UserProfile defaults and field extraction', () {
      final profile = UserProfile.fromMap({
        'displayName': 'Antigravity User',
        'username': 'antigravity',
        'avatarColor': 4280391411,
        'blockedUids': ['bad-actor'],
      }, uid: 'user-1');

      expect(profile.uid, 'user-1');
      expect(profile.displayName, 'Antigravity User');
      expect(profile.username, 'antigravity');
      expect(profile.blockedUids, contains('bad-actor'));
      expect(
        profile.showPhoneNumber,
        isTrue,
      ); // Default to showing phone number for users
      expect(
        profile.isSearchableByPhone,
        isTrue,
      ); // Default to searchable for users
    });

    test(
      'UserProfile phone privacy and searchability parsing and serialization',
      () {
        // Opted out of phone search
        final privateProfile = UserProfile.fromMap({
          'displayName': 'Private User',
          'username': 'private_user',
          'phoneNumber': '+15550001111',
          'isPhonePublic': false,
          'isSearchableByPhone': false,
        }, uid: 'user-private');

        expect(privateProfile.showPhoneNumber, isFalse);
        expect(privateProfile.isSearchableByPhone, isFalse);

        final map = privateProfile.toMap();
        expect(map['isPhonePublic'], isFalse);
        expect(map['showPhoneNumber'], isFalse);
        expect(map['isSearchableByPhone'], isFalse);

        // Legacy user with isPhonePublic: true
        final legacyPublic = UserProfile.fromMap({
          'displayName': 'Public User',
          'username': 'public_user',
          'phoneNumber': '+15550002222',
          'isPhonePublic': true,
        }, uid: 'user-public');

        expect(legacyPublic.showPhoneNumber, isTrue);
        expect(
          legacyPublic.isSearchableByPhone,
          isTrue,
        ); // default true when not set

        // copyWith updates searchability
        final updated = privateProfile.copyWith(
          isSearchableByPhone: true,
          showPhoneNumber: true,
        );
        expect(updated.isSearchableByPhone, isTrue);
        expect(updated.showPhoneNumber, isTrue);
      },
    );
  });

  group('Submission Request Tests', () {
    test(
      'HangoutSubmissionRequest combinedDateTime correctly merges date and time',
      () {
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
      },
    );

    test(
      'VibeCheckSubmissionRequest combinedDateTime correctly merges date and time',
      () {
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
        expect(req.lastMinuteInviteIds, isEmpty);
        expect(req.isMainHost, isTrue);
        expect(req.isCoHost, isFalse);
      },
    );

    test(
      'HangoutSubmissionRequest and VibeCheckSubmissionRequest store lastMinuteInviteIds',
      () {
        final hangoutReq = HangoutSubmissionRequest(
          selectedDate: DateTime(2026, 10, 15),
          selectedTime: const TimeOfDay(hour: 20, minute: 45),
          isEditing: true,
          isMainHost: false,
          isCoHost: true,
          title: 'Board Game Night',
          location: 'Game Lounge',
          details: 'Settlers of Catan tournament',
          inviteAll: false,
          selectedCircleIds: const ['circle-1'],
          lastMinuteInviteIds: const ['friend-1', 'friend-2'],
          rsvpDeadlineOffset: 0,
          keepAliveDays: 1,
          isImportantDetails: false,
          isRecurring: false,
        );
        expect(
          hangoutReq.lastMinuteInviteIds,
          equals(['friend-1', 'friend-2']),
        );

        final vibeReq = VibeCheckSubmissionRequest(
          selectedDate: DateTime(2026, 11, 20),
          selectedTime: const TimeOfDay(hour: 17, minute: 15),
          isEditing: true,
          isMainHost: false,
          isCoHost: true,
          title: 'Where should we eat?',
          details: 'Vote on options',
          pollOptions: const [
            {'id': '1', 'text': 'Sushi'},
            {'id': '2', 'text': 'Burgers'},
          ],
          inviteAll: false,
          selectedCircleIds: const ['circle-2'],
          lastMinuteInviteIds: const ['friend-3'],
          rsvpDeadlineOffset: 0,
        );
        expect(vibeReq.lastMinuteInviteIds, equals(['friend-3']));
        expect(vibeReq.isMainHost, isFalse);
        expect(vibeReq.isCoHost, isTrue);
      },
    );
  });

  group('Seasons & Recurring Events Tests', () {
    test(
      'Event serializes and deserializes seasonId, seasonInstance, and seasonTotal',
      () {
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
      },
    );

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

    test(
      'Generates a recurring event series linked with seasonId and sequential instances',
      () {
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
      },
    );

    test(
      'Recurring date generator produces correct dates for weekly, biweekly, and monthly',
      () {
        final start = DateTime(2026, 1, 10, 14, 0);

        List<DateTime> generateDates(String frequency, int count) {
          final List<DateTime> dates = [start];
          int daysToAdd = frequency == 'weekly'
              ? 7
              : (frequency == 'biweekly' ? 14 : 0);
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
              int newDay = current.day > daysInNewMonth
                  ? daysInNewMonth
                  : current.day;
              current = DateTime(
                newYear,
                newMonth,
                newDay,
                current.hour,
                current.minute,
              );
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
      },
    );

    test('SeasonUpdateScope enum converts to string and back correctly', () {
      expect(SeasonUpdateScope.single.value, 'single');
      expect(SeasonUpdateScope.future.value, 'future');
      expect(SeasonUpdateScope.toggleOff.value, 'toggle_off');

      expect(SeasonUpdateScope.fromString('single'), SeasonUpdateScope.single);
      expect(SeasonUpdateScope.fromString('future'), SeasonUpdateScope.future);
      expect(
        SeasonUpdateScope.fromString('toggle_off'),
        SeasonUpdateScope.toggleOff,
      );
      expect(
        SeasonUpdateScope.fromString('unknown_val'),
        SeasonUpdateScope.single,
      );
    });
  });

  group('Duration & Event Expiration Tests', () {
    final baseTime = DateTime(2026, 10, 20, 15, 0);

    test(
      'calculatedEndTime defaults to 4 hours (240 minutes) when keepAliveDays is 0',
      () {
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
      },
    );

    test(
      'calculatedEndTime calculates 24 hours when keepAliveDays is 1 (1 Day)',
      () {
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
      },
    );

    test(
      'calculatedEndTime calculates 7 days when keepAliveDays is 7 (1 Week)',
      () {
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
      },
    );

    test(
      'calculatedEndTime calculates arbitrary multi-day duration (e.g. 3 days)',
      () {
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
      },
    );

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

    test(
      'isCurrentlyPast accurately determines event expiration status relative to calculatedEndTime',
      () {
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
      },
    );

    test(
      'HangoutSubmissionRequest calculatedEndTime mirrors Event duration calculation',
      () {
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
      },
    );

    test(
      'HangoutSubmissionRequest supports bannerImageBytes for web uploads and preserves image state',
      () {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final req = HangoutSubmissionRequest(
          selectedDate: DateTime(2026, 10, 20),
          selectedTime: const TimeOfDay(hour: 18, minute: 0),
          isEditing: false,
          isMainHost: true,
          isCoHost: false,
          title: 'Beach Volleyball',
          location: 'Ocean Beach',
          details: 'Bring sunscreen and water',
          inviteAll: true,
          selectedCircleIds: const [],
          rsvpDeadlineOffset: -120,
          keepAliveDays: 0,
          isImportantDetails: false,
          isRecurring: false,
          bannerImageBytes: bytes,
          bannerImagePath: 'blob:http://localhost/dummy-blob',
          removeBanner: false,
        );

        expect(req.bannerImageBytes, equals(bytes));
        expect(req.bannerImagePath, equals('blob:http://localhost/dummy-blob'));
        expect(req.removeBanner, isFalse);
      },
    );
  });

  group('SquadRequest Model Tests', () {
    test(
      'Serialization and deserialization roundtrip with createdAt and addedAt',
      () {
        final now = DateTime(2026, 10, 13, 11, 0);
        final req = SquadRequest(
          id: 'user-a',
          fromUid: 'user-a',
          toUid: 'user-x',
          displayName: 'Ash Ketchum',
          username: 'ash_k',
          avatarUrl: 'https://example.com/avatar.png',
          avatarColor: 4280391411,
          status: 'pending',
          source: 'phone',
          createdAt: now,
          addedAt: now,
        );

        final map = req.toMap();
        expect(map['fromUid'], 'user-a');
        expect(map['toUid'], 'user-x');
        expect(map['displayName'], 'Ash Ketchum');
        expect(map['username'], 'ash_k');
        expect(map['status'], 'pending');
        expect(map['source'], 'phone');
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['addedAt'], isA<Timestamp>());

        // Deserialization from map
        final fromMap = SquadRequest.fromMap(map, id: 'user-a');
        expect(fromMap.id, 'user-a');
        expect(fromMap.fromUid, 'user-a');
        expect(fromMap.toUid, 'user-x');
        expect(fromMap.displayName, 'Ash Ketchum');
        expect(fromMap.username, 'ash_k');
        expect(fromMap.createdAt, now);
        expect(fromMap.addedAt, now);
        expect(fromMap.effectiveDate, now);
      },
    );

    test(
      'Backwards compatibility: supports addedAt when createdAt is omitted',
      () {
        final legacyTime = DateTime(2026, 10, 1, 12, 0);
        final legacyMap = {
          'fromUid': 'user-b',
          'toUid': 'user-x',
          'displayName': 'Brock',
          'username': 'brock_gym',
          'addedAt': Timestamp.fromDate(legacyTime),
          // createdAt omitted!
        };

        final req = SquadRequest.fromMap(legacyMap);
        expect(req.fromUid, 'user-b');
        expect(req.displayName, 'Brock');
        expect(req.effectiveDate, legacyTime);
        expect(req.addedAt, legacyTime);
        expect(req.createdAt, legacyTime); // Fallbacks to addedAt
      },
    );

    test('14-day expiration logic (isExpired)', () {
      final now = DateTime(2026, 10, 15, 12, 0);

      // 5 days old -> not expired
      final recentReq = SquadRequest(
        id: 'req-recent',
        fromUid: 'user-1',
        toUid: 'user-2',
        displayName: 'Misty',
        username: 'misty',
        createdAt: now.subtract(const Duration(days: 5)),
      );
      expect(recentReq.isExpired(currentTime: now), isFalse);

      // 13 days, 23 hours old -> not expired
      final almostExpiredReq = SquadRequest(
        id: 'req-almost',
        fromUid: 'user-1',
        toUid: 'user-2',
        displayName: 'Misty',
        username: 'misty',
        createdAt: now.subtract(const Duration(days: 13, hours: 23)),
      );
      expect(almostExpiredReq.isExpired(currentTime: now), isFalse);

      // 14 days and 1 hour old -> expired!
      final expiredReq = SquadRequest(
        id: 'req-expired',
        fromUid: 'user-1',
        toUid: 'user-2',
        displayName: 'Misty',
        username: 'misty',
        createdAt: now.subtract(const Duration(days: 14, hours: 1)),
      );
      expect(expiredReq.isExpired(currentTime: now), isTrue);
    });
  });

  group('TeamCircle & TeamMember Tests', () {
    test('TeamCircle toMap and copyWith', () {
      final now = DateTime(2026, 10, 1, 12, 0);
      final circle = TeamCircle(
        id: 'circle-1',
        name: 'The OG Squad',
        createdAt: now,
        memberCount: 5,
      );

      final map = circle.toMap();
      expect(map['name'], 'The OG Squad');
      expect((map['createdAt'] as Timestamp).toDate(), now);

      final updated = circle.copyWith(name: 'The New Squad', memberCount: 6);
      expect(updated.id, 'circle-1');
      expect(updated.name, 'The New Squad');
      expect(updated.memberCount, 6);
      expect(updated.createdAt, now);
    });

    test('TeamMember score calculation and color resolution', () {
      const member = TeamMember(
        uid: 'user-77',
        displayName: 'Red',
        username: 'red_pkmn',
        phoneNumber: '+15551234567',
        avatarColor: 4280391411,
        hp: 100,
        mana: 50,
        isGoated: true,
        circles: ['circle-1', 'circle-2'],
      );

      // score formula: (hp * 0.6) + (mana * 0.4) -> (60) + (20) = 80.0
      expect(member.score, closeTo(80.0, 0.001));
      expect(member.resolvedColor.toARGB32(), 4280391411);
      expect(member.isGoated, isTrue);
      expect(member.circles, contains('circle-1'));

      // Fallback color when avatarColor is null
      const defaultMember = TeamMember(
        uid: 'user-default',
        displayName: 'Blue',
      );
      expect(defaultMember.resolvedColor, isNotNull);
      expect(defaultMember.score, 0.0);
    });
  });

  group('ChatMessage Model Tests', () {
    test('ChatMessage fromMap and toMap roundtrip', () {
      final now = DateTime(2026, 10, 10, 14, 30);
      final msg = ChatMessage(
        id: 'msg-1',
        eventId: 'evt-100',
        senderId: 'user-ash',
        senderName: 'Ash',
        senderAvatarUrl: 'https://example.com/ash.jpg',
        senderColor: 4280391411,
        text: 'Who is ready for tacos? @gary',
        imageUrl: 'https://example.com/taco.jpg',
        timestamp: now,
        mentionedUids: ['user-gary'],
        reactions: {
          '🔥': ['user-gary', 'user-brock'],
        },
        readBy: [
          {'uid': 'user-gary', 'readAt': now.toIso8601String()},
        ],
        type: 'text',
      );

      final map = msg.toMap();
      expect(map['senderId'], 'user-ash');
      expect(map['senderName'], 'Ash');
      expect(map['text'], 'Who is ready for tacos? @gary');
      expect(map['imageUrl'], 'https://example.com/taco.jpg');
      expect(map['mentionedUids'], contains('user-gary'));
      expect(map['reactions']['🔥'], contains('user-brock'));
      expect((map['timestamp'] as Timestamp).toDate(), now);

      final restored = ChatMessage.fromMap(
        map,
        id: 'msg-1',
        eventId: 'evt-100',
      );
      expect(restored.id, 'msg-1');
      expect(restored.eventId, 'evt-100');
      expect(restored.senderName, 'Ash');
      expect(restored.hasImage, isTrue);
      expect(restored.isSystem, isFalse);
      expect(restored.isFromUser('user-ash'), isTrue);
      expect(restored.isFromUser('user-gary'), isFalse);
      expect(restored.reactions['🔥']?.length, 2);
    });

    test(
      'ChatMessage handles ISO string timestamp and empty fields gracefully',
      () {
        final isoString = '2026-10-12T18:00:00.000Z';
        final rawMap = {
          'senderId': 'system-bot',
          'text': 'Welcome everyone!',
          'timestamp': isoString,
          'type': 'system',
        };

        final msg = ChatMessage.fromMap(rawMap, id: 'msg-sys');
        expect(msg.isSystem, isTrue);
        expect(msg.hasImage, isFalse);
        expect(msg.senderName, 'Guest'); // Default
        expect(msg.timestamp, DateTime.parse(isoString));
        expect(msg.isWhisper, isFalse);
        expect(msg.visibleTo, isNull);
      },
    );

    test('ChatMessage supports whisper messaging fields roundtrip', () {
      final now = DateTime(2026, 10, 21, 23, 0);
      final whisperMsg = ChatMessage(
        id: 'msg-whisper-1',
        eventId: 'evt-100',
        senderId: 'user-charlie',
        senderName: 'Charlie',
        text: 'Can you bring extra napkins? 🤫',
        timestamp: now,
        isWhisper: true,
        visibleTo: ['user-charlie', 'user-adam'],
        whisperRecipientId: 'user-adam',
        whisperRecipientName: 'Adam',
      );

      final map = whisperMsg.toMap();
      expect(map['isWhisper'], isTrue);
      expect(map['visibleTo'], equals(['user-charlie', 'user-adam']));
      expect(map['whisperRecipientId'], 'user-adam');
      expect(map['whisperRecipientName'], 'Adam');

      final restored = ChatMessage.fromMap(
        map,
        id: 'msg-whisper-1',
        eventId: 'evt-100',
      );
      expect(restored.isWhisper, isTrue);
      expect(restored.visibleTo, equals(['user-charlie', 'user-adam']));
      expect(restored.whisperRecipientId, 'user-adam');
      expect(restored.whisperRecipientName, 'Adam');
    });
  });

  group('SavedPlace Model Tests', () {
    test('SavedPlace parsing and serialization', () {
      final now = DateTime(2026, 10, 5, 20, 0);
      final place = SavedPlace(
        id: 'place-abc',
        name: 'Super Taqueria',
        address: '123 Taco Lane',
        createdAt: now,
        placeId: 'google-place-999',
        lat: 37.7749,
        lng: -122.4194,
      );

      final map = place.toMap();
      expect(map['name'], 'Super Taqueria');
      expect(map['address'], '123 Taco Lane');
      expect(map['placeId'], 'google-place-999');
      expect(map['lat'], 37.7749);
      expect(map['lng'], -122.4194);
      expect((map['createdAt'] as Timestamp).toDate(), now);

      // Test parsing with string lat/lng
      final stringCoordMap = {
        'name': 'String Coords Spot',
        'address': '456 Main St',
        'lat': '34.0522',
        'lng': '-118.2437',
        'addedAt': Timestamp.fromDate(now),
      };

      final fromStringCoord = SavedPlace.fromMap(
        stringCoordMap,
        id: 'spot-str',
      );
      expect(fromStringCoord.lat, 34.0522);
      expect(fromStringCoord.lng, -118.2437);
      expect(fromStringCoord.createdAt, now); // Fallback from addedAt

      final copy = place.copyWith(name: 'Updated Taqueria');
      expect(copy.name, 'Updated Taqueria');
      expect(copy.lat, 37.7749);
    });
  });

  group('Friend Model Tests', () {
    test('Friend toMap, copyWith, and fields', () {
      final now = DateTime(2026, 10, 2, 9, 30);
      final friend = Friend(
        uid: 'friend-42',
        phoneNumber: '+15559876543',
        isGoated: true,
        circles: ['circle-inner', 'circle-lunch'],
        addedAt: now,
      );

      final map = friend.toMap();
      expect(map['uid'], 'friend-42');
      expect(map['phoneNumber'], '+15559876543');
      expect(map['isGoated'], isTrue);
      expect(map['circles'], contains('circle-lunch'));
      expect((map['addedAt'] as Timestamp).toDate(), now);

      final copy = friend.copyWith(isGoated: false);
      expect(copy.isGoated, isFalse);
      expect(copy.uid, 'friend-42');
      expect(copy.circles.length, 2);
    });
  });

  group('Invitation Model Tests', () {
    test('Invitation getters and serialization', () {
      final now = DateTime(2026, 10, 11, 15, 0);
      final inv = Invitation(
        uid: 'user-invited',
        eventId: 'evt-200',
        status: 'going',
        isHidden: false,
        isMuted: true,
        respondedAt: now,
        lastReadChat: now,
        lastViewedAt: now,
      );

      expect(inv.isGoing, isTrue);
      expect(inv.isDeclined, isFalse);
      expect(inv.isPending, isFalse);

      final map = inv.toMap();
      expect(map['status'], 'going');
      expect(map['isMuted'], isTrue);
      expect(map['isHidden'], isFalse);
      expect((map['respondedAt'] as Timestamp).toDate(), now);

      final fromMap = Invitation.fromMap(
        map,
        uid: 'user-invited',
        eventId: 'evt-200',
      );
      expect(fromMap.isGoing, isTrue);
      expect(fromMap.isMuted, isTrue);
      expect(fromMap.respondedAt, now);

      final declinedInv = inv.copyWith(status: 'declined');
      expect(declinedInv.isDeclined, isTrue);
      expect(declinedInv.isGoing, isFalse);
    });
  });

  group('FeedSnapshot & FilteredFeedData Tests', () {
    test('FeedSnapshot.empty default values', () {
      expect(FeedSnapshot.empty.firstName, 'there');
      expect(FeedSnapshot.empty.blockedUids, isEmpty);
      expect(FeedSnapshot.empty.goatedUids, isEmpty);
      expect(FeedSnapshot.empty.myInvitesMap, isEmpty);
      expect(FeedSnapshot.empty.events, isEmpty);
    });

    test('FilteredFeedData defaults', () {
      const data = FilteredFeedData();
      expect(data.actionNeeded, isEmpty);
      expect(data.agenda, isEmpty);
      expect(data.declined, isEmpty);
      expect(data.past, isEmpty);
      expect(data.hidden, isEmpty);
    });
  });
}
