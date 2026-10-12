import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tftiapp/models/friend_model.dart';

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

  /// Find user UID by phone number
  static Future<String?> findUidByPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) return null;

    final query = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }

    return null;
  }
}
