import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EventService {
  static Future<void> deleteEventWithConfirmation({
    required BuildContext context,
    required String eventId,
    required bool isVibeCheck,
    required ValueChanged<bool> onLoadingChanged,
  }) async {
    final title = isVibeCheck ? "Delete Vibe Check?" : "Delete Hangout?";
    final content = isVibeCheck
        ? "This will permanently delete the feeler, the votes, and the chat history."
        : "Are you sure you want to permanently delete this hangout? This action cannot be undone.";
    final successMessage = isVibeCheck
        ? "Vibe Check deleted permanently."
        : "Hangout deleted permanently.";

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

    if (confirm == true) {
      onLoadingChanged(true);
      try {
        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(eventId);

        final batch = FirebaseFirestore.instance.batch();

        // Subcollection 1: Invitations
        final invitesSnap = await eventRef.collection('invitations').get();
        for (var doc in invitesSnap.docs) {
          batch.delete(doc.reference);
        }

        // Subcollection 2: Messages
        final messagesSnap = await eventRef.collection('messages').get();
        for (var doc in messagesSnap.docs) {
          batch.delete(doc.reference);
        }

        // Subcollection 3: Roles (Safe to run even if Vibe Checks don't use it yet)
        final rolesSnap = await eventRef.collection('roles').get();
        for (var doc in rolesSnap.docs) {
          batch.delete(doc.reference);
        }

        // Finally: Delete the main event document
        batch.delete(eventRef);

        await batch.commit();

        // Remove banner image if it exists to save storage space
        try {
          await FirebaseStorage.instance
              .ref()
              .child('event_banners/$eventId/banner.jpg')
              .delete();
        } catch (_) {}

        // Cleanup all chat images in the chat_images folder
        try {
          final chatImagesRef = FirebaseStorage.instance.ref().child(
            'chat_images/$eventId',
          );
          final listResult = await chatImagesRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
        } catch (_) {}

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
}
