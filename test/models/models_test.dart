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
}
