import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'contact_resolver.dart';

/// User-configurable priority for how display names are formatted.
enum DisplayNameFormat {
  fullName,
  firstName,
  firstNameLastInitial,
  givenName;

  String get label => switch (this) {
    DisplayNameFormat.fullName => 'Full Name',
    DisplayNameFormat.firstName => 'First Name',
    DisplayNameFormat.firstNameLastInitial => 'First Name Last Initial',
    DisplayNameFormat.givenName => 'First Name Middle Name (Given Name)',
  };

  static DisplayNameFormat fromStorageKey(
    String? raw, {
    required DisplayNameFormat fallback,
  }) {
    if (raw == null || raw.isEmpty) return fallback;
    for (final value in DisplayNameFormat.values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}

class ContactHelper {
  /// Requests permission and fetches contacts with phone numbers.
  static Future<List<Contact>?> getContacts() async {
    if (kIsWeb) {
      debugPrint("Contact import is not supported on Web.");
      return null;
    }
    try {
      // readonly permission is recommended for iOS to assure the user
      // you are only reading contacts, not modifying them.
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      final bool permission = status == PermissionStatus.granted ||
          status == PermissionStatus.limited;

      if (!permission) {
        debugPrint("Contact permission denied by user.");
        return null;
      }

      // Mark permission granted so ContactResolver can auto-warm cache in future sessions
      ContactResolver.instance.onPermissionGranted();

      // Fetch contacts with their properties (specifically names and phone numbers)
      final List<Contact> contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      return contacts;
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
      return null;
    }
  }

  /// Helper to normalize phone numbers for database comparison
  static String? normalizePhone(String raw) {
    if (raw.isEmpty) return null;

    // Strip everything except digits
    final String digits = raw.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    if (digits.length > 10) return '+$digits';

    return null;
  }

  /// Picks the first non-null, non-empty phone string from [candidates].
  /// Prevents empty strings (`""`) from short-circuiting Dart's `??` operator.
  static String pickPhone(Iterable<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '';
  }

  /// Extracts the first name from a full name string.
  /// Handles both "First Last" and "Last, First" conventions.
  /// If [fullName] is null or empty, returns an empty string.
  static String extractFirstName(String? fullName) {
    if (fullName == null) return '';
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';

    // Handle "Last, First" format (e.g. "Smith, John" -> "John")
    if (trimmed.contains(',')) {
      final commaParts = trimmed.split(',');
      if (commaParts.length > 1) {
        final afterComma = commaParts[1].trim();
        if (afterComma.isNotEmpty) {
          final wordsAfterComma = afterComma.split(RegExp(r'\s+'));
          if (wordsAfterComma.isNotEmpty && wordsAfterComma.first.isNotEmpty) {
            return wordsAfterComma.first;
          }
        }
      }
      return commaParts.first.trim();
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  /// Extracts "First L." (First Name + Last Initial) from a full name string.
  /// Falls back to just the first name if only a single name word exists.
  static String extractFirstNameLastInitial(
    String? fullName, {
    String? firstName,
    String? lastName,
  }) {
    if (fullName == null) return '';
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';

    final String first = (firstName != null && firstName.trim().isNotEmpty)
        ? extractFirstName(firstName)
        : extractFirstName(trimmed);
    if (first.isEmpty) return '';

    String? lastWord;
    if (lastName != null && lastName.trim().isNotEmpty) {
      lastWord = lastName.trim().split(RegExp(r'\s+')).last;
    } else if (trimmed.contains(',')) {
      final commaParts = trimmed.split(',');
      if (commaParts.length > 1 &&
          commaParts[1].trim().isNotEmpty &&
          commaParts[0].trim().isNotEmpty) {
        lastWord = commaParts[0].trim().split(RegExp(r'\s+')).last;
      }
    } else {
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        lastWord = parts.last;
      }
    }

    if (lastWord != null && lastWord.isNotEmpty) {
      return '$first ${lastWord[0].toUpperCase()}.';
    }
    return first;
  }

  /// Extracts "First Middle" (Given Name) from a full name string.
  /// Uses structured [structuredFirst] + [structuredMiddle] when available and valid;
  /// for plain strings, takes all words before the last word when 3+ words
  /// ("Robert Michael Yen" -> "Robert Michael"), and the first word when 1–2 words
  /// ("John Smith" -> "John") so last names are not mistaken for middle names.
  static String extractGivenName(
    String? fullName, {
    String? structuredFirst,
    String? structuredMiddle,
  }) {
    if (fullName == null) return '';
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';

    final sFirst = structuredFirst?.trim() ?? '';
    final sMiddle = structuredMiddle?.trim() ?? '';
    if (sFirst.isNotEmpty) {
      final combined = (sMiddle.isNotEmpty &&
              !sFirst.toLowerCase().endsWith(sMiddle.toLowerCase()))
          ? '$sFirst $sMiddle'
          : sFirst;
      final normalizedCombined = combined.split(RegExp(r'\s+')).join(' ');
      if (normalizedCombined.contains(' ')) {
        final pattern = RegExp(
          r'\b' + RegExp.escape(normalizedCombined) + r'\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(trimmed)) {
          return normalizedCombined;
        }
      }
    }

    if (trimmed.contains(',')) {
      final commaParts = trimmed.split(',');
      if (commaParts.length > 1) {
        final afterComma = commaParts[1].trim();
        if (afterComma.isNotEmpty) {
          return afterComma.split(RegExp(r'\s+')).join(' ');
        }
      }
      return commaParts.first.trim();
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return parts.sublist(0, parts.length - 1).join(' ');
    }
    return parts.first;
  }

  /// Formats [fullName] according to the user's chosen [DisplayNameFormat].
  static String formatName(
    String? fullName,
    DisplayNameFormat format, {
    String? firstName,
    String? givenName,
    String? lastName,
  }) {
    if (fullName == null) return '';
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';

    return switch (format) {
      DisplayNameFormat.fullName => trimmed,
      DisplayNameFormat.firstName =>
        (firstName != null && firstName.trim().isNotEmpty)
            ? extractFirstName(firstName)
            : extractFirstName(trimmed),
      DisplayNameFormat.firstNameLastInitial => extractFirstNameLastInitial(
        trimmed,
        firstName: firstName,
        lastName: lastName,
      ),
      DisplayNameFormat.givenName =>
        (givenName != null && givenName.trim().isNotEmpty)
            ? givenName.trim()
            : extractGivenName(trimmed, structuredFirst: firstName),
    };
  }
}

