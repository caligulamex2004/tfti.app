import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:tftiapp/components/dialogs/season_dialogs.dart';
import 'package:tftiapp/models/hangout_submission_request.dart';
import 'package:tftiapp/models/vibe_check_submission_request.dart';

class EventService {
  // ---------------------------------------------------------------------------
  // Submit / Create / Update a Vibe Check
  // ---------------------------------------------------------------------------

  static Future<void> submitVibeCheck({
    required VibeCheckSubmissionRequest request,
    ValueChanged<bool>? onLoadingChanged,
    VoidCallback? onSuccess,
    ValueChanged<String>? onError,
  }) async {
    onLoadingChanged?.call(true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onLoadingChanged?.call(false);
      return;
    }

    try {
      final newDateTime = request.combinedDateTime;
      final batch = FirebaseFirestore.instance.batch();

      if (request.isEditing) {
        // --- EDIT MODE ---
        final int keepAliveDays = request.eventData?['keepAliveDays'] ?? 0;
        final int durationMinutes =
            keepAliveDays > 0 ? (keepAliveDays * 24 * 60) : 240;
        final newEndTime = newDateTime.add(Duration(minutes: durationMinutes));

        List<String> changedFields = [];
        List<String> oldValues = [];
        List<String> newValues = [];

        String formatDateTime(DateTime dt) {
          final months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          final hour =
              dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
          final min = dt.minute.toString().padLeft(2, '0');
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          return '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
        }

        String formatOptions(List<dynamic> opts) {
          return opts
              .map((opt) {
                if (opt is! Map) return '';
                final title = opt['title'] ?? 'Option';
                final loc = opt['location'];
                if (loc != null &&
                    loc.toString().trim().isNotEmpty &&
                    loc != 'TBD') {
                  return '$title ($loc)';
                }
                return title.toString();
              })
              .join(", ");
        }

        final oldTimeTs = request.eventData?['time'] as Timestamp?;
        if (oldTimeTs != null) {
          final oldDt = oldTimeTs.toDate();
          if (oldDt.year != newDateTime.year ||
              oldDt.month != newDateTime.month ||
              oldDt.day != newDateTime.day ||
              oldDt.hour != newDateTime.hour ||
              oldDt.minute != newDateTime.minute) {
            changedFields.add("Time");
            oldValues.add(formatDateTime(oldDt));
            newValues.add(formatDateTime(newDateTime));
          }
        }

        final oldOptions =
            request.eventData?['pollOptions'] as List<dynamic>? ?? [];
        bool optionsChanged = false;

        if (oldOptions.length != request.pollOptions.length) {
          optionsChanged = true;
        } else {
          for (int i = 0; i < oldOptions.length; i++) {
            final oldTitle = oldOptions[i]['title'] ?? '';
            final newTitle = request.pollOptions[i]['title'] ?? '';
            final oldLoc = oldOptions[i]['location'] ?? 'TBD';
            final newLoc = request.pollOptions[i]['location'] ?? 'TBD';

            if (oldTitle != newTitle || oldLoc != newLoc) {
              optionsChanged = true;
              break;
            }
          }
        }

        if (optionsChanged) {
          changedFields.add("Options");
          oldValues.add(formatOptions(oldOptions));
          newValues.add(formatOptions(request.pollOptions));
        }

        final Map<String, dynamic> updateData = {
          'title': request.title,
          'details': request.details,
          'time': Timestamp.fromDate(newDateTime),
          'endTime': Timestamp.fromDate(newEndTime),
          'pollOptions': request.pollOptions,
          'rsvpDeadline': request.rsvpDeadlineOffset,
          'inviteAll': request.inviteAll,
          'invitedCircles': request.selectedCircleIds,
          'coHostId': request.coHostId,
          'coHostName': request.coHostName,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };

        if (changedFields.isNotEmpty) {
          updateData['latestCriticalChange'] = {
            'field': changedFields.join(" & "),
            'original': oldValues.join(" | "),
            'new': newValues.join(" | "),
            'timestamp': FieldValue.serverTimestamp(),
          };
        }

        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();
        Set<String> newIntendedIds = {};
        Set<String> oldIntendedIds = {};

        final bool oldInviteAll = request.eventData?['inviteAll'] ?? true;
        final List<String> oldCircles = List<String>.from(
          request.eventData?['invitedCircles'] ?? [],
        );

        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data();
          final friendCircles = List<String>.from(data['circles'] ?? []);
          if (request.inviteAll ||
              request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
            newIntendedIds.add(friendDoc.id);
          }
          if (oldInviteAll ||
              oldCircles.any((id) => friendCircles.contains(id))) {
            oldIntendedIds.add(friendDoc.id);
          }
        }

        final currentInvitesSnap = await FirebaseFirestore.instance
            .collection('events')
            .doc(request.eventId!)
            .collection('invitations')
            .get();
        final Set<String> currentlyInvitedIds =
            currentInvitesSnap.docs.map((d) => d.id).toSet();

        Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
        Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);
        toRemove.remove(request.eventData?['hostId']);

        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(request.eventId!);

        if (toAdd.isNotEmpty) {
          updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
          for (String uid in toAdd) {
            if (!currentlyInvitedIds.contains(uid)) {
              batch.set(eventRef.collection('invitations').doc(uid), {
                'uid': uid,
                'role': 'guest',
                'status': 'pending',
                'votes': [],
                'sentAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        if (toRemove.isNotEmpty) {
          updateData['visibleTo'] = FieldValue.arrayRemove(toRemove.toList());
          for (String uid in toRemove) {
            batch.delete(eventRef.collection('invitations').doc(uid));
          }
        }

        batch.update(eventRef, updateData);
        batch.set(
          eventRef.collection('invitations').doc(user.uid),
          {'lastViewedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      } else {
        // --- CREATE MODE ---
        final defaultEndTime = newDateTime.add(const Duration(hours: 4));
        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();

        Set<String> visibleToIds = {user.uid};
        Set<DocumentSnapshot> friendsToInvite = {};

        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data();
          final friendCircles = List<String>.from(data['circles'] ?? []);
          if (request.inviteAll ||
              request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
            friendsToInvite.add(friendDoc);
            visibleToIds.add(friendDoc.id);
          }
        }

        if (friendsToInvite.isEmpty && !request.inviteAll) {
          onError?.call("No friends found in selected teams!");
          onLoadingChanged?.call(false);
          return;
        }

        final eventRef =
            FirebaseFirestore.instance.collection('events').doc();
        batch.set(eventRef, {
          'type': 'vibe_check',
          'pollOptions': request.pollOptions,
          'lockedOptionId': null,
          'isTieBreakerNeeded': false,
          'hostId': user.uid,
          'coHostId': request.coHostId,
          'coHostName': request.coHostName,
          'title': request.title,
          'details': request.details,
          'time': Timestamp.fromDate(newDateTime),
          'endTime': Timestamp.fromDate(defaultEndTime),
          'keepAliveDays': 0,
          'pointsAwarded': false,
          'created_at': FieldValue.serverTimestamp(),
          'visibleTo': visibleToIds.toList(),
          'inviteAll': request.inviteAll,
          'invitedCircles': request.selectedCircleIds,
          'rsvpDeadline': request.rsvpDeadlineOffset,
        });

        for (var friendDoc in friendsToInvite) {
          batch.set(eventRef.collection('invitations').doc(friendDoc.id), {
            'uid': friendDoc.id,
            'role': 'guest',
            'status': 'pending',
            'votes': [],
            'sentAt': FieldValue.serverTimestamp(),
          });
        }

        batch.set(eventRef.collection('invitations').doc(user.uid), {
          'uid': user.uid,
          'role': 'host',
          'status': 'going',
          'votes': ['placeholder'],
          'sentAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      onSuccess?.call();
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Convert a Vibe Check to a Finalized Hangout
  // ---------------------------------------------------------------------------

  static Future<void> convertVibeCheck({
    required String eventId,
    required Map<String, dynamic> option,
    ValueChanged<bool>? onLoadingChanged,
    VoidCallback? onSuccess,
    ValueChanged<String>? onError,
  }) async {
    onLoadingChanged?.call(true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final eventRef =
          FirebaseFirestore.instance.collection('events').doc(eventId);

      batch.update(eventRef, {
        'type': 'event',
        'lockedOptionId': option['id'],
        'title': option['title'],
        'location': option['location'],
        'isTieBreakerNeeded': false,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      final invitesSnap = await eventRef.collection('invitations').get();
      for (var doc in invitesSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'declined') continue;

        final votes = List<String>.from(data['votes'] ?? []);
        String newStatus =
            votes.contains(option['id']) ? 'going' : 'pending';

        if (data['role'] == 'host' || data['role'] == 'co-host') {
          newStatus = 'going';
        }
        batch.update(doc.reference, {'status': newStatus});
      }

      await batch.commit();
      onSuccess?.call();
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Submit / Create / Update a Hangout (Pure Backend Service Method)
  // ---------------------------------------------------------------------------

  static Future<void> submitHangout({
    required HangoutSubmissionRequest request,
    ValueChanged<bool>? onLoadingChanged,
    VoidCallback? onSuccess,
    ValueChanged<String>? onError,
  }) async {
    onLoadingChanged?.call(true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onLoadingChanged?.call(false);
      return;
    }

    try {
      final newDateTime = request.combinedDateTime;
      final newEndTime = request.calculatedEndTime;
      final String updateScope = request.updateScope.value;
      final String? seasonId = request.eventData?['seasonId'];

      // -----------------------------------------------------------------------
      // EDIT PATH
      // -----------------------------------------------------------------------
      if (request.isEditing) {
        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(request.eventId);
        final batch = FirebaseFirestore.instance.batch();

        final Map<String, dynamic> updateData = {
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };

        // --- Critical change detector (host & co-host) ---
        List<String> changedFields = [];
        List<String> oldValues = [];
        List<String> newValues = [];

        String formatDateTime(DateTime dt) {
          final months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          final hour = dt.hour > 12
              ? dt.hour - 12
              : (dt.hour == 0 ? 12 : dt.hour);
          final min = dt.minute.toString().padLeft(2, '0');
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          return '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
        }

        final oldTimeTs = request.eventData?['time'] as Timestamp?;
        if (oldTimeTs != null) {
          final oldDt = oldTimeTs.toDate();
          if (oldDt.year != newDateTime.year ||
              oldDt.month != newDateTime.month ||
              oldDt.day != newDateTime.day ||
              oldDt.hour != newDateTime.hour ||
              oldDt.minute != newDateTime.minute) {
            changedFields.add("Time");
            oldValues.add(formatDateTime(oldDt));
            newValues.add(formatDateTime(newDateTime));
          }
        }

        final oldLoc = (request.eventData?['location'] ?? '').toString().trim();
        if (oldLoc != request.location) {
          changedFields.add("Location");
          oldValues.add(oldLoc.isEmpty ? "TBD" : oldLoc);
          newValues.add(request.location.isEmpty ? "TBD" : request.location);
        }

        if (changedFields.isNotEmpty) {
          updateData['latestCriticalChange'] = {
            'field': changedFields.join(" & "),
            'original': oldValues.join(" | "),
            'new': newValues.join(" | "),
            'timestamp': FieldValue.serverTimestamp(),
          };
        }

        // --- Standard updates (host & co-host) ---
        updateData['title'] = request.title;
        updateData['location'] = request.location;
        updateData['details'] = request.details;
        updateData['time'] = Timestamp.fromDate(newDateTime);
        updateData['endTime'] = Timestamp.fromDate(newEndTime);
        updateData['isImportantDetails'] = request.isImportantDetails;
        updateData['rsvpDeadline'] = request.rsvpDeadlineOffset;
        updateData['keepAliveDays'] = request.keepAliveDays;

        if (request.removeBanner) {
          updateData['bannerUrl'] = FieldValue.delete();
          try {
            await FirebaseStorage.instance
                .ref()
                .child('event_banners/${request.eventId}/banner.jpg')
                .delete();
          } catch (_) {}
        } else if (request.bannerImageBytes != null || request.bannerImagePath != null) {
          try {
            Uint8List? bytes = request.bannerImageBytes;
            if (bytes == null && request.bannerImagePath != null && !kIsWeb) {
              final File file = File(request.bannerImagePath!);
              bytes = await file.readAsBytes();
            }
            if (bytes != null) {
              Uint8List compressedBytes = bytes;
              try {
                compressedBytes = await FlutterImageCompress.compressWithList(
                  bytes,
                  minWidth: 1280,
                  minHeight: 720,
                  quality: 75,
                );
              } catch (compErr) {
                debugPrint("Banner compression error (using raw bytes): $compErr");
              }
              final ref = FirebaseStorage.instance.ref().child(
                'event_banners/${request.eventId}/banner.jpg',
              );
              await ref.putData(
                compressedBytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              updateData['bannerUrl'] = await ref.getDownloadURL();
            }
          } catch (e) {
            debugPrint("Failed to upload new banner: $e");
          }
        }

        // --- Invitation roster management ---
        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();

        final currentInvitesSnap = await eventRef.collection('invitations').get();
        final Set<String> currentlyInvitedIds = currentInvitesSnap.docs
            .map((d) => d.id)
            .toSet();

        if (request.isMainHost) {
          // Host: full roster control (add + remove) & co-captain assignment
          updateData['inviteAll'] = request.inviteAll;
          updateData['invitedCircles'] = request.selectedCircleIds;
          updateData['coHostId'] = request.coHostId;
          updateData['coHostName'] = request.coHostName;

          Set<String> newIntendedIds = {};
          Set<String> oldIntendedIds = {};
          final bool oldInviteAll = request.eventData?['inviteAll'] ?? true;
          final List<String> oldCircles = List<String>.from(
            request.eventData?['invitedCircles'] ?? [],
          );

          for (var friendDoc in friendsSnapshot.docs) {
            final friendCircles = List<String>.from(
              friendDoc.data()['circles'] ?? [],
            );
            if (request.inviteAll ||
                request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
              newIntendedIds.add(friendDoc.id);
            }
            if (oldInviteAll ||
                oldCircles.any((id) => friendCircles.contains(id))) {
              oldIntendedIds.add(friendDoc.id);
            }
          }

          Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
          Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);
          toRemove.remove(request.eventData?['hostId']);

          if (toAdd.isNotEmpty) {
            updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
            for (String uid in toAdd) {
              if (!currentlyInvitedIds.contains(uid)) {
                batch.set(eventRef.collection('invitations').doc(uid), {
                  'uid': uid,
                  'role': 'guest',
                  'status': 'pending',
                  'invitedBy': user.uid,
                  'sentAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
          if (toRemove.isNotEmpty) {
            updateData['visibleTo'] = FieldValue.arrayRemove(toRemove.toList());
            for (String uid in toRemove) {
              batch.delete(eventRef.collection('invitations').doc(uid));
            }
          }
        } else {
          // Co-host: full diff on their own scope (add + remove)
          updateData['coHostInviteAll'] = request.inviteAll;
          updateData['coHostInvitedCircles'] = request.selectedCircleIds;

          final bool oldCoHostInviteAll =
              request.eventData?['coHostInviteAll'] ?? false;
          final List<String> oldCoHostCircles = List<String>.from(
            request.eventData?['coHostInvitedCircles'] ?? [],
          );

          Set<String> oldCoHostFriendIds = {};
          Set<String> newCoHostFriendIds = {};

          for (var friendDoc in friendsSnapshot.docs) {
            final friendCircles = List<String>.from(
              friendDoc.data()['circles'] ?? [],
            );
            if (oldCoHostInviteAll ||
                oldCoHostCircles.any((id) => friendCircles.contains(id))) {
              oldCoHostFriendIds.add(friendDoc.id);
            }
            if (request.inviteAll ||
                request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
              newCoHostFriendIds.add(friendDoc.id);
            }
          }

          // Add new guests
          Set<String> toAdd = newCoHostFriendIds.difference(currentlyInvitedIds);
          if (toAdd.isNotEmpty) {
            updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
            for (String uid in toAdd) {
              batch.set(eventRef.collection('invitations').doc(uid), {
                'uid': uid,
                'role': 'guest',
                'status': 'pending',
                'invitedBy': user.uid,
                'sentAt': FieldValue.serverTimestamp(),
              });
            }
          }

          // Remove guests the co-host previously added
          Set<String> potentialRemoves = oldCoHostFriendIds.difference(
            newCoHostFriendIds,
          );
          potentialRemoves.remove(request.eventData?['hostId']);
          potentialRemoves.remove(user.uid);

          if (potentialRemoves.isNotEmpty) {
            for (String uid in potentialRemoves) {
              final inviteDoc = currentInvitesSnap.docs
                  .where((d) => d.id == uid)
                  .firstOrNull;
              if (inviteDoc == null) continue;
              final inviteData = inviteDoc.data();
              if (inviteData['invitedBy'] != user.uid) continue;
              batch.delete(eventRef.collection('invitations').doc(uid));
            }
            final confirmedRemoves = potentialRemoves.where((uid) {
              final doc = currentInvitesSnap.docs
                  .where((d) => d.id == uid)
                  .firstOrNull;
              if (doc == null) return false;
              return doc.data()['invitedBy'] == user.uid;
            }).toList();
            if (confirmedRemoves.isNotEmpty) {
              updateData['visibleTo'] = FieldValue.arrayRemove(confirmedRemoves);
            }
          }
        }

        // --- Scoped batch commit ---
        if (updateScope == 'single') {
          batch.update(eventRef, updateData);
          await batch.commit();
        } else if (updateScope == 'future' && seasonId != null) {
          final currentEventTime = request.eventData!['time'] as Timestamp;
          final futureEvents = await FirebaseFirestore.instance
              .collection('events')
              .where('seasonId', isEqualTo: seasonId)
              .where('time', isGreaterThanOrEqualTo: currentEventTime)
              .get();

          final seasonFields = {
            'title': request.title,
            'location': request.location,
            'details': request.details,
            if (request.isMainHost) ...{
              'inviteAll': request.inviteAll,
              'invitedCircles': request.selectedCircleIds,
              'coHostId': request.coHostId,
              'coHostName': request.coHostName,
            } else ...{
              'coHostInviteAll': request.inviteAll,
              'coHostInvitedCircles': request.selectedCircleIds,
            },
            if (updateData.containsKey('bannerUrl'))
              'bannerUrl': updateData['bannerUrl'],
            'isImportantDetails': request.isImportantDetails,
            'rsvpDeadline': request.rsvpDeadlineOffset,
            'keepAliveDays': request.keepAliveDays,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          };

          for (var doc in futureEvents.docs) {
            final docTime = (doc.data()['time'] as Timestamp).toDate();
            final updatedInstanceTime = DateTime(
              docTime.year,
              docTime.month,
              docTime.day,
              newDateTime.hour,
              newDateTime.minute,
            );
            final int durMins = request.keepAliveDays > 0
                ? (request.keepAliveDays * 24 * 60)
                : 240;
            final updatedEndTime = updatedInstanceTime.add(
              Duration(minutes: durMins),
            );

            batch.update(doc.reference, {
              ...seasonFields,
              'time': Timestamp.fromDate(updatedInstanceTime),
              'endTime': Timestamp.fromDate(updatedEndTime),
            });
          }
          await batch.commit();

          await FirebaseFirestore.instance
              .collection('seasons')
              .doc(seasonId)
              .update({
                'title': request.title,
                'location': request.location,
                'details': request.details,
                if (request.isMainHost) ...{
                  'coHostId': request.coHostId,
                },
                if (updateData.containsKey('bannerUrl'))
                  'bannerUrl': updateData['bannerUrl'],
              });
        } else if (updateScope == 'toggle_off' && seasonId != null) {
          batch.update(eventRef, {
            ...updateData,
            'seasonId': FieldValue.delete(),
            'seasonInstance': FieldValue.delete(),
            'seasonTotal': FieldValue.delete(),
          });
          await batch.commit();

          final currentEventTime = request.eventData!['time'] as Timestamp;
          final futureEvents = await FirebaseFirestore.instance
              .collection('events')
              .where('seasonId', isEqualTo: seasonId)
              .where('time', isGreaterThan: currentEventTime)
              .get();

          int opCount = 0;
          for (var fDoc in futureEvents.docs) {
            final fRef = fDoc.reference;
            final invs = await fRef.collection('invitations').get();
            for (var inv in invs.docs) {
              batch.delete(inv.reference);
              opCount++;
            }
            final msgs = await fRef.collection('messages').get();
            for (var m in msgs.docs) {
              batch.delete(m.reference);
              opCount++;
            }
            final rls = await fRef.collection('roles').get();
            for (var r in rls.docs) {
              batch.delete(r.reference);
              opCount++;
            }
            batch.delete(fRef);
            opCount++;
            if (opCount > 400) {
              await batch.commit();
              opCount = 0;
            }
          }
          if (opCount > 0) await batch.commit();

          await FirebaseFirestore.instance
              .collection('seasons')
              .doc(seasonId)
              .delete();
        }
      } else {
        // ---------------------------------------------------------------------
        // CREATE PATH
        // ---------------------------------------------------------------------
        final List<DateTime> eventDates = request.generateSeasonDates != null
            ? request.generateSeasonDates!(newDateTime)
            : [newDateTime];

        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();

        Set<String> visibleToIds = {user.uid};
        Set<DocumentSnapshot> friendsToInvite = {};

        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data() as Map<String, dynamic>? ?? {};
          final friendCircles = List<String>.from(data['circles'] ?? []);
          if (request.inviteAll ||
              request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
            friendsToInvite.add(friendDoc);
            visibleToIds.add(friendDoc.id);
          }
        }

        if (friendsToInvite.isEmpty && !request.inviteAll) {
          onError?.call("No friends found in selected teams!");
          onLoadingChanged?.call(false);
          return;
        }

        // Dynamic batch engine
        WriteBatch batch = FirebaseFirestore.instance.batch();
        int operationCount = 0;

        Future<void> commitBatchIfNeeded() async {
          if (operationCount > 450) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            operationCount = 0;
          }
        }

        // Create the Season parent (only if recurring)
        String? newSeasonId;
        DocumentReference? seasonRef;

        if (request.isRecurring && eventDates.length > 1) {
          seasonRef = FirebaseFirestore.instance.collection('seasons').doc();
          newSeasonId = seasonRef.id;

          batch.set(seasonRef, {
            'hostId': user.uid,
            'coHostId': request.coHostId,
            'title': request.title,
            'location': request.location,
            'details': request.details,
            'frequency': request.recurringFrequency,
            'totalInstances': eventDates.length,
            'createdAt': FieldValue.serverTimestamp(),
          });
          operationCount++;
        }

        List<DocumentReference> createdEventRefs = [];

        for (int i = 0; i < eventDates.length; i++) {
          final date = eventDates[i];
          final eventRef = FirebaseFirestore.instance.collection('events').doc();
          createdEventRefs.add(eventRef);

          final int durMins = request.keepAliveDays > 0
              ? (request.keepAliveDays * 24 * 60)
              : 240;
          final DateTime endTime = date.add(Duration(minutes: durMins));

          batch.set(eventRef, {
            'hostId': user.uid,
            'coHostId': request.coHostId,
            'coHostName': request.coHostName,
            'title': request.title,
            'location': request.location,
            'details': request.details,
            'time': Timestamp.fromDate(date),
            'endTime': Timestamp.fromDate(endTime),
            'isPast': false,
            'created_at': FieldValue.serverTimestamp(),
            'visibleTo': visibleToIds.toList(),
            'inviteAll': request.inviteAll,
            'invitedCircles': request.selectedCircleIds,
            'isImportantDetails': request.isImportantDetails,
            'rsvpDeadline': request.rsvpDeadlineOffset,
            'keepAliveDays': request.keepAliveDays,
            'pointsAwarded': false,
            'seasonId': newSeasonId,
            'seasonInstance': newSeasonId != null ? (i + 1) : null,
            'seasonTotal': newSeasonId != null ? eventDates.length : null,
          });
          operationCount++;
          await commitBatchIfNeeded();

          for (var friendDoc in friendsToInvite) {
            final isCoHostFriend = friendDoc.id == request.coHostId;
            batch.set(eventRef.collection('invitations').doc(friendDoc.id), {
              'uid': friendDoc.id,
              'role': isCoHostFriend ? 'co-host' : 'guest',
              'status': 'pending',
              'invitedBy': user.uid,
              'sentAt': FieldValue.serverTimestamp(),
            });
            operationCount++;
          }
          await commitBatchIfNeeded();

          batch.set(eventRef.collection('invitations').doc(user.uid), {
            'uid': user.uid,
            'role': 'host',
            'status': 'going',
            'invitedBy': user.uid,
            'sentAt': FieldValue.serverTimestamp(),
          });
          operationCount++;
          await commitBatchIfNeeded();

          for (String roleTitle in request.roles) {
            batch.set(eventRef.collection('roles').doc(), {
              'title': roleTitle,
              'addedBy': user.uid,
              'claimedByUid': null,
              'claimedByName': null,
              'createdAt': FieldValue.serverTimestamp(),
            });
            operationCount++;
          }
          await commitBatchIfNeeded();
        }

        if (operationCount > 0) await batch.commit();

        // Banner upload (once, shared across all events in the season)
        if ((request.bannerImageBytes != null || request.bannerImagePath != null) && createdEventRefs.isNotEmpty) {
          try {
            Uint8List? bytes = request.bannerImageBytes;
            if (bytes == null && request.bannerImagePath != null && !kIsWeb) {
              final File file = File(request.bannerImagePath!);
              bytes = await file.readAsBytes();
            }
            if (bytes != null) {
              Uint8List compressedBytes = bytes;
              try {
                compressedBytes = await FlutterImageCompress.compressWithList(
                  bytes,
                  minWidth: 1280,
                  minHeight: 720,
                  quality: 75,
                );
              } catch (compErr) {
                debugPrint("Season banner compression error (using raw bytes): $compErr");
              }

              final String storageFolderId =
                  newSeasonId ?? createdEventRefs.first.id;
              final Reference ref = FirebaseStorage.instance.ref().child(
                'event_banners/$storageFolderId/banner.jpg',
              );

              final TaskSnapshot snapshot = await ref.putData(
                compressedBytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              final String downloadUrl = await snapshot.ref.getDownloadURL();

              if (seasonRef != null) {
                await seasonRef.update({'bannerUrl': downloadUrl});
              }

            WriteBatch urlBatch = FirebaseFirestore.instance.batch();
            int urlOps = 0;
            for (var eRef in createdEventRefs) {
              urlBatch.update(eRef, {'bannerUrl': downloadUrl});
              urlOps++;
              if (urlOps > 450) {
                await urlBatch.commit();
                urlBatch = FirebaseFirestore.instance.batch();
                urlOps = 0;
              }
            }
            if (urlOps > 0) await urlBatch.commit();
            }
          } catch (e) {
            debugPrint("Failed to upload banner: $e");
          }
        }
      }

      onSuccess?.call();
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Pure Deletion Backend Method (No BuildContext)
  // ---------------------------------------------------------------------------

  static Future<void> deleteEvent({
    required String eventId,
    required bool isVibeCheck,
    String deleteScope = 'single',
    String? seasonId,
    Timestamp? eventTime,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (deleteScope == 'single') {
      final eventRef = firestore.collection('events').doc(eventId);
      final batch = firestore.batch();

      final invitesSnap = await eventRef.collection('invitations').get();
      for (var doc in invitesSnap.docs) {
        batch.delete(doc.reference);
      }

      final messagesSnap = await eventRef.collection('messages').get();
      for (var doc in messagesSnap.docs) {
        batch.delete(doc.reference);
      }

      final rolesSnap = await eventRef.collection('roles').get();
      for (var doc in rolesSnap.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(eventRef);
      await batch.commit();

      try {
        await FirebaseStorage.instance
            .ref()
            .child('event_banners/$eventId/banner.jpg')
            .delete();
      } catch (_) {}

      try {
        final chatImagesRef = FirebaseStorage.instance.ref().child(
          'chat_images/$eventId',
        );
        final listResult = await chatImagesRef.listAll();
        for (var item in listResult.items) {
          await item.delete();
        }
      } catch (_) {}
    } else if (deleteScope == 'future' &&
        seasonId != null &&
        eventTime != null) {
      final futureEvents = await firestore
          .collection('events')
          .where('seasonId', isEqualTo: seasonId)
          .where('time', isGreaterThanOrEqualTo: eventTime)
          .get();

      WriteBatch batch = firestore.batch();
      int opCount = 0;

      Future<void> commitIfNeeded() async {
        if (opCount > 450) {
          await batch.commit();
          batch = firestore.batch();
          opCount = 0;
        }
      }

      for (var doc in futureEvents.docs) {
        final eventRef = doc.reference;

        final invites = await eventRef.collection('invitations').get();
        for (var inv in invites.docs) {
          batch.delete(inv.reference);
          opCount++;
          await commitIfNeeded();
        }

        final msgs = await eventRef.collection('messages').get();
        for (var msg in msgs.docs) {
          batch.delete(msg.reference);
          opCount++;
          await commitIfNeeded();
        }

        final roles = await eventRef.collection('roles').get();
        for (var role in roles.docs) {
          batch.delete(role.reference);
          opCount++;
          await commitIfNeeded();
        }

        batch.delete(eventRef);
        opCount++;
        await commitIfNeeded();

        try {
          final chatImagesRef = FirebaseStorage.instance.ref().child(
            'chat_images/${eventRef.id}',
          );
          final listResult = await chatImagesRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
        } catch (_) {}
      }

      if (opCount > 0) await batch.commit();

      await firestore.collection('seasons').doc(seasonId).delete();

      try {
        await FirebaseStorage.instance
            .ref()
            .child('event_banners/$seasonId/banner.jpg')
            .delete();
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Delete Event with User Confirmation (UI Helper)
  // ---------------------------------------------------------------------------

  static Future<void> deleteEventWithConfirmation({
    required BuildContext context,
    required String eventId,
    required bool isVibeCheck,
    required ValueChanged<bool> onLoadingChanged,
    String? seasonId,
    Timestamp? eventTime,
  }) async {
    final deleteScope = await SeasonDialogs.showDeleteConfirmation(
      context,
      isVibeCheck: isVibeCheck,
      isRecurringSeason: seasonId != null,
    );

    if (deleteScope == null) return;

    final successMessage = isVibeCheck
        ? "Vibe Check deleted permanently."
        : (deleteScope == 'future'
              ? "Season deleted permanently."
              : "Hangout deleted permanently.");

    onLoadingChanged(true);
    try {
      await deleteEvent(
        eventId: eventId,
        isVibeCheck: isVibeCheck,
        deleteScope: deleteScope,
        seasonId: seasonId,
        eventTime: eventTime,
      );

      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.popUntil(context, (route) => route.isFirst);
        messenger.showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
      }
    } finally {
      onLoadingChanged(false);
    }
  }

  /// Toggle hidden status of an event for a user
  static Future<void> toggleEventHidden({
    required String eventId,
    required String uid,
    required bool currentlyHidden,
  }) async {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('invitations')
        .doc(uid)
        .set({
          'uid': uid,
          'isHidden': !currentlyHidden,
        }, SetOptions(merge: true));
  }
}
