import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contact_service.dart';

/// In-memory, device-only contact resolver.
/// Matches normalized phone numbers to local address book display names
/// without transmitting contact book names to any cloud server or database.
class ContactResolver extends ChangeNotifier {
  ContactResolver._internal() {
    _initAuthListenerSafely();
  }
  static final ContactResolver instance = ContactResolver._internal();

  static const String _prefKeyGranted = 'contacts_permission_granted';

  final Map<String, String> _phoneToNameCache = {};
  final Map<String, String> _phoneToFirstNameCache = {};
  String? _currentUserPhone;
  bool _isWarmingUp = false;
  bool _hasWarmedUp = false;
  bool _listenerRegistered = false;

  void _initAuthListenerSafely() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
            setCurrentUserPhone(user.phoneNumber);
          } else {
            unawaited(_checkCurrentUserPhone());
          }
        } else {
          setCurrentUserPhone(null);
        }
      });
    } catch (_) {
      // Firebase might not be initialized in headless test environments
    }
  }

  /// Sets or clears the current user's phone number to ignore from address book matching.
  void setCurrentUserPhone(String? phone) {
    final normalized =
        phone != null ? ContactHelper.normalizePhone(phone) : null;
    if (_currentUserPhone != normalized) {
      _currentUserPhone = normalized;
      if (normalized != null) {
        _phoneToNameCache.remove(normalized);
        _phoneToFirstNameCache.remove(normalized);
      }
      notifyListeners();
    }
  }

  /// Current user's normalized phone number, if known.
  String? get currentUserPhone => _currentUserPhone;

  /// Returns true if [normalizedPhone] matches the current user's phone number.
  bool isCurrentUserPhone(String normalizedPhone) {
    if (_currentUserPhone != null && _currentUserPhone == normalizedPhone) {
      return true;
    }
    try {
      final authPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
      if (authPhone != null && authPhone.isNotEmpty) {
        final norm = ContactHelper.normalizePhone(authPhone);
        if (norm != null && norm == normalizedPhone) {
          return true;
        }
      }
    } catch (_) {
      // Firebase might not be initialized in headless test environments
    }
    return false;
  }

  Future<void> _checkCurrentUserPhone() async {
    if (_currentUserPhone != null && _currentUserPhone!.isNotEmpty) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        final norm = ContactHelper.normalizePhone(user.phoneNumber!);
        if (norm != null) {
          _currentUserPhone = norm;
          _phoneToNameCache.remove(norm);
          _phoneToFirstNameCache.remove(norm);
          return;
        }
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final phone = doc.data()?['phoneNumber']?.toString();
        if (phone != null && phone.isNotEmpty) {
          final norm = ContactHelper.normalizePhone(phone);
          if (norm != null) {
            _currentUserPhone = norm;
            _phoneToNameCache.remove(norm);
            _phoneToFirstNameCache.remove(norm);
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking current user phone in ContactResolver: $e");
    }
  }

  /// Returns the cached local contact name for a phone number if known, or null.
  /// Never matches the current user's own phone number.
  String? resolveName(String? rawPhone) {
    if (rawPhone == null || rawPhone.isEmpty) return null;
    final normalized = ContactHelper.normalizePhone(rawPhone);
    if (normalized == null) return null;
    if (isCurrentUserPhone(normalized)) return null;
    return _phoneToNameCache[normalized];
  }

  /// Returns the cached local contact first name for a phone number if known,
  /// or extracts the first name from [fallbackName] if provided, or null.
  /// Never matches the current user's own phone number.
  String? resolveFirstName(String? rawPhone, {String? fallbackName}) {
    if (rawPhone != null && rawPhone.isNotEmpty) {
      final normalized = ContactHelper.normalizePhone(rawPhone);
      if (normalized != null && !isCurrentUserPhone(normalized)) {
        final cachedFirst = _phoneToFirstNameCache[normalized];
        if (cachedFirst != null && cachedFirst.isNotEmpty) {
          return cachedFirst;
        }
      }
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return ContactHelper.extractFirstName(fallbackName);
    }
    return null;
  }

  /// Check if the cache has finished warming up at least once.
  bool get hasWarmedUp => _hasWarmedUp;

  /// Read-only snapshot of cached phone-to-name entries.
  Map<String, String> get cache => Map.unmodifiable(_phoneToNameCache);

  /// Read-only snapshot of cached phone-to-first-name entries.
  Map<String, String> get firstNameCache =>
      Map.unmodifiable(_phoneToFirstNameCache);

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
      await _checkCurrentUserPhone();

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      _phoneToNameCache.clear();
      _phoneToFirstNameCache.clear();
      for (final contact in contacts) {
        final name = contact.displayName.trim();
        if (name.isEmpty) continue;

        String firstName = contact.name.first.trim();
        if (firstName.isEmpty) {
          firstName = ContactHelper.extractFirstName(name);
        }

        for (final p in contact.phones) {
          final normalized = ContactHelper.normalizePhone(p.number);
          if (normalized != null &&
              !isCurrentUserPhone(normalized) &&
              !_phoneToNameCache.containsKey(normalized)) {
            _phoneToNameCache[normalized] = name;
            _phoneToFirstNameCache[normalized] = firstName;
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
  void seedForTest(
    Map<String, String> entries, {
    Map<String, String>? firstNames,
    String? currentUserPhone,
  }) {
    _phoneToNameCache.clear();
    _phoneToFirstNameCache.clear();
    if (currentUserPhone != null) {
      _currentUserPhone = ContactHelper.normalizePhone(currentUserPhone);
    }
    entries.forEach((phone, name) {
      final normalized = ContactHelper.normalizePhone(phone) ?? phone;
      if (!isCurrentUserPhone(normalized)) {
        _phoneToNameCache[normalized] = name;
        final explicitFirst = firstNames?[phone];
        _phoneToFirstNameCache[normalized] = explicitFirst != null &&
                explicitFirst.isNotEmpty
            ? explicitFirst
            : ContactHelper.extractFirstName(name);
      }
    });
    _hasWarmedUp = true;
    notifyListeners();
  }

  /// Clears the cache for unit and widget tests and notifies listeners.
  @visibleForTesting
  void clearForTest() {
    _phoneToNameCache.clear();
    _phoneToFirstNameCache.clear();
    _currentUserPhone = null;
    _hasWarmedUp = false;
    notifyListeners();
  }
}
