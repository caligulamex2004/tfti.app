import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EventService {
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

      if (scope == null) return; // User swiped down or tapped out
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
        : (deleteScope == 'future' ? "Season deleted permanently." : "Hangout deleted permanently.");

    onLoadingChanged(true);
    try {
      final firestore = FirebaseFirestore.instance;

      if (deleteScope == 'single') {
        final eventRef = firestore.collection('events').doc(eventId);
        final batch = firestore.batch();

        final invitesSnap = await eventRef.collection('invitations').get();
        for (var doc in invitesSnap.docs) batch.delete(doc.reference);

        final messagesSnap = await eventRef.collection('messages').get();
        for (var doc in messagesSnap.docs) batch.delete(doc.reference);

        final rolesSnap = await eventRef.collection('roles').get();
        for (var doc in rolesSnap.docs) batch.delete(doc.reference);

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
      } else if (deleteScope == 'future' && seasonId != null && eventTime != null) {
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
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.red,
          ),
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
