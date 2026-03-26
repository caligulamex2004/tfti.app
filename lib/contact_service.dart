import 'package:flutter_contacts/flutter_contacts.dart';

class ContactHelper {
  /// Requests permission and fetches contacts with phone numbers.
  static Future<List<Contact>?> getContacts() async {
    // --- REAL CROSS-PLATFORM EXECUTION ---
    // readonly: true is highly recommended for iOS to assure the user
    // you are only reading contacts, not modifying them.
    bool permission = await FlutterContacts.requestPermission(readonly: true);

    if (!permission) {
      return null; // Permission denied
    }

    // Fetch contacts with their properties (specifically phone numbers)
    List<Contact> contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false, // Keep it fast, skip photos to prevent memory spikes
    );

    return contacts;
  }

  /// Helper to normalize phone numbers for comparison
  static String? normalizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    if (digits.length > 10) return '+$digits';
    return null;
  }
}
