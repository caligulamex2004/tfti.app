import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contact_service.dart';

/// In-memory, device-only contact resolver.
/// Matches normalized phone numbers to local address book display names
/// without transmitting contact book names to any cloud server or database.
class ContactResolver extends ChangeNotifier {
  ContactResolver._internal();
  static final ContactResolver instance = ContactResolver._internal();

  static const String _prefKeyGranted = 'contacts_permission_granted';

  final Map<String, String> _phoneToNameCache = {};
  bool _isWarmingUp = false;
  bool _hasWarmedUp = false;
  bool _listenerRegistered = false;

  /// Returns the cached local contact name for a phone number if known, or null.
  String? resolveName(String? rawPhone) {
    if (rawPhone == null || rawPhone.isEmpty) return null;
    final normalized = ContactHelper.normalizePhone(rawPhone);
    if (normalized == null) return null;
    return _phoneToNameCache[normalized];
  }

  /// Check if the cache has finished warming up at least once.
  bool get hasWarmedUp => _hasWarmedUp;

  /// Read-only snapshot of cached phone-to-name entries.
  Map<String, String> get cache => Map.unmodifiable(_phoneToNameCache);

  /// Warms up the in-memory cache if permission has previously been granted.
  /// Safe to call asynchronously on app startup or page loads without blocking the UI.
  Future<void> warmUpIfPermitted() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool wasGranted = prefs.getBool(_prefKeyGranted) ?? false;
      if (!wasGranted) return;

      await refresh();
    } catch (e) {
      debugPrint("Error warming up ContactResolver: $e");
    }
  }

  /// Marks permission as granted and triggers an immediate cache refresh.
  Future<void> onPermissionGranted() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyGranted, true);
      await refresh();
    } catch (e) {
      debugPrint("Error in ContactResolver.onPermissionGranted: $e");
    }
  }

  /// Refreshes the local in-memory phone -> contact name cache.
  Future<void> refresh() async {
    if (kIsWeb) return;
    if (_isWarmingUp) return;
    _isWarmingUp = true;

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      _phoneToNameCache.clear();
      for (final contact in contacts) {
        final name = contact.displayName.trim();
        if (name.isEmpty) continue;

        for (final p in contact.phones) {
          final normalized = ContactHelper.normalizePhone(p.number);
          if (normalized != null &&
              !_phoneToNameCache.containsKey(normalized)) {
            _phoneToNameCache[normalized] = name;
          }
        }
      }
      _hasWarmedUp = true;

      // Register device contacts change listener once
      if (!_listenerRegistered) {
        _listenerRegistered = true;
        FlutterContacts.addListener(_onContactsChanged);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error refreshing ContactResolver: $e");
    } finally {
      _isWarmingUp = false;
    }
  }

  void _onContactsChanged() {
    debugPrint(
      "Device contacts changed externally. Refreshing ContactResolver...",
    );
    refresh();
  }

  /// Seeds the cache for unit and widget tests and notifies listeners.
  @visibleForTesting
  void seedForTest(Map<String, String> entries) {
    _phoneToNameCache.clear();
    entries.forEach((phone, name) {
      final normalized = ContactHelper.normalizePhone(phone) ?? phone;
      _phoneToNameCache[normalized] = name;
    });
    _hasWarmedUp = true;
    notifyListeners();
  }

  /// Clears the cache for unit and widget tests and notifies listeners.
  @visibleForTesting
  void clearForTest() {
    _phoneToNameCache.clear();
    _hasWarmedUp = false;
    notifyListeners();
  }
}
