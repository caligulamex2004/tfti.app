import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class EventService {
  // ---------------------------------------------------------------------------
  // Submit / Create / Update a Hangout
  // ---------------------------------------------------------------------------

  static Future<void> submitHangout({
    required BuildContext context,
    required bool isEditing,
    required bool isMainHost,
    required bool isCoHost,
    required String? eventId,
    required Map<String, dynamic>? eventData,

    // Form values
    required String title,
    required String location,
    required String details,
    required DateTime selectedDate,
    required TimeOfDay selectedTime,
    required bool inviteAll,
    required List<String> selectedCircleIds,
    required int rsvpDeadlineOffset,
    required int keepAliveDays,
    required bool isImportantDetails,

    // Recurring
    required bool isRecurring,
    required String recurringFrequency,
    required int recurringInstances,
    required List<DateTime> Function(DateTime) generateSeasonDates,

    // Banner
    required String? bannerImagePath,
    required bool removeBanner,

    // Co-host
    required String? coHostId,
    required String? coHostName,

    // Squad needs (create mode only)
    required List<String> roles,

    // Callbacks
    required ValueChanged<bool> onLoadingChanged,
    required VoidCallback onSuccess,
    required ValueChanged<String> onError,
  }) async {
    onLoadingChanged(true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onLoadingChanged(false);
      return;
    }

    try {
      final newDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      final int durationMinutes = keepAliveDays > 0
          ? (keepAliveDays * 24 * 60)
          : 240;
      final newEndTime = newDateTime.add(Duration(minutes: durationMinutes));

      String updateScope = 'single';
      final String? seasonId = isEditing ? eventData!['seasonId'] : null;

      // -----------------------------------------------------------------------
      // Scope picker: editing a recurring season
      // -----------------------------------------------------------------------
      if (isEditing && isMainHost && seasonId != null && isRecurring) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final scope = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Update Season",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Do you want to apply these changes to just this hangout, or to this and all future hangouts in the Season?",
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text(
                      "This hangout only",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => Navigator.pop(ctx, 'single'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.update),
                    title: const Text(
                      "This and all future hangouts",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => Navigator.pop(ctx, 'future'),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!context.mounted) return;
        if (scope == null) {
          onLoadingChanged(false);
          return;
        }
        updateScope = scope;
      }

      // -----------------------------------------------------------------------
      // Toggle-off confirmation: user turned off recurring for an existing season
      // -----------------------------------------------------------------------
      if (isEditing && isMainHost && seasonId != null && !isRecurring) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final confirm = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Turn Off Recurring?",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "This will save this hangout as a single event and delete all future hangouts in the season. Continue?",
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.cancel),
                    title: const Text(
                      "Cancel",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_delete, color: Colors.red),
                    title: const Text(
                      "Turn Off & Delete Future",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!context.mounted) return;
        if (confirm != true) {
          onLoadingChanged(false);
          return;
        }
        updateScope = 'toggle_off';
      }

      // -----------------------------------------------------------------------
      // EDIT PATH
      // -----------------------------------------------------------------------
      if (isEditing) {
        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(eventId);
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

        final oldTimeTs = eventData!['time'] as Timestamp?;
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

        final oldLoc = (eventData['location'] ?? '').toString().trim();
        if (oldLoc != location) {
          changedFields.add("Location");
          oldValues.add(oldLoc.isEmpty ? "TBD" : oldLoc);
          newValues.add(location.isEmpty ? "TBD" : location);
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
        updateData['title'] = title;
        updateData['location'] = location;
        updateData['details'] = details;
        updateData['time'] = Timestamp.fromDate(newDateTime);
        updateData['endTime'] = Timestamp.fromDate(newEndTime);
        updateData['isImportantDetails'] = isImportantDetails;
        updateData['rsvpDeadline'] = rsvpDeadlineOffset;
        updateData['keepAliveDays'] = keepAliveDays;

        if (removeBanner) {
          updateData['bannerUrl'] = FieldValue.delete();
          try {
            await FirebaseStorage.instance
                .ref()
                .child('event_banners/$eventId/banner.jpg')
                .delete();
          } catch (_) {}
        } else if (bannerImagePath != null) {
          try {
            final File file = File(bannerImagePath);
            final Uint8List bytes = await file.readAsBytes();
            final Uint8List compressedBytes =
                await FlutterImageCompress.compressWithList(
                  bytes,
                  minWidth: 1280,
                  minHeight: 720,
                  quality: 75,
                );
            final ref = FirebaseStorage.instance.ref().child(
              'event_banners/$eventId/banner.jpg',
            );
            await ref.putData(
              compressedBytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            updateData['bannerUrl'] = await ref.getDownloadURL();
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

        if (isMainHost) {
          // Host: full roster control (add + remove) & co-captain assignment
          updateData['inviteAll'] = inviteAll;
          updateData['invitedCircles'] = selectedCircleIds;
          updateData['coHostId'] = coHostId;
          updateData['coHostName'] = coHostName;

          Set<String> newIntendedIds = {};
          Set<String> oldIntendedIds = {};
          final bool oldInviteAll = eventData['inviteAll'] ?? true;
          final List<String> oldCircles = List<String>.from(
            eventData['invitedCircles'] ?? [],
          );

          for (var friendDoc in friendsSnapshot.docs) {
            final friendCircles = List<String>.from(
              friendDoc.data()['circles'] ?? [],
            );
            if (inviteAll ||
                selectedCircleIds.any((id) => friendCircles.contains(id))) {
              newIntendedIds.add(friendDoc.id);
            }
            if (oldInviteAll ||
                oldCircles.any((id) => friendCircles.contains(id))) {
              oldIntendedIds.add(friendDoc.id);
            }
          }

          Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
          Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);
          toRemove.remove(eventData['hostId']);

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
          updateData['coHostInviteAll'] = inviteAll;
          updateData['coHostInvitedCircles'] = selectedCircleIds;

          final bool oldCoHostInviteAll = eventData['coHostInviteAll'] ?? false;
          final List<String> oldCoHostCircles = List<String>.from(
            eventData['coHostInvitedCircles'] ?? [],
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
            if (inviteAll ||
                selectedCircleIds.any((id) => friendCircles.contains(id))) {
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
          potentialRemoves.remove(eventData['hostId']);
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
          final currentEventTime = eventData['time'] as Timestamp;
          final futureEvents = await FirebaseFirestore.instance
              .collection('events')
              .where('seasonId', isEqualTo: seasonId)
              .where('time', isGreaterThanOrEqualTo: currentEventTime)
              .get();

          int opCount = 0;
          for (var doc in futureEvents.docs) {
            batch.update(doc.reference, updateData);
            opCount++;
            if (opCount > 450) {
              await batch.commit();
              opCount = 0;
            }
          }
          if (opCount > 0) await batch.commit();

          await FirebaseFirestore.instance
              .collection('seasons')
              .doc(seasonId)
              .update({
                'title': title,
                'location': location,
                'details': details,
              });
        } else if (updateScope == 'toggle_off' && seasonId != null) {
          // Save this event as standalone, remove season fields
          updateData['seasonId'] = FieldValue.delete();
          updateData['seasonInstance'] = FieldValue.delete();
          updateData['seasonTotal'] = FieldValue.delete();
          batch.update(eventRef, updateData);

          // Delete future events (strictly after this one)
          final currentEventTime = eventData['time'] as Timestamp;
          final futureEvents = await FirebaseFirestore.instance
              .collection('events')
              .where('seasonId', isEqualTo: seasonId)
              .where('time', isGreaterThan: currentEventTime)
              .get();

          int opCount = 0;
          for (var doc in futureEvents.docs) {
            final fRef = doc.reference;
            final inv = await fRef.collection('invitations').get();
            for (var d in inv.docs) {
              batch.delete(d.reference);
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
        // -----------------------------------------------------------------
        // CREATE PATH
        // -----------------------------------------------------------------
        final List<DateTime> eventDates = generateSeasonDates(newDateTime);

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
          if (inviteAll ||
              selectedCircleIds.any((id) => friendCircles.contains(id))) {
            friendsToInvite.add(friendDoc);
            visibleToIds.add(friendDoc.id);
          }
        }

        if (friendsToInvite.isEmpty && !inviteAll) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("No friends found in selected teams!"),
              ),
            );
          }
          onLoadingChanged(false);
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

        if (isRecurring && eventDates.length > 1) {
          seasonRef = FirebaseFirestore.instance.collection('seasons').doc();
          newSeasonId = seasonRef.id;

          batch.set(seasonRef, {
            'hostId': user.uid,
            'coHostId': coHostId,
            'title': title,
            'location': location,
            'details': details,
            'frequency': recurringFrequency,
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

          final int durMins = keepAliveDays > 0 ? (keepAliveDays * 24 * 60) : 240;
          final DateTime endTime = date.add(Duration(minutes: durMins));

          batch.set(eventRef, {
            'hostId': user.uid,
            'coHostId': coHostId,
            'coHostName': coHostName,
            'title': title,
            'location': location,
            'details': details,
            'time': Timestamp.fromDate(date),
            'endTime': Timestamp.fromDate(endTime),
            'isPast': false,
            'created_at': FieldValue.serverTimestamp(),
            'visibleTo': visibleToIds.toList(),
            'inviteAll': inviteAll,
            'invitedCircles': selectedCircleIds,
            'isImportantDetails': isImportantDetails,
            'rsvpDeadline': rsvpDeadlineOffset,
            'keepAliveDays': keepAliveDays,
            'pointsAwarded': false,
            'seasonId': newSeasonId,
            'seasonInstance': newSeasonId != null ? (i + 1) : null,
            'seasonTotal': newSeasonId != null ? eventDates.length : null,
          });
          operationCount++;
          await commitBatchIfNeeded();

          for (var friendDoc in friendsToInvite) {
            final isCoHostFriend = friendDoc.id == coHostId;
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

          for (String roleTitle in roles) {
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
        if (bannerImagePath != null && createdEventRefs.isNotEmpty) {
          try {
            final File file = File(bannerImagePath);
            final Uint8List bytes = await file.readAsBytes();
            final Uint8List compressedBytes =
                await FlutterImageCompress.compressWithList(
                  bytes,
                  minWidth: 1280,
                  minHeight: 720,
                  quality: 75,
                );

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
          } catch (e) {
            debugPrint("Failed to upload banner: $e");
          }
        }
      }

      onSuccess();
    } catch (e) {
      onError(e.toString());
    } finally {
      onLoadingChanged(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a Hangout (or Vibe Check)
  // ---------------------------------------------------------------------------

  static Future<void> deleteEventWithConfirmation({
    required BuildContext context,
    required String eventId,
    required bool isVibeCheck,
    required ValueChanged<bool> onLoadingChanged,
    String? seasonId,
    Timestamp? eventTime,
  }) async {
    final title = isVibeCheck ? "Delete Vibe Check?" : "Delete Hangout?";
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String deleteScope = 'single';

    if (seasonId != null) {
      final scope = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delete Hangout",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  "This hangout is part of a recurring Season. Do you want to cancel just this one, or the entire remaining season?",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.event_busy),
                  title: const Text(
                    "Cancel just this hangout",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.pop(ctx, 'single'),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_delete, color: Colors.red),
                  title: const Text(
                    "Cancel this and all future hangouts",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, 'future'),
                ),
              ],
            ),
          ),
        ),
      );

      if (scope == null) return;
      deleteScope = scope;
    } else {
      final content = isVibeCheck
          ? "This will permanently delete the feeler, the votes, and the chat history."
          : "Are you sure you want to permanently delete this hangout? This action cannot be undone.";

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(
                "Delete",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final successMessage = isVibeCheck
        ? "Vibe Check deleted permanently."
        : (deleteScope == 'future'
              ? "Season deleted permanently."
              : "Hangout deleted permanently.");

    onLoadingChanged(true);
    try {
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
}
