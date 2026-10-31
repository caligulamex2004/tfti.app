import 'dart:typed_data';
import 'package:flutter/material.dart';

enum SeasonUpdateScope {
  single,
  future,
  toggleOff;

  String get value {
    switch (this) {
      case SeasonUpdateScope.single:
        return 'single';
      case SeasonUpdateScope.future:
        return 'future';
      case SeasonUpdateScope.toggleOff:
        return 'toggle_off';
    }
  }

  static SeasonUpdateScope fromString(String val) {
    switch (val) {
      case 'future':
        return SeasonUpdateScope.future;
      case 'toggle_off':
        return SeasonUpdateScope.toggleOff;
      case 'single':
      default:
        return SeasonUpdateScope.single;
    }
  }
}

/// Typed request container for creating and editing hangouts.
/// Decouples service layer from loose parameter explosion.
class HangoutSubmissionRequest {
  final bool isEditing;
  final bool isMainHost;
  final bool isCoHost;
  final String? eventId;
  final Map<String, dynamic>? eventData;

  // Form values
  final String title;
  final String location;
  final String? hostLocationLabel;
  final String details;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final bool inviteAll;
  final List<String> selectedCircleIds;
  final List<String> lastMinuteInviteIds;
  final int rsvpDeadlineOffset;
  final int keepAliveDays;
  final bool isImportantDetails;

  // Recurring
  final bool isRecurring;
  final String recurringFrequency;
  final int recurringInstances;
  final List<DateTime> Function(DateTime)? generateSeasonDates;
  final SeasonUpdateScope updateScope;

  // Banner
  final String? bannerImagePath;
  final Uint8List? bannerImageBytes;
  final bool removeBanner;

  // Co-host
  final String? coHostId;
  final String? coHostName;

  // Squad needs
  final List<String> roles;

  const HangoutSubmissionRequest({
    required this.isEditing,
    required this.isMainHost,
    required this.isCoHost,
    this.eventId,
    this.eventData,
    required this.title,
    required this.location,
    this.hostLocationLabel,
    required this.details,
    required this.selectedDate,
    required this.selectedTime,
    required this.inviteAll,
    required this.selectedCircleIds,
    this.lastMinuteInviteIds = const [],
    required this.rsvpDeadlineOffset,
    required this.keepAliveDays,
    required this.isImportantDetails,
    required this.isRecurring,
    this.recurringFrequency = 'weekly',
    this.recurringInstances = 4,
    this.generateSeasonDates,
    this.updateScope = SeasonUpdateScope.single,
    this.bannerImagePath,
    this.bannerImageBytes,
    this.removeBanner = false,
    this.coHostId,
    this.coHostName,
    this.roles = const [],
  });

  DateTime get combinedDateTime => DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

  DateTime get calculatedEndTime {
    final int durationMinutes =
        keepAliveDays > 0 ? (keepAliveDays * 24 * 60) : 240;
    return combinedDateTime.add(Duration(minutes: durationMinutes));
  }
}
