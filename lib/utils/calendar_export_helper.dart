class CalendarExportHelper {
  /// Formats a [DateTime] into Google Calendar's required UTC format: YYYYMMDDTHHmmssZ
  static String formatUtcForGoogleCalendar(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$year$month${day}T$hour$minute${second}Z';
  }

  /// Builds a web-compatible Google Calendar event creation URL.
  static Uri buildGoogleCalendarUrl({
    required String title,
    required String details,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final startIso = formatUtcForGoogleCalendar(startTime);
    final endIso = formatUtcForGoogleCalendar(endTime);

    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '$startIso/$endIso',
      'details': details,
      'location': location,
    });
  }
}
