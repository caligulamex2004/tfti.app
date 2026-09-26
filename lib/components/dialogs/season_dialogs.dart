import 'package:flutter/material.dart';
import 'package:tftiapp/models/hangout_submission_request.dart';

/// Clean dialog and bottom sheet helpers for recurring seasons and event deletion.
/// Keeps UI rendering logic strictly within the presentation layer.
class SeasonDialogs {
  /// Prompts the user whether to apply edits to this event only or all future events in the season.
  static Future<SeasonUpdateScope?> showUpdateSeasonScope(
    BuildContext context,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scopeStr = await showModalBottomSheet<String>(
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
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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

    if (scopeStr == null) return null;
    return SeasonUpdateScope.fromString(scopeStr);
  }

  /// Prompts the user before turning off recurring for an existing season.
  static Future<bool?> showTurnOffRecurringConfirmation(
    BuildContext context,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showModalBottomSheet<bool>(
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
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
  }

  /// Prompts the user before deleting an event or recurring season.
  /// Returns 'single', 'future', or null if cancelled.
  static Future<String?> showDeleteConfirmation(
    BuildContext context, {
    required bool isVibeCheck,
    required bool isRecurringSeason,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isRecurringSeason) {
      return await showModalBottomSheet<String>(
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
    } else {
      final title = isVibeCheck ? "Delete Vibe Check?" : "Delete Hangout?";
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

      return confirm == true ? 'single' : null;
    }
  }
}
