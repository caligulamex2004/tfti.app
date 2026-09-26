import 'package:flutter/material.dart';

/// Encapsulates all data required to create or update a Vibe Check (poll).
class VibeCheckSubmissionRequest {
  final bool isEditing;
  final String? eventId;
  final Map<String, dynamic>? eventData;
  final String title;
  final String details;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final List<Map<String, dynamic>> pollOptions;
  final bool inviteAll;
  final List<String> selectedCircleIds;
  final int rsvpDeadlineOffset;
  final String? coHostId;
  final String? coHostName;

  const VibeCheckSubmissionRequest({
    required this.isEditing,
    this.eventId,
    this.eventData,
    required this.title,
    required this.details,
    required this.selectedDate,
    required this.selectedTime,
    required this.pollOptions,
    required this.inviteAll,
    required this.selectedCircleIds,
    required this.rsvpDeadlineOffset,
    this.coHostId,
    this.coHostName,
  });

  DateTime get combinedDateTime => DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
}
