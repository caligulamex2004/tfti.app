import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tftiapp/models/team_model.dart';
import 'package:tftiapp/utils/event_service.dart';

class TeamService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of all teams/circles created by the user
  static Stream<List<TeamCircle>> teamsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('circles')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamCircle.fromFirestore(doc))
            .toList());
  }

  /// Create a new team circle
  static Future<String> createTeam({
    required String uid,
    required String name,
  }) async {
    final cleanName = name.trim();
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('circles')
        .doc();

    await docRef.set({
      'name': cleanName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Rename an existing team circle
  static Future<void> renameTeam({
    required String uid,
    required String circleId,
    required String newName,
  }) async {
    final cleanName = newName.trim();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('circles')
        .doc(circleId)
        .update({'name': cleanName});
  }

  /// Delete a team circle and remove it from all friends who were assigned to it
  static Future<void> deleteTeam({
    required String uid,
    required String circleId,
  }) async {
    final batch = _firestore.batch();

    // 1. Delete the circle doc
    final circleRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('circles')
        .doc(circleId);
    batch.delete(circleRef);

    // 2. Query friends that belong to this circle
    final friendsQuery = await _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .where('circles', arrayContains: circleId)
        .get();

    for (var doc in friendsQuery.docs) {
      batch.update(doc.reference, {
        'circles': FieldValue.arrayRemove([circleId]),
      });
    }

    await batch.commit();
  }

  /// Add members to a team circle
  static Future<void> addMembersToTeam({
    required String uid,
    required String circleId,
    required List<String> memberUids,
  }) async {
    if (memberUids.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (String friendUid in memberUids) {
      final friendRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .doc(friendUid);

      batch.set(friendRef, {
        'circles': FieldValue.arrayUnion([circleId]),
      }, SetOptions(merge: true));

      count++;
      if (count > 450) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  /// Remove a member from a team circle
  static Future<void> removeMemberFromTeam({
    required String uid,
    required String circleId,
    required String friendUid,
  }) async {
    final friendRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(friendUid);

    await friendRef.update({
      'circles': FieldValue.arrayRemove([circleId]),
    });

    // Also sync any events where this user is host or co-host and this circle is invited
    try {
      final hostedEvents = await _firestore
          .collection('events')
          .where('hostId', isEqualTo: uid)
          .get();

      for (var doc in hostedEvents.docs) {
        final data = doc.data();
        final bool inviteAll = data['inviteAll'] ?? true;
        final circles = List<String>.from(data['invitedCircles'] ?? []);
        if (!inviteAll && circles.contains(circleId)) {
          await EventService.syncEventInvitesWithTeams(doc.id);
        }
      }

      final coHostedEvents = await _firestore
          .collection('events')
          .where('coHostId', isEqualTo: uid)
          .get();

      for (var doc in coHostedEvents.docs) {
        final data = doc.data();
        final bool coHostInviteAll = data['coHostInviteAll'] ?? false;
        final coHostCircles =
            List<String>.from(data['coHostInvitedCircles'] ?? []);
        if (!coHostInviteAll && coHostCircles.contains(circleId)) {
          await EventService.syncEventInvitesWithTeams(doc.id);
        }
      }
    } catch (_) {
      // Non-blocking background sync
    }
  }
}
