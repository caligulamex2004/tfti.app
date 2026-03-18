import 'dart:io' show Platform;
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactHelper {
  /// Requests permission and fetches contacts with phone numbers.
  static Future<List<Contact>?> getContacts() async {
    // --- TEMPORARY iOS BYPASS ---
    // Prevents the Swift native crash on the iOS 18 Simulator.
    // Once tested on a physical iPhone, this check can be removed.
    if (Platform.isIOS) {
      return <Contact>[];
    }

    // --- REAL ANDROID EXECUTION ---
    bool permission = await FlutterContacts.requestPermission();

    if (!permission) {
      return null; // Permission denied
    }

    List<Contact> contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false, // Keep it fast, skip photos for now
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
