import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:tftiapp/models/user_profile.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of the user's domain profile
  static Stream<UserProfile?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  /// Get a snapshot of the user's profile
  static Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  /// Update core user profile fields
  static Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? username,
    String? status,
    int? avatarColor,
    String? phone,
    bool? isPhonePublic,
    bool? isSearchableByPhone,
    bool? autoExportCalendar,
    Map<String, dynamic>? additionalFields,
  }) async {
    final Map<String, dynamic> updates = {};

    if (displayName != null) {
      updates['displayName'] = displayName.trim();
    }
    if (username != null) {
      updates['username'] = username.trim().toLowerCase();
    }
    if (status != null) {
      updates['status'] = status.trim();
    }
    if (avatarColor != null) {
      updates['avatarColor'] = avatarColor;
    }
    if (phone != null) {
      updates['phone'] = phone;
    }
    if (isPhonePublic != null) {
      updates['isPhonePublic'] = isPhonePublic;
      updates['showPhoneNumber'] = isPhonePublic;
    }
    if (isSearchableByPhone != null) {
      updates['isSearchableByPhone'] = isSearchableByPhone;
    } else if (isPhonePublic != null) {
      updates['isSearchableByPhone'] = isPhonePublic;
    }
    if (autoExportCalendar != null) {
      updates['autoExportCalendar'] = autoExportCalendar;
    }
    if (additionalFields != null) {
      updates.addAll(additionalFields);
    }

    if (updates.isEmpty) return;

    updates['lastUpdatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('users').doc(uid).update(updates);

    if (displayName != null && _auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(displayName.trim());
    }
  }

  /// Compresses and uploads an avatar image to Storage and saves url to user doc
  static Future<String> uploadAvatar({
    required String uid,
    required File imageFile,
  }) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    final Uint8List compressedBytes =
        await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 512,
          minHeight: 512,
          quality: 75,
        );

    final Reference ref = _storage.ref().child('profile_images/$uid/avatar.jpg');

    final UploadTask uploadTask = ref.putData(
      compressedBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    await _firestore.collection('users').doc(uid).update({
      'avatarUrl': downloadUrl,
    });

    if (_auth.currentUser != null && _auth.currentUser!.uid == uid) {
      await _auth.currentUser!.updatePhotoURL(downloadUrl);
    }

    return downloadUrl;
  }

  /// Removes avatar from storage and deletes field from user document
  static Future<void> deleteAvatar({required String uid}) async {
    try {
      final Reference ref = _storage.ref().child('profile_images/$uid/avatar.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint("Storage avatar file might not exist: $e");
    }

    await _firestore.collection('users').doc(uid).update({
      'avatarUrl': FieldValue.delete(),
    });

    if (_auth.currentUser != null && _auth.currentUser!.uid == uid) {
      await _auth.currentUser!.updatePhotoURL(null);
    }
  }

  /// Checks if a lowercase username is available for registration
  static Future<bool> isUsernameAvailable(
    String username, {
    String? currentUid,
  }) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return false;

    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: clean)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return true;
    if (currentUid != null && query.docs.first.id == currentUid) return true;
    return false;
  }

  /// Registers an FCM token for push notifications
  static Future<void> saveFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Unregisters an FCM token (e.g. on logout)
  static Future<void> removeFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  /// Permanently deletes user data across storage, subcollections, invitations, and Auth
  static Future<void> deleteAccount(User user) async {
    // 1. Delete avatar from Storage
    try {
      final Reference ref = _storage.ref().child('profile_images/${user.uid}/avatar.jpg');
      await ref.delete();
    } catch (_) {}

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();
    final String? usernameToFree = userDoc.data()?['username'];

    // 2. Clear subcollections (Friends, Circles, Places)
    try {
      final friendsSnap = await userDocRef.collection('friends').get();
      for (var doc in friendsSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    try {
      final circlesSnap = await userDocRef.collection('circles').get();
      for (var doc in circlesSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    try {
      final placesSnap = await userDocRef.collection('favorite_places').get();
      for (var doc in placesSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    // 3. Free up username
    try {
      if (usernameToFree != null && usernameToFree.isNotEmpty) {
        await _firestore.collection('usernames').doc(usernameToFree).delete();
      }
    } catch (_) {}

    // 4. Delete global invites and collect event IDs
    List<String> userEventIds = [];
    try {
      final invitesSnap = await _firestore
          .collectionGroup('invitations')
          .where('uid', isEqualTo: user.uid)
          .get();

      for (var doc in invitesSnap.docs) {
        final parentEventId = doc.reference.parent.parent?.id;
        if (parentEventId != null && !userEventIds.contains(parentEventId)) {
          userEventIds.add(parentEventId);
        }
        await doc.reference.delete();
      }
    } catch (_) {}

    // 5. Collect hosted events
    try {
      final hostedEventsSnap = await _firestore
          .collection('events')
          .where('hostId', isEqualTo: user.uid)
          .get();
      for (var doc in hostedEventsSnap.docs) {
        if (!userEventIds.contains(doc.id)) userEventIds.add(doc.id);
      }
    } catch (_) {}

    // 6. Release squad needs roles
    try {
      for (String eventId in userEventIds) {
        final rolesSnap = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('roles')
            .where('claimedByUid', isEqualTo: user.uid)
            .get();

        for (var doc in rolesSnap.docs) {
          await doc.reference.update({
            'claimedByUid': FieldValue.delete(),
            'claimedByName': FieldValue.delete(),
          });
        }
      }
    } catch (_) {}

    // 7. Remove from global friends
    try {
      final friendsGlobalSnap = await _firestore
          .collectionGroup('friends')
          .where('uid', isEqualTo: user.uid)
          .get();
      for (var doc in friendsGlobalSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    // 8. Delete user doc
    await userDocRef.delete();

    // 9. Delete Firebase Auth user
    await user.delete();
  }

  /// Toggle blocked status of a target user
  static Future<void> toggleBlockUser({
    required String myUid,
    required String targetUid,
    required bool isBlocked,
  }) async {
    final userRef = _firestore.collection('users').doc(myUid);
    if (isBlocked) {
      await userRef.update({
        'blockedUids': FieldValue.arrayUnion([targetUid]),
      });
    } else {
      await userRef.update({
        'blockedUids': FieldValue.arrayRemove([targetUid]),
      });
    }
  }
}
