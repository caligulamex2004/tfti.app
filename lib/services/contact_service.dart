import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'contact_resolver.dart';

class ContactHelper {
  /// Requests permission and fetches contacts with phone numbers.
  static Future<List<Contact>?> getContacts() async {
    if (kIsWeb) {
      debugPrint("Contact import is not supported on Web.");
      return null;
    }
    try {
      // readonly: true is highly recommended for iOS to assure the user
      // you are only reading contacts, not modifying them.
      final bool permission = await FlutterContacts.requestPermission(
        readonly: true,
      );

      if (!permission) {
        debugPrint("Contact permission denied by user.");
        return null;
      }

      // Mark permission granted so ContactResolver can auto-warm cache in future sessions
      ContactResolver.instance.onPermissionGranted();

      // Fetch contacts with their properties (specifically phone numbers)
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false, // Keep it fast, skip photos to prevent memory spikes
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
}

