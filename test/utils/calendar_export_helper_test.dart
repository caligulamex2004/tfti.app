import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/utils/calendar_export_helper.dart';

void main() {
  group('CalendarExportHelper Tests', () {
    test('formatUtcForGoogleCalendar correctly formats UTC date and time string', () {
      final dt = DateTime.utc(2026, 10, 15, 18, 30, 0);
      final formatted = CalendarExportHelper.formatUtcForGoogleCalendar(dt);
      expect(formatted, '20261015T183000Z');
    });

    test('formatUtcForGoogleCalendar converts local timezone time to UTC correctly', () {
      // Local time with explicit offset
      final local = DateTime(2026, 5, 20, 12, 0, 0);
      final formatted = CalendarExportHelper.formatUtcForGoogleCalendar(local);

      final expectedUtc = local.toUtc();
      final year = expectedUtc.year.toString().padLeft(4, '0');
      final month = expectedUtc.month.toString().padLeft(2, '0');
      final day = expectedUtc.day.toString().padLeft(2, '0');
      final hour = expectedUtc.hour.toString().padLeft(2, '0');
      final minute = expectedUtc.minute.toString().padLeft(2, '0');
      final second = expectedUtc.second.toString().padLeft(2, '0');

      expect(formatted, '$year$month${day}T$hour$minute${second}Z');
    });

    test('buildGoogleCalendarUrl constructs valid Google Calendar template URL', () {
      final start = DateTime.utc(2026, 11, 1, 20, 0, 0);
      final end = DateTime.utc(2026, 11, 1, 22, 0, 0);

      final uri = CalendarExportHelper.buildGoogleCalendarUrl(
        title: 'Squad Dinner & Drinks',
        details: 'Organized via tfti.app! Check the squad chat for updates.',
        location: 'Downtown Pizza Co., 123 Main St',
        startTime: start,
        endTime: end,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'calendar.google.com');
      expect(uri.path, '/calendar/render');
      expect(uri.queryParameters['action'], 'TEMPLATE');
      expect(uri.queryParameters['text'], 'Squad Dinner & Drinks');
      expect(uri.queryParameters['dates'], '20261101T200000Z/20261101T220000Z');
      expect(uri.queryParameters['details'], 'Organized via tfti.app! Check the squad chat for updates.');
      expect(uri.queryParameters['location'], 'Downtown Pizza Co., 123 Main St');
    });

    test('buildGoogleCalendarUrl safely handles emojis and special characters', () {
      final start = DateTime.utc(2026, 12, 25, 14, 0, 0);
      final end = DateTime.utc(2026, 12, 25, 17, 0, 0);

      final uri = CalendarExportHelper.buildGoogleCalendarUrl(
        title: '🎄 Holiday Party & Games 🎲',
        details: 'Bring snacks! 🍕🍪',
        location: 'Alice\'s Apartment #4B & Rooftop',
        startTime: start,
        endTime: end,
      );

      expect(uri.queryParameters['text'], '🎄 Holiday Party & Games 🎲');
      expect(uri.queryParameters['details'], 'Bring snacks! 🍕🍪');
      expect(uri.queryParameters['location'], 'Alice\'s Apartment #4B & Rooftop');
      expect(uri.toString(), contains('calendar.google.com'));
    });
  });
}
