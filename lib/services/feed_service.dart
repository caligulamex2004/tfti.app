import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/feed_snapshot.dart';

class FeedService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @visibleForTesting
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  /// Lightweight, pure-Dart combineLatest4 implementation without third-party dependencies.
  static Stream<R> combineLatest4<A, B, C, D, R>(
    Stream<A> streamA,
    Stream<B> streamB,
    Stream<C> streamC,
    Stream<D> streamD,
    R Function(A a, B b, C c, D d) combiner,
  ) {
    late StreamController<R> controller;
    A? valA;
    B? valB;
    C? valC;
    D? valD;
    bool hasA = false;
    bool hasB = false;
    bool hasC = false;
    bool hasD = false;

    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;
    StreamSubscription<C>? subC;
    StreamSubscription<D>? subD;

    void emitIfAllReady() {
      if (hasA && hasB && hasC && hasD && !controller.isClosed) {
        controller.add(combiner(valA as A, valB as B, valC as C, valD as D));
      }
    }

    controller = StreamController<R>.broadcast(
      onListen: () {
        subA = streamA.listen(
          (data) {
            valA = data;
            hasA = true;
            emitIfAllReady();
          },
          onError: controller.addError,
        );
        subB = streamB.listen(
          (data) {
            valB = data;
            hasB = true;
            emitIfAllReady();
          },
          onError: controller.addError,
        );
        subC = streamC.listen(
          (data) {
            valC = data;
            hasC = true;
            emitIfAllReady();
          },
          onError: controller.addError,
        );
        subD = streamD.listen(
          (data) {
            valD = data;
            hasD = true;
            emitIfAllReady();
          },
          onError: controller.addError,
        );
        emitIfAllReady();
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
        subC?.cancel();
        subD?.cancel();
      },
    );

    return controller.stream;
  }

  /// Streams the unified FeedSnapshot for a user
  static Stream<FeedSnapshot> feedStream(String uid) {
    final userStream = _firestore.collection('users').doc(uid).snapshots();
    final friendsStream = _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .where('isGoated', isEqualTo: true)
        .snapshots();
    final invitesStream = _firestore
        .collectionGroup('invitations')
        .where('uid', isEqualTo: uid)
        .snapshots();
    final eventsStream = _firestore
        .collection('events')
        .where('visibleTo', arrayContains: uid)
        .snapshots();

    return combineLatest4(
      userStream,
      friendsStream,
      invitesStream,
      eventsStream,
      (userSnap, friendsSnap, invitesSnap, eventsSnap) {
        // 1. User doc details
        List<String> blockedUids = [];
        String firstName = "there";
        if (userSnap.exists) {
          final userData = userSnap.data();
          if (userData != null) {
            if (userData['blockedUids'] != null) {
              blockedUids = List<String>.from(userData['blockedUids']);
            }
            if (userData['displayName'] != null) {
              final String name = userData['displayName'] as String;
              if (name.trim().isNotEmpty) {
                firstName = name.trim().split(' ')[0];
              }
            }
          }
        }

        // 2. Goated friends
        final List<String> goatedUids =
            friendsSnap.docs.map((doc) => doc.id).toList();

        // 3. Invitations map
        final Map<String, Map<String, dynamic>> myInvitesMap = {};
        for (var doc in invitesSnap.docs) {
          final eventId = doc.reference.parent.parent?.id;
          if (eventId != null) {
            myInvitesMap[eventId] = doc.data();
          }
        }

        // 4. Raw events
        final List<RawFeedEvent> events = eventsSnap.docs.map((doc) {
          return RawFeedEvent(
            id: doc.id,
            data: doc.data(),
          );
        }).toList();

        return FeedSnapshot(
          firstName: firstName,
          blockedUids: blockedUids,
          goatedUids: goatedUids,
          myInvitesMap: myInvitesMap,
          events: events,
        );
      },
    );
  }
}
