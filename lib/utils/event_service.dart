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
  /// Notifies listeners whenever an event has been deleted permanently.
  static final ValueNotifier<String?> lastDeletedEventId =
      ValueNotifier<String?>(null);

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
        final Set<String> allFriendIds =
            friendsSnapshot.docs.map((d) => d.id).toSet();
        Set<String> teamMemberIds = {};
        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data();
          final friendCircles = List<String>.from(data['circles'] ?? []);
          if (request.inviteAll ||
              request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
            teamMemberIds.add(friendDoc.id);
          }
        }

        final List<String> effectiveLastMinuteIds =
            (request.inviteAll || request.selectedCircleIds.isEmpty)
                ? <String>[]
                : request.lastMinuteInviteIds
                    .where(
                      (id) =>
                          allFriendIds.contains(id) &&
                          !teamMemberIds.contains(id),
                    )
                    .toSet()
                    .toList();

        if (request.isMainHost) {
          updateData['inviteAll'] = request.inviteAll;
          updateData['invitedCircles'] = request.selectedCircleIds;
          updateData['lastMinuteInvites'] = effectiveLastMinuteIds;
          updateData['coHostId'] = request.coHostId;
          updateData['coHostName'] = request.coHostName;
        } else {
          updateData['coHostInviteAll'] = request.inviteAll;
          updateData['coHostInvitedCircles'] = request.selectedCircleIds;
          updateData['coHostLastMinuteInvites'] = effectiveLastMinuteIds;
        }

        Set<String> newIntendedIds = {
          ...teamMemberIds,
          ...effectiveLastMinuteIds,
        };

        final currentInvitesSnap = await FirebaseFirestore.instance
            .collection('events')
            .doc(request.eventId!)
            .collection('invitations')
            .get();
        final Set<String> currentlyInvitedIds =
            currentInvitesSnap.docs.map((d) => d.id).toSet();

        Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
        Set<String> toRemove = {};

        final String? hostId = request.eventData?['hostId'];
        final String? coHostId = request.isMainHost
            ? (request.coHostId ?? request.eventData?['coHostId'])
            : request.eventData?['coHostId'];

        for (var doc in currentInvitesSnap.docs) {
          final uid = doc.id;
          if (uid == hostId || uid == user.uid) continue;
          if (uid == coHostId) continue;

          final inviteData = doc.data();
          final invitedBy = inviteData['invitedBy'];
          if (request.isMainHost) {
            // Preserve guests invited by co-host
            if (coHostId != null && invitedBy == coHostId) continue;
          } else {
            // Co-host only removes guests they personally invited
            if (invitedBy != user.uid) continue;
          }

          if (!newIntendedIds.contains(uid)) {
            toRemove.add(uid);
          }
        }

        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(request.eventId!);

        if (toAdd.isNotEmpty) {
          for (String uid in toAdd) {
            if (!currentlyInvitedIds.contains(uid)) {
              batch.set(eventRef.collection('invitations').doc(uid), {
                'uid': uid,
                'role': uid == coHostId ? 'co-host' : 'guest',
                'status': 'pending',
                'votes': [],
                'invitedBy': user.uid,
                'sentAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        if (toRemove.isNotEmpty) {
          for (String uid in toRemove) {
            batch.delete(eventRef.collection('invitations').doc(uid));
          }
        }

        if (toAdd.isNotEmpty || toRemove.isNotEmpty) {
          final Set<String> updatedVisibleTo = Set<String>.from(
            request.eventData?['visibleTo'] ?? [],
          );
          updatedVisibleTo.removeAll(toRemove);
          updatedVisibleTo.addAll(toAdd);
          if (hostId != null && hostId.isNotEmpty) {
            updatedVisibleTo.add(hostId);
          }
          if (coHostId != null && coHostId.isNotEmpty) {
            updatedVisibleTo.add(coHostId);
          }
          updatedVisibleTo.add(user.uid);
          updateData['visibleTo'] = updatedVisibleTo.toList();
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

        final Set<String> allFriendIds =
            friendsSnapshot.docs.map((d) => d.id).toSet();
        Set<String> visibleToIds = {user.uid};
        Set<String> teamMemberIds = {};

        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data();
          final friendCircles = List<String>.from(data['circles'] ?? []);
          if (request.inviteAll ||
              request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
            teamMemberIds.add(friendDoc.id);
            visibleToIds.add(friendDoc.id);
          }
        }

        if (teamMemberIds.isEmpty && !request.inviteAll) {
          onError?.call("No friends found in selected teams!");
          onLoadingChanged?.call(false);
          return;
        }

        final List<String> effectiveLastMinuteIds =
            (request.inviteAll || request.selectedCircleIds.isEmpty)
                ? <String>[]
                : request.lastMinuteInviteIds
                    .where(
                      (id) =>
                          allFriendIds.contains(id) &&
                          !teamMemberIds.contains(id),
                    )
                    .toSet()
                    .toList();

        final Set<String> allInvitedFriendIds = {
          ...teamMemberIds,
          ...effectiveLastMinuteIds,
        };
        visibleToIds.addAll(allInvitedFriendIds);

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
          'lastMinuteInvites': effectiveLastMinuteIds,
          'rsvpDeadline': request.rsvpDeadlineOffset,
        });

        for (var friendId in allInvitedFriendIds) {
          batch.set(eventRef.collection('invitations').doc(friendId), {
            'uid': friendId,
            'role': friendId == request.coHostId ? 'co-host' : 'guest',
            'status': 'pending',
            'votes': [],
            'invitedBy': user.uid,
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
        if (request.isMainHost) {
          if (request.hostLocationLabel != null &&
              request.hostLocationLabel!.isNotEmpty) {
            updateData['hostLocationLabel'] = request.hostLocationLabel;
          } else {
            updateData['hostLocationLabel'] = FieldValue.delete();
          }
        } else if (oldLoc != request.location) {
          updateData['hostLocationLabel'] = FieldValue.delete();
        }
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

        final Set<String> allFriendIds =
            friendsSnapshot.docs.map((d) => d.id).toSet();

        if (request.isMainHost) {
          // Host: full roster control (add + remove) & co-captain assignment
          updateData['inviteAll'] = request.inviteAll;
          updateData['invitedCircles'] = request.selectedCircleIds;
          updateData['coHostId'] = request.coHostId;
          updateData['coHostName'] = request.coHostName;

          Set<String> teamMemberIds = {};
          for (var friendDoc in friendsSnapshot.docs) {
            final friendCircles = List<String>.from(
              friendDoc.data()['circles'] ?? [],
            );
            if (request.inviteAll ||
                request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
              teamMemberIds.add(friendDoc.id);
            }
          }

          final List<String> effectiveLastMinuteIds =
              (request.inviteAll || request.selectedCircleIds.isEmpty)
                  ? <String>[]
                  : request.lastMinuteInviteIds
                      .where(
                        (id) =>
                            allFriendIds.contains(id) &&
                            !teamMemberIds.contains(id),
                      )
                      .toSet()
                      .toList();

          updateData['lastMinuteInvites'] = effectiveLastMinuteIds;

          Set<String> newIntendedIds = {
            ...teamMemberIds,
            ...effectiveLastMinuteIds,
          };

          Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
          Set<String> toRemove = {};

          final String? hostId = request.eventData?['hostId'];
          final String? coHostId =
              request.coHostId ?? request.eventData?['coHostId'];

          for (var doc in currentInvitesSnap.docs) {
            final uid = doc.id;
            if (uid == hostId || uid == user.uid) continue;
            if (uid == coHostId) continue;

            final inviteData = doc.data();
            final invitedBy = inviteData['invitedBy'];
            // Preserve guests invited by co-host
            if (coHostId != null && invitedBy == coHostId) continue;

            if (!newIntendedIds.contains(uid)) {
              toRemove.add(uid);
            }
          }

          if (toAdd.isNotEmpty) {
            for (String uid in toAdd) {
              if (!currentlyInvitedIds.contains(uid)) {
                batch.set(eventRef.collection('invitations').doc(uid), {
                  'uid': uid,
                  'role': uid == coHostId ? 'co-host' : 'guest',
                  'status': 'pending',
                  'invitedBy': user.uid,
                  'sentAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
          if (toRemove.isNotEmpty) {
            for (String uid in toRemove) {
              batch.delete(eventRef.collection('invitations').doc(uid));
            }
            final rolesSnap = await eventRef.collection('roles').get();
            for (var roleDoc in rolesSnap.docs) {
              final claimedBy = roleDoc.data()['claimedByUid'];
              if (claimedBy != null && toRemove.contains(claimedBy)) {
                batch.update(roleDoc.reference, {
                  'claimedByUid': null,
                  'claimedByName': null,
                });
              }
            }
          }
          if (toAdd.isNotEmpty || toRemove.isNotEmpty) {
            final Set<String> updatedVisibleTo = Set<String>.from(
              request.eventData?['visibleTo'] ?? [],
            );
            updatedVisibleTo.removeAll(toRemove);
            updatedVisibleTo.addAll(toAdd);
            if (hostId != null && hostId.isNotEmpty) {
              updatedVisibleTo.add(hostId);
            }
            if (coHostId != null && coHostId.isNotEmpty) {
              updatedVisibleTo.add(coHostId);
            }
            updatedVisibleTo.add(user.uid);
            updateData['visibleTo'] = updatedVisibleTo.toList();
          }
        } else {
          // Co-host: full diff on their own scope (add + remove)
          final String? hostId = request.eventData?['hostId'];
          updateData['coHostInviteAll'] = request.inviteAll;
          updateData['coHostInvitedCircles'] = request.selectedCircleIds;

          Set<String> coHostTeamMemberIds = {};
          for (var friendDoc in friendsSnapshot.docs) {
            final friendCircles = List<String>.from(
              friendDoc.data()['circles'] ?? [],
            );
            if (request.inviteAll ||
                request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
              coHostTeamMemberIds.add(friendDoc.id);
            }
          }

          final List<String> effectiveCoHostLastMinuteIds =
              (request.inviteAll || request.selectedCircleIds.isEmpty)
                  ? <String>[]
                  : request.lastMinuteInviteIds
                      .where(
                        (id) =>
                            allFriendIds.contains(id) &&
                            !coHostTeamMemberIds.contains(id) &&
                            id != hostId,
                      )
                      .toSet()
                      .toList();

          updateData['coHostLastMinuteInvites'] = effectiveCoHostLastMinuteIds;

          Set<String> newCoHostFriendIds = {
            ...coHostTeamMemberIds,
            ...effectiveCoHostLastMinuteIds,
          };

          // Add new guests
          Set<String> toAdd = newCoHostFriendIds.difference(currentlyInvitedIds);
          if (toAdd.isNotEmpty) {
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

          // Remove guests the co-host previously added who are no longer intended
          Set<String> potentialRemoves = {};
          for (var doc in currentInvitesSnap.docs) {
            final uid = doc.id;
            if (uid == hostId || uid == user.uid) continue;
            final inviteData = doc.data();
            if (inviteData['invitedBy'] == user.uid) {
              if (!newCoHostFriendIds.contains(uid)) {
                potentialRemoves.add(uid);
              }
            }
          }

          if (potentialRemoves.isNotEmpty) {
            for (String uid in potentialRemoves) {
              batch.delete(eventRef.collection('invitations').doc(uid));
            }

            final rolesSnap = await eventRef.collection('roles').get();
            for (var roleDoc in rolesSnap.docs) {
              final claimedBy = roleDoc.data()['claimedByUid'];
              if (claimedBy != null && potentialRemoves.contains(claimedBy)) {
                batch.update(roleDoc.reference, {
                  'claimedByUid': null,
                  'claimedByName': null,
                });
              }
            }
          }

          if (toAdd.isNotEmpty || potentialRemoves.isNotEmpty) {
            final Set<String> updatedVisibleTo = Set<String>.from(
              request.eventData?['visibleTo'] ?? [],
            );
            updatedVisibleTo.removeAll(potentialRemoves);
            updatedVisibleTo.addAll(toAdd);
            if (hostId != null && hostId.isNotEmpty) {
              updatedVisibleTo.add(hostId);
            }
            updatedVisibleTo.add(user.uid);
            updateData['visibleTo'] = updatedVisibleTo.toList();
          }
        }

        // --- Scoped batch commit ---
        if (updateScope == 'single') {
          batch.update(eventRef, updateData);
          await batch.commit();
        } else if (updateScope == 'future' && seasonId != null) {
          // Ensure current event gets all its specific updates (including lastMinuteInvites & visibleTo)
          batch.update(eventRef, updateData);

          final currentEventTime = request.eventData!['time'] as Timestamp;
          final futureEvents = await FirebaseFirestore.instance
              .collection('events')
              .where('seasonId', isEqualTo: seasonId)
              .where('time', isGreaterThanOrEqualTo: currentEventTime)
              .get();

          final seasonFields = {
            'title': request.title,
            'location': request.location,
            if (request.isMainHost)
              'hostLocationLabel': (request.hostLocationLabel != null &&
                      request.hostLocationLabel!.isNotEmpty)
                  ? request.hostLocationLabel
                  : FieldValue.delete(),
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

          final List<String> otherFutureEventIds = [];
          for (var doc in futureEvents.docs) {
            if (doc.id == request.eventId) continue;
            otherFutureEventIds.add(doc.id);

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

          for (final futureId in otherFutureEventIds) {
            try {
              await syncEventInvitesWithTeams(futureId);
            } catch (_) {}
          }

          await FirebaseFirestore.instance
              .collection('seasons')
              .doc(seasonId)
              .update({
                'title': request.title,
                'location': request.location,
                if (request.isMainHost)
                  'hostLocationLabel': (request.hostLocationLabel != null &&
                          request.hostLocationLabel!.isNotEmpty)
                      ? request.hostLocationLabel
                      : FieldValue.delete(),
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

        final Set<String> allFriendIds =
            friendsSnapshot.docs.map((d) => d.id).toSet();
        Set<String> teamMemberIds = {};

        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data() as Map<String, dynamic>? ?? {};
          final friendCircles = List<String>.from(data['circles'] ?? []);
          if (request.inviteAll ||
              request.selectedCircleIds.any((id) => friendCircles.contains(id))) {
            teamMemberIds.add(friendDoc.id);
          }
        }

        if (teamMemberIds.isEmpty && !request.inviteAll) {
          onError?.call("No friends found in selected teams!");
          onLoadingChanged?.call(false);
          return;
        }

        final List<String> effectiveLastMinuteIds =
            (request.inviteAll || request.selectedCircleIds.isEmpty)
                ? <String>[]
                : request.lastMinuteInviteIds
                    .where(
                      (id) =>
                          allFriendIds.contains(id) &&
                          !teamMemberIds.contains(id),
                    )
                    .toSet()
                    .toList();

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
            if (request.hostLocationLabel != null &&
                request.hostLocationLabel!.isNotEmpty)
              'hostLocationLabel': request.hostLocationLabel,
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

          // Last Minute Invites apply strictly per-hangout ("on this one"), so only to the first instance on creation
          final List<String> instanceLastMinuteIds =
              (i == 0) ? effectiveLastMinuteIds : <String>[];
          final Set<String> instanceFriendIds = {
            ...teamMemberIds,
            ...instanceLastMinuteIds,
            if (request.coHostId != null && request.coHostId!.isNotEmpty)
              request.coHostId!,
          };
          final Set<String> instanceVisibleToIds = {
            user.uid,
            ...instanceFriendIds,
          };

          batch.set(eventRef, {
            'hostId': user.uid,
            'coHostId': request.coHostId,
            'coHostName': request.coHostName,
            'title': request.title,
            'location': request.location,
            if (request.hostLocationLabel != null &&
                request.hostLocationLabel!.isNotEmpty)
              'hostLocationLabel': request.hostLocationLabel,
            'details': request.details,
            'time': Timestamp.fromDate(date),
            'endTime': Timestamp.fromDate(endTime),
            'isPast': false,
            'created_at': FieldValue.serverTimestamp(),
            'visibleTo': instanceVisibleToIds.toList(),
            'inviteAll': request.inviteAll,
            'invitedCircles': request.selectedCircleIds,
            'lastMinuteInvites': instanceLastMinuteIds,
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

          for (var friendId in instanceFriendIds) {
            final isCoHostFriend = friendId == request.coHostId;
            batch.set(eventRef.collection('invitations').doc(friendId), {
              'uid': friendId,
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
      lastDeletedEventId.value = eventId;

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
      lastDeletedEventId.value = eventId;

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
    if (!context.mounted) return;

    final successMessage = isVibeCheck
        ? "Vibe Check deleted permanently."
        : (deleteScope == 'future'
              ? "Season deleted permanently."
              : "Hangout deleted permanently.");

    onLoadingChanged(true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await deleteEvent(
        eventId: eventId,
        isVibeCheck: isVibeCheck,
        deleteScope: deleteScope,
        seasonId: seasonId,
        eventTime: eventTime,
      );

      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
      }
    } finally {
      if (context.mounted) {
        onLoadingChanged(false);
      }
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

  /// Updates a hangout's Last Minute Invites directly (e.g. from HangoutDetailsPage)
  /// and synchronizes invitations and visibleTo immediately.
  static Future<void> updateLastMinuteInvites({
    required String eventId,
    required List<String> lastMinuteInviteIds,
    required bool isMainHost,
  }) async {
    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(eventId);
    await eventRef.update({
      if (isMainHost)
        'lastMinuteInvites': lastMinuteInviteIds
      else
        'coHostLastMinuteInvites': lastMinuteInviteIds,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    await syncEventInvitesWithTeams(eventId);
  }

  /// Checks whether an event document represents an active (non-past) event.
  static bool _isEventActive(Map<String, dynamic> eventData, [DateTime? now]) {
    if (eventData['isPast'] == true) return false;
    final currentTime = now ?? DateTime.now();
    final Timestamp? endTs = eventData['endTime'] as Timestamp?;
    if (endTs != null) {
      return endTs.toDate().isAfter(currentTime);
    }
    final Timestamp? timeTs = eventData['time'] as Timestamp?;
    if (timeTs != null) {
      final int keepAliveDays = eventData['keepAliveDays'] ?? 0;
      final int durMins = keepAliveDays > 0 ? (keepAliveDays * 24 * 60) : 240;
      final DateTime fallbackEnd =
          timeTs.toDate().add(Duration(minutes: durMins));
      return fallbackEnd.isAfter(currentTime);
    }
    return false;
  }

  /// Synchronizes all active/upcoming Hangouts and Vibe Checks for [uid]
  /// (where [uid] is Host or Co-Captain).
  /// If [circleId] is provided, only syncs events where that team is invited
  /// (or where "Entire Squad" is active).
  /// If [deletedCircleId] is provided, removes that circle ID from the event's
  /// invitedCircles / coHostInvitedCircles before syncing.
  static Future<void> syncActiveEventsForUser(
    String uid, {
    String? circleId,
    String? deletedCircleId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != uid) return;

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();

    try {
      final results = await Future.wait([
        firestore.collection('events').where('hostId', isEqualTo: uid).get(),
        firestore.collection('events').where('coHostId', isEqualTo: uid).get(),
      ]);

      final hostedDocs = results[0].docs;
      final coHostedDocs = results[1].docs;

      for (final doc in hostedDocs) {
        final data = doc.data();
        if (!_isEventActive(data, now)) continue;

        final bool inviteAll = data['inviteAll'] ?? true;
        final List<String> circles =
            List<String>.from(data['invitedCircles'] ?? []);

        if (deletedCircleId != null && circles.contains(deletedCircleId)) {
          circles.remove(deletedCircleId);
          await doc.reference.update({'invitedCircles': circles});
        }

        if (circleId == null || inviteAll || circles.contains(circleId)) {
          try {
            await syncEventInvitesWithTeams(doc.id);
          } catch (e) {
            debugPrint("Error syncing hosted event ${doc.id}: $e");
          }
        }
      }

      for (final doc in coHostedDocs) {
        final data = doc.data();
        if (data['hostId'] == uid) continue; // Already handled above
        if (!_isEventActive(data, now)) continue;

        final bool coHostInviteAll = data['coHostInviteAll'] ?? false;
        final List<String> coHostCircles =
            List<String>.from(data['coHostInvitedCircles'] ?? []);

        if (deletedCircleId != null &&
            coHostCircles.contains(deletedCircleId)) {
          coHostCircles.remove(deletedCircleId);
          await doc.reference.update({'coHostInvitedCircles': coHostCircles});
        }

        if (circleId == null ||
            coHostInviteAll ||
            coHostCircles.contains(circleId)) {
          try {
            await syncEventInvitesWithTeams(doc.id);
          } catch (e) {
            debugPrint("Error syncing co-hosted event ${doc.id}: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Error in syncActiveEventsForUser: $e");
    }
  }

  /// Synchronizes an event's invitations and visibleTo with the current user's
  /// team/circle members and Last Minute Invites.
  /// Strictly queries only the authenticated user's own friends collection to
  /// respect Firestore security rules (`isOwner`), while preserving the other
  /// host/co-host's invitations.
  static Future<void> syncEventInvitesWithTeams(String eventId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(eventId);
    final eventSnap = await eventRef.get();
    if (!eventSnap.exists) return;
    final eventData = eventSnap.data()!;

    // Skip past/ended events (Firestore security rules block updates after endTime)
    if (!_isEventActive(eventData)) return;

    final String hostId = eventData['hostId'] ?? '';
    final String? coHostId = eventData['coHostId'];
    final bool isVibeCheck = eventData['type'] == 'vibe_check';

    final bool isMainHost = currentUser.uid == hostId;
    final bool isCoHost = coHostId != null && currentUser.uid == coHostId;
    if (!isMainHost && !isCoHost) return;

    final myFriendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .get();
    final Set<String> allMyFriendIds =
        myFriendsSnap.docs.map((d) => d.id).toSet();

    final invitesSnap = await eventRef.collection('invitations').get();
    final Set<String> currentUids = invitesSnap.docs.map((d) => d.id).toSet();

    final Set<String> toRemove = {};
    final Set<String> toAdd = {};
    final Set<String> toClaimHostOwnership = {};
    final Map<String, dynamic> updateData = {};

    if (isMainHost) {
      final bool inviteAll = eventData['inviteAll'] ?? true;
      final List<String> invitedCircles =
          List<String>.from(eventData['invitedCircles'] ?? []);
      final List<String> rawLastMinute =
          List<String>.from(eventData['lastMinuteInvites'] ?? []);

      final Set<String> teamMemberIds = {};
      for (final doc in myFriendsSnap.docs) {
        final friendCircles = List<String>.from(doc.data()['circles'] ?? []);
        if (inviteAll ||
            invitedCircles.any((c) => friendCircles.contains(c))) {
          teamMemberIds.add(doc.id);
        }
      }

      // Deduplicate Last Minute Invites against team members & current squad
      final List<String> effectiveLastMinute =
          (inviteAll || invitedCircles.isEmpty)
              ? <String>[]
              : rawLastMinute
                  .where(
                    (id) =>
                        allMyFriendIds.contains(id) &&
                        !teamMemberIds.contains(id),
                  )
                  .toSet()
                  .toList();

      if (effectiveLastMinute.length != rawLastMinute.length ||
          !effectiveLastMinute.every((id) => rawLastMinute.contains(id))) {
        updateData['lastMinuteInvites'] = effectiveLastMinute;
      }

      final Set<String> intendedHostFriendIds = {
        ...teamMemberIds,
        ...effectiveLastMinute,
      };

      for (final doc in invitesSnap.docs) {
        final uid = doc.id;
        if (uid == hostId || uid == coHostId) continue;

        final inviteData = doc.data();
        final invitedBy = inviteData['invitedBy'];

        if (coHostId != null && invitedBy == coHostId) {
          // If the main host also now intends to invite this friend, claim host ownership
          if (intendedHostFriendIds.contains(uid)) {
            toClaimHostOwnership.add(uid);
          }
          continue;
        }

        if (!intendedHostFriendIds.contains(uid)) {
          toRemove.add(uid);
        }
      }

      for (final uid in intendedHostFriendIds) {
        if (!currentUids.contains(uid)) {
          toAdd.add(uid);
        }
      }
    } else {
      // Co-Host scope
      final bool coHostInviteAll = eventData['coHostInviteAll'] ?? false;
      final List<String> coHostInvitedCircles =
          List<String>.from(eventData['coHostInvitedCircles'] ?? []);
      final List<String> rawCoHostLastMinute =
          List<String>.from(eventData['coHostLastMinuteInvites'] ?? []);

      final Set<String> coHostTeamMemberIds = {};
      for (final doc in myFriendsSnap.docs) {
        final friendCircles = List<String>.from(doc.data()['circles'] ?? []);
        if (coHostInviteAll ||
            coHostInvitedCircles.any((c) => friendCircles.contains(c))) {
          if (doc.id != hostId) {
            coHostTeamMemberIds.add(doc.id);
          }
        }
      }

      final List<String> effectiveCoHostLastMinute =
          (coHostInviteAll || coHostInvitedCircles.isEmpty)
              ? <String>[]
              : rawCoHostLastMinute
                  .where(
                    (id) =>
                        allMyFriendIds.contains(id) &&
                        !coHostTeamMemberIds.contains(id) &&
                        id != hostId,
                  )
                  .toSet()
                  .toList();

      if (effectiveCoHostLastMinute.length != rawCoHostLastMinute.length ||
          !effectiveCoHostLastMinute.every(
            (id) => rawCoHostLastMinute.contains(id),
          )) {
        updateData['coHostLastMinuteInvites'] = effectiveCoHostLastMinute;
      }

      final Set<String> intendedCoHostFriendIds = {
        ...coHostTeamMemberIds,
        ...effectiveCoHostLastMinute,
      };

      for (final doc in invitesSnap.docs) {
        final uid = doc.id;
        if (uid == hostId || uid == coHostId) continue;

        final inviteData = doc.data();
        if (inviteData['invitedBy'] == coHostId) {
          if (!intendedCoHostFriendIds.contains(uid)) {
            toRemove.add(uid);
          }
        }
      }

      for (final uid in intendedCoHostFriendIds) {
        if (!currentUids.contains(uid)) {
          toAdd.add(uid);
        }
      }
    }

    if (toRemove.isEmpty &&
        toAdd.isEmpty &&
        toClaimHostOwnership.isEmpty &&
        updateData.isEmpty) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    for (final uid in toClaimHostOwnership) {
      batch.update(eventRef.collection('invitations').doc(uid), {
        'invitedBy': hostId,
      });
    }

    for (final uid in toRemove) {
      batch.delete(eventRef.collection('invitations').doc(uid));
    }

    for (final uid in toAdd) {
      batch.set(eventRef.collection('invitations').doc(uid), {
        'uid': uid,
        'role': uid == coHostId ? 'co-host' : 'guest',
        'status': 'pending',
        if (isVibeCheck) 'votes': [],
        'invitedBy': currentUser.uid,
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    if (toRemove.isNotEmpty || toAdd.isNotEmpty) {
      final Set<String> updatedVisibleTo = Set<String>.from(
        eventData['visibleTo'] ?? [],
      );
      updatedVisibleTo.removeAll(toRemove);
      updatedVisibleTo.addAll(toAdd);
      if (hostId.isNotEmpty) updatedVisibleTo.add(hostId);
      if (coHostId != null && coHostId.isNotEmpty) {
        updatedVisibleTo.add(coHostId);
      }
      updateData['visibleTo'] = updatedVisibleTo.toList();
    }

    if (updateData.isNotEmpty) {
      batch.update(eventRef, updateData);
    }

    // Also unclaim any roles claimed by removed users
    if (toRemove.isNotEmpty) {
      final rolesSnap = await eventRef.collection('roles').get();
      for (final roleDoc in rolesSnap.docs) {
        final claimedBy = roleDoc.data()['claimedByUid'];
        if (claimedBy != null && toRemove.contains(claimedBy)) {
          batch.update(roleDoc.reference, {
            'claimedByUid': null,
            'claimedByName': null,
          });
        }
      }
    }

    await batch.commit();
  }
}
