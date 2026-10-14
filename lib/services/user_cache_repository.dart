import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tftiapp/models/event_model.dart';
import 'package:tftiapp/models/user_profile.dart';

class _CachedEntry<T> {
  final T data;
  final DateTime cachedAt;

  _CachedEntry(this.data) : cachedAt = DateTime.now();

  bool isExpired(Duration ttl) =>
      DateTime.now().difference(cachedAt) > ttl;
}

/// In-memory cache and batching repository for Firestore user and event reads.
/// Eradicates N+1 sequential query loops across teams, chats, and badges.
class UserCacheRepository {
  UserCacheRepository._internal();
  static final UserCacheRepository instance = UserCacheRepository._internal();

  final Map<String, _CachedEntry<UserProfile>> _userCache = {};
  final Map<String, _CachedEntry<Event>> _eventCache = {};

  final Duration defaultTtl = const Duration(minutes: 5);
  static const int _firestoreBatchLimit = 30; // Firestore whereIn limit

  /// Look up a single user profile from cache or fetch from Firestore
  Future<UserProfile?> getUser(
    String uid, {
    bool forceRefresh = false,
    Duration? ttl,
  }) async {
    final entry = _userCache[uid];
    if (!forceRefresh && entry != null && !entry.isExpired(ttl ?? defaultTtl)) {
      return entry.data;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;

      final profile = UserProfile.fromFirestore(doc);
      _userCache[uid] = _CachedEntry(profile);
      return profile;
    } catch (e) {
      debugPrint("Error fetching user profile for $uid: $e");
      return entry?.data;
    }
  }

  /// Batch fetches multiple users efficiently using Firestore whereIn queries,
  /// skipping any that are already valid in cache.
  Future<Map<String, UserProfile>> getUsers(
    Iterable<String> uids, {
    bool forceRefresh = false,
    Duration? ttl,
  }) async {
    final Map<String, UserProfile> result = {};
    final List<String> toFetch = [];
    final activeTtl = ttl ?? defaultTtl;

    for (final uid in uids) {
      if (uid.isEmpty) continue;
      final entry = _userCache[uid];
      if (!forceRefresh && entry != null && !entry.isExpired(activeTtl)) {
        result[uid] = entry.data;
      } else {
        toFetch.add(uid);
      }
    }

    if (toFetch.isEmpty) {
      return result;
    }

    // Chunk into batches of up to 30 for Firestore whereIn queries
    for (int i = 0; i < toFetch.length; i += _firestoreBatchLimit) {
      final end = (i + _firestoreBatchLimit < toFetch.length)
          ? i + _firestoreBatchLimit
          : toFetch.length;
      final chunk = toFetch.sublist(i, end);

      try {
        final querySnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in querySnap.docs) {
          final profile = UserProfile.fromFirestore(doc);
          _userCache[doc.id] = _CachedEntry(profile);
          result[doc.id] = profile;
        }
      } catch (e) {
        debugPrint("Error batch fetching users: $e");
      }
    }

    return result;
  }

  /// Batch fetches multiple events efficiently using Firestore whereIn queries.
  Future<Map<String, Event>> getEvents(
    Iterable<String> eventIds, {
    bool forceRefresh = false,
    Duration? ttl,
  }) async {
    final Map<String, Event> result = {};
    final List<String> toFetch = [];
    final activeTtl = ttl ?? defaultTtl;

    for (final eventId in eventIds) {
      if (eventId.isEmpty) continue;
      final entry = _eventCache[eventId];
      if (!forceRefresh && entry != null && !entry.isExpired(activeTtl)) {
        result[eventId] = entry.data;
      } else {
        toFetch.add(eventId);
      }
    }

    if (toFetch.isEmpty) {
      return result;
    }

    for (int i = 0; i < toFetch.length; i += _firestoreBatchLimit) {
      final end = (i + _firestoreBatchLimit < toFetch.length)
          ? i + _firestoreBatchLimit
          : toFetch.length;
      final chunk = toFetch.sublist(i, end);

      try {
        final querySnap = await FirebaseFirestore.instance
            .collection('events')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in querySnap.docs) {
          final event = Event.fromFirestore(doc);
          _eventCache[doc.id] = _CachedEntry(event);
          result[doc.id] = event;
        }
      } catch (e) {
        debugPrint("Error batch fetching events: $e");
      }
    }

    return result;
  }

  /// Manually populate or update a user profile in cache
  void putUser(UserProfile profile) {
    _userCache[profile.uid] = _CachedEntry(profile);
  }

  /// Invalidate cache for a specific user
  void invalidateUser(String uid) {
    _userCache.remove(uid);
  }

  /// Invalidate cache for a specific event
  void invalidateEvent(String eventId) {
    _eventCache.remove(eventId);
  }

  /// Clear all cached data
  void clear() {
    _userCache.clear();
    _eventCache.clear();
  }
}
