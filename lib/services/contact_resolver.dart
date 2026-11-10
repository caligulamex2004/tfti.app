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
    unawaited(loadFormatPreferences());
  }
  static final ContactResolver instance = ContactResolver._internal();

  static const String _prefKeyGranted = 'contacts_permission_granted';
  static const String _prefKeyMiniFormat = 'display_name_format_mini';
  static const String _prefKeyFullFormat = 'display_name_format_full';

  final Map<String, String> _phoneToNameCache = {};
  final Map<String, String> _phoneToFirstNameCache = {};
  final Map<String, String> _phoneToLastInitialNameCache = {};
  final Map<String, String> _phoneToGivenNameCache = {};

  DisplayNameFormat _miniProfileFormat = DisplayNameFormat.firstName;
  DisplayNameFormat _fullProfileFormat = DisplayNameFormat.fullName;

  String? _currentUserPhone;
  bool _isWarmingUp = false;
  bool _needsRefreshAgain = false;
  bool _hasWarmedUp = false;
  bool _listenerRegistered = false;

  /// Active display name priority for Mini Profiles (tiles & mini hero cards).
  DisplayNameFormat get miniProfileFormat => _miniProfileFormat;

  /// Active display name priority for Full Profiles (TCG profile sheet).
  DisplayNameFormat get fullProfileFormat => _fullProfileFormat;

  /// Loads persisted display name format preferences from SharedPreferences.
  Future<void> loadFormatPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawMini = prefs.getString(_prefKeyMiniFormat);
      final rawFull = prefs.getString(_prefKeyFullFormat);

      final nextMini = DisplayNameFormat.fromStorageKey(
        rawMini,
        fallback: DisplayNameFormat.firstName,
      );
      final nextFull = DisplayNameFormat.fromStorageKey(
        rawFull,
        fallback: DisplayNameFormat.fullName,
      );

      if (_miniProfileFormat != nextMini || _fullProfileFormat != nextFull) {
        _miniProfileFormat = nextMini;
        _fullProfileFormat = nextFull;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading display name format preferences: $e");
    }
  }

  /// Updates and persists the display name priority for Mini Profiles.
  Future<void> setMiniProfileFormat(DisplayNameFormat format) async {
    if (_miniProfileFormat == format) return;
    _miniProfileFormat = format;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyMiniFormat, format.name);
    } catch (e) {
      debugPrint("Error saving mini profile format preference: $e");
    }
  }

  /// Updates and persists the display name priority for Full Profiles.
  Future<void> setFullProfileFormat(DisplayNameFormat format) async {
    if (_fullProfileFormat == format) return;
    _fullProfileFormat = format;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyFullFormat, format.name);
    } catch (e) {
      debugPrint("Error saving full profile format preference: $e");
    }
  }

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

  void _removePhoneFromCaches(String normalized) {
    _phoneToNameCache.remove(normalized);
    _phoneToFirstNameCache.remove(normalized);
    _phoneToLastInitialNameCache.remove(normalized);
    _phoneToGivenNameCache.remove(normalized);
  }

  /// Sets or clears the current user's phone number to ignore from address book matching.
  void setCurrentUserPhone(String? phone) {
    final normalized =
        phone != null ? ContactHelper.normalizePhone(phone) : null;
    if (_currentUserPhone != normalized) {
      _currentUserPhone = normalized;
      if (normalized != null) {
        _removePhoneFromCaches(normalized);
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
          _removePhoneFromCaches(norm);
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
            _removePhoneFromCaches(norm);
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
  /// Never matches the current user's own phone number. Always guarantees
  /// returning strictly the single first name (no middle names or compound words).
  String? resolveFirstName(String? rawPhone, {String? fallbackName}) {
    if (rawPhone != null && rawPhone.isNotEmpty) {
      final normalized = ContactHelper.normalizePhone(rawPhone);
      if (normalized != null && !isCurrentUserPhone(normalized)) {
        final cachedFirst = _phoneToFirstNameCache[normalized];
        if (cachedFirst != null && cachedFirst.isNotEmpty) {
          return ContactHelper.extractFirstName(cachedFirst);
        }
      }
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return ContactHelper.extractFirstName(fallbackName);
    }
    return null;
  }

  /// Resolves a contact name (or [fallbackName]) formatted with [format].
  /// Never matches the current user's own phone number.
  String? resolveFormattedName(
    String? rawPhone, {
    String? fallbackName,
    required DisplayNameFormat format,
  }) {
    if (rawPhone != null && rawPhone.isNotEmpty) {
      final normalized = ContactHelper.normalizePhone(rawPhone);
      if (normalized != null && !isCurrentUserPhone(normalized)) {
        final cachedFull = _phoneToNameCache[normalized];
        if (cachedFull != null && cachedFull.isNotEmpty) {
          return switch (format) {
            DisplayNameFormat.fullName => cachedFull,
            DisplayNameFormat.firstName =>
              _phoneToFirstNameCache[normalized] ??
                  ContactHelper.extractFirstName(cachedFull),
            DisplayNameFormat.firstNameLastInitial =>
              _phoneToLastInitialNameCache[normalized] ??
                  ContactHelper.extractFirstNameLastInitial(cachedFull),
            DisplayNameFormat.givenName =>
              _phoneToGivenNameCache[normalized] ??
                  ContactHelper.extractGivenName(cachedFull),
          };
        }
      }
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return ContactHelper.formatName(fallbackName, format);
    }
    return null;
  }

  /// Resolves a name using the active [miniProfileFormat] preference.
  String? resolveMiniProfileName(String? rawPhone, {String? fallbackName}) {
    return resolveFormattedName(
      rawPhone,
      fallbackName: fallbackName,
      format: _miniProfileFormat,
    );
  }

  /// Resolves a contact name using the active [fullProfileFormat] preference.
  String? resolveFullProfileName(String? rawPhone, {String? fallbackName}) {
    return resolveFormattedName(
      rawPhone,
      fallbackName: fallbackName,
      format: _fullProfileFormat,
    );
  }

  /// Formats a fallback display name using the active [miniProfileFormat].
  String formatMiniProfileFallback(String? fallbackName) {
    return ContactHelper.formatName(fallbackName, _miniProfileFormat);
  }

  /// Formats a fallback display name using the active [fullProfileFormat].
  String formatFullProfileFallback(String? fallbackName) {
    return ContactHelper.formatName(fallbackName, _fullProfileFormat);
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
    await loadFormatPreferences();
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
    if (_isWarmingUp) {
      _needsRefreshAgain = true;
      return;
    }
    _isWarmingUp = true;

    try {
      await _checkCurrentUserPhone();

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      _phoneToNameCache.clear();
      _phoneToFirstNameCache.clear();
      _phoneToLastInitialNameCache.clear();
      _phoneToGivenNameCache.clear();

      for (final contact in contacts) {
        final name = (contact.displayName ?? '').trim();
        if (name.isEmpty) continue;

        final extractedFirst = ContactHelper.extractFirstName(name);
        final structuredFirst = contact.name?.first?.trim() ?? '';
        final structuredMiddle = contact.name?.middle?.trim() ?? '';
        final structuredLast = contact.name?.last?.trim() ?? '';

        // If structuredFirst is present as a distinct word in the display name
        // (e.g. "Dr. John Doe" -> "John" or "Doe, John" -> "John"), use it.
        // If structuredFirst does not match the display name (e.g. on Android
        // where raw contact StructuredName.GIVEN_NAME can be stale or desynced
        // from Contacts.DISPLAY_NAME_PRIMARY after editing in Google Contacts),
        // fallback to extractedFirst from the authoritative display name.
        String firstName = extractedFirst;
        bool structuredFirstValid = false;
        if (structuredFirst.isNotEmpty) {
          final pattern = RegExp(
            r'\b' + RegExp.escape(structuredFirst) + r'\b',
            caseSensitive: false,
          );
          if (pattern.hasMatch(name)) {
            structuredFirstValid = true;
            firstName = ContactHelper.extractFirstName(structuredFirst);
          }
        }
        // Enforce strictly single first name (stripping any middle names that Android bundled into GIVEN_NAME)
        firstName = ContactHelper.extractFirstName(firstName);

        bool structuredLastValid = false;
        if (structuredLast.isNotEmpty) {
          final pattern = RegExp(
            r'\b' + RegExp.escape(structuredLast) + r'\b',
            caseSensitive: false,
          );
          if (pattern.hasMatch(name)) {
            structuredLastValid = true;
          }
        }

        final String lastInitialName = ContactHelper.extractFirstNameLastInitial(
          name,
          firstName: firstName,
          lastName: structuredLastValid ? structuredLast : null,
        );

        final String givenName = ContactHelper.extractGivenName(
          name,
          structuredFirst: structuredFirstValid ? structuredFirst : null,
          structuredMiddle: structuredFirstValid ? structuredMiddle : null,
        );

        for (final p in contact.phones) {
          final normalized = ContactHelper.normalizePhone(p.number);
          if (normalized != null && !isCurrentUserPhone(normalized)) {
            final existingName = _phoneToNameCache[normalized];
            // If phone not yet cached, or if existing name is single-word and new one has more details
            if (existingName == null ||
                (!existingName.contains(' ') && name.contains(' '))) {
              _phoneToNameCache[normalized] = name;
              _phoneToFirstNameCache[normalized] = firstName;
              _phoneToLastInitialNameCache[normalized] = lastInitialName;
              _phoneToGivenNameCache[normalized] = givenName;
            }
          }
        }
      }
      _hasWarmedUp = true;

      // Ensure permission is persisted since contacts read succeeded
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyGranted, true);
      } catch (_) {}

      // Register device contacts change listener once
      if (!_listenerRegistered) {
        _listenerRegistered = true;
        FlutterContacts.onDatabaseChange.listen((_) => _onContactsChanged());
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error refreshing ContactResolver: $e");
    } finally {
      _isWarmingUp = false;
      if (_needsRefreshAgain) {
        _needsRefreshAgain = false;
        unawaited(refresh());
      }
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
    Map<String, String>? givenNames,
    Map<String, String>? lastNames,
    String? currentUserPhone,
  }) {
    _phoneToNameCache.clear();
    _phoneToFirstNameCache.clear();
    _phoneToLastInitialNameCache.clear();
    _phoneToGivenNameCache.clear();
    if (currentUserPhone != null) {
      _currentUserPhone = ContactHelper.normalizePhone(currentUserPhone);
    }
    entries.forEach((phone, name) {
      final normalized = ContactHelper.normalizePhone(phone) ?? phone;
      if (!isCurrentUserPhone(normalized)) {
        _phoneToNameCache[normalized] = name;
        final explicitFirst = firstNames?[phone];
        final first = explicitFirst != null && explicitFirst.isNotEmpty
            ? ContactHelper.extractFirstName(explicitFirst)
            : ContactHelper.extractFirstName(name);
        _phoneToFirstNameCache[normalized] = first;

        final explicitLast = lastNames?[phone];
        _phoneToLastInitialNameCache[normalized] =
            ContactHelper.extractFirstNameLastInitial(
          name,
          firstName: first,
          lastName: explicitLast,
        );

        final explicitGiven = givenNames?[phone];
        _phoneToGivenNameCache[normalized] =
            explicitGiven != null && explicitGiven.isNotEmpty
                ? explicitGiven.trim()
                : ContactHelper.extractGivenName(
                    name,
                    structuredFirst: explicitFirst,
                  );
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
    _phoneToLastInitialNameCache.clear();
    _phoneToGivenNameCache.clear();
    _miniProfileFormat = DisplayNameFormat.firstName;
    _fullProfileFormat = DisplayNameFormat.fullName;
    _currentUserPhone = null;
    _hasWarmedUp = false;
    notifyListeners();
  }
}
