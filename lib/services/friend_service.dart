import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tftiapp/models/friend_model.dart';
import 'package:tftiapp/models/squad_request_model.dart';
import 'package:tftiapp/utils/event_service.dart';

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of all friends for a given user
  static Stream<List<Friend>> friendsStream(String myUid) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Friend.fromFirestore(doc)).toList());
  }

  /// Check if user has at least one friend
  static Future<bool> hasFriends(String myUid) async {
    final snap = await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Get set of all friend UIDs for a given user
  static Future<Set<String>> getFriendUids(String myUid) async {
    final snap = await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .get(const GetOptions(source: Source.server));
    return snap.docs.map((doc) => doc.id).toSet();
  }

  /// Add a friend by target UID
  static Future<void> addFriend({
    required String myUid,
    required String friendUid,
    String? phoneNumber,
    bool isGoated = false,
  }) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid)
        .set({
      'uid': friendUid,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phoneNumber': phoneNumber,
      'isGoated': isGoated,
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await EventService.syncActiveEventsForUser(myUid);
  }

  /// Remove a friend from the squad
  static Future<void> removeFriend({
    required String myUid,
    required String friendUid,
  }) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid)
        .delete();

    await EventService.syncActiveEventsForUser(myUid);
  }

  /// Toggle goated / favorite status of a friend
  static Future<void> toggleGoated({
    required String myUid,
    required String friendUid,
    required bool isGoated,
  }) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid)
        .set({
      'isGoated': isGoated,
    }, SetOptions(merge: true));
  }

  /// Toggle blocked status of a friend
  static Future<void> toggleBlocked({
    required String myUid,
    required String friendUid,
    required bool isBlocked,
  }) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid)
        .set({
      'isBlocked': isBlocked,
    }, SetOptions(merge: true));
  }

  /// Update the circles/teams a friend belongs to
  static Future<void> updateFriendCircles({
    required String myUid,
    required String friendUid,
    required List<String> circleIds,
  }) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid)
        .set({
      'circles': circleIds,
    }, SetOptions(merge: true));

    await EventService.syncActiveEventsForUser(myUid);
  }

  /// Find user UID by unique username
  static Future<String?> findUidByUsername(String username) async {
    final clean = username.trim().toLowerCase().replaceAll(RegExp(r'^@'), '');
    if (clean.isEmpty) return null;

    final doc = await _firestore.collection('usernames').doc(clean).get();
    if (doc.exists) {
      return doc.data()?['uid'] as String?;
    }

    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: clean)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }

    return null;
  }

  /// Find user UID by phone number. Respects user privacy settings:
  /// returns null if the user has opted out of phone searchability (isSearchableByPhone == false).
  static Future<String?> findUidByPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) return null;

    final query = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final data = doc.data();
      final bool isSearchable = data['isSearchableByPhone'] != false;
      if (!isSearchable) {
        return null;
      }
      return doc.id;
    }

    return null;
  }

  /// Stream of active incoming squad requests for a user (filtering out requests older than 14 days)
  static Stream<List<SquadRequest>> incomingRequestsStream(String myUid) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('squad_requests')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SquadRequest.fromFirestore(doc))
          .where((req) => !req.isExpired())
          .toList();
    });
  }

  /// Check if there is an active (non-expired) squad request from [fromUid] to [toUid]
  static Future<bool> hasPendingRequest({
    required String fromUid,
    required String toUid,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(toUid)
        .collection('squad_requests')
        .doc(fromUid)
        .get();

    if (!doc.exists) return false;
    final req = SquadRequest.fromFirestore(doc);
    return !req.isExpired();
  }

  /// Send a squad request from [fromUid] to [toUid].
  /// Silently drops if target has blocked requester.
  /// Writes both createdAt and addedAt for backwards compatibility.
  static Future<void> sendSquadRequest({
    required String fromUid,
    required String toUid,
    required String source,
  }) async {
    if (fromUid == toUid) return;

    // Check if target user has blocked requester
    final targetDoc = await _firestore.collection('users').doc(toUid).get();
    if (targetDoc.exists) {
      final blocked = List<String>.from(targetDoc.data()?['blockedUids'] ?? []);
      if (blocked.contains(fromUid)) {
        return;
      }
    }

    // Fetch requester profile details
    final fromDoc = await _firestore.collection('users').doc(fromUid).get();
    final fromData = fromDoc.data() ?? {};

    await _firestore
        .collection('users')
        .doc(toUid)
        .collection('squad_requests')
        .doc(fromUid)
        .set({
      'fromUid': fromUid,
      'toUid': toUid,
      'displayName': fromData['displayName'] ?? '',
      'username': fromData['username'] ?? '',
      'avatarUrl': fromData['avatarUrl'],
      'avatarColor': fromData['avatarColor'],
      'status': 'pending',
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Accept incoming squad request: adds friends symmetrically and removes request
  static Future<void> acceptSquadRequest({
    required String myUid,
    required String requesterUid,
  }) async {
    final myDoc = await _firestore.collection('users').doc(myUid).get();
    final requesterDoc = await _firestore.collection('users').doc(requesterUid).get();

    final myPhone = myDoc.data()?['phoneNumber'] ?? '';
    final reqPhone = requesterDoc.data()?['phoneNumber'] ?? '';

    // Add friends symmetrically
    await addFriend(
      myUid: myUid,
      friendUid: requesterUid,
      phoneNumber: reqPhone,
    );
    await addFriend(
      myUid: requesterUid,
      friendUid: myUid,
      phoneNumber: myPhone,
    );

    // Delete the request
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('squad_requests')
        .doc(requesterUid)
        .delete();
  }

  /// Pass / dismiss incoming squad request: removes request silently
  static Future<void> passSquadRequest({
    required String myUid,
    required String requesterUid,
  }) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('squad_requests')
        .doc(requesterUid)
        .delete();
  }

  /// Block requester: removes request and adds requester to user's blockedUids
  static Future<void> blockSquadRequest({
    required String myUid,
    required String requesterUid,
  }) async {
    // Delete the request
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('squad_requests')
        .doc(requesterUid)
        .delete();

    // Add requester to blockedUids
    await _firestore.collection('users').doc(myUid).set({
      'blockedUids': FieldValue.arrayUnion([requesterUid]),
    }, SetOptions(merge: true));
  }
}
