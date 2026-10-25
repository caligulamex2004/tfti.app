import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tftiapp/models/user_profile.dart';
import 'package:tftiapp/services/contact_resolver.dart';
import 'package:tftiapp/services/user_cache_repository.dart';
import 'last_minute_invite_sheet.dart';

class LastMinuteInviteField extends StatelessWidget {
  final bool inviteAll;
  final List<String> selectedCircleIds;
  final List<String> lastMinuteInviteIds;
  final bool enabled;
  final Set<String> excludeUids;
  final ValueChanged<List<String>> onChanged;
  final String? userUidOverride;

  const LastMinuteInviteField({
    super.key,
    required this.inviteAll,
    required this.selectedCircleIds,
    required this.lastMinuteInviteIds,
    required this.onChanged,
    this.enabled = true,
    this.excludeUids = const {},
    this.userUidOverride,
  });

  static void showInfoMessage(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("Select one or more to join the Crew on this one."),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
  }

  Future<String> _resolveSelectedNames(List<String> uids) async {
    if (uids.isEmpty) return "None selected";
    try {
      final userMap = await UserCacheRepository.instance.getUsers(uids);
      final List<String> names = [];
      for (final uid in uids) {
        final UserProfile? profile = userMap[uid];
        if (profile != null) {
          final resolved =
              ContactResolver.instance.resolveMiniProfileName(
                profile.phoneNumber,
                fallbackName: profile.displayName,
              ) ??
              ContactResolver.instance.formatMiniProfileFallback(
                profile.displayName,
              );
          names.add(resolved);
        }
      }
      if (names.isEmpty) return "${uids.length} Selected";
      return names.join(', ');
    } catch (_) {
      return "${uids.length} Selected";
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUid =
        userUidOverride ?? FirebaseAuth.instance.currentUser?.uid;
    if (effectiveUid == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canSelect = !inviteAll && selectedCircleIds.isNotEmpty;

    String fallbackPreviewText = "None selected";
    if (inviteAll) {
      fallbackPreviewText = "Entire Squad Invited";
    } else if (selectedCircleIds.isEmpty) {
      fallbackPreviewText = "Select a Team first...";
    } else if (lastMinuteInviteIds.isNotEmpty) {
      fallbackPreviewText = "${lastMinuteInviteIds.length} Selected";
    }

    return Opacity(
      opacity: canSelect ? 1.0 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: !enabled
            ? null
            : () {
                if (inviteAll) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Entire Squad is selected — everyone is already invited!",
                        ),
                      ),
                    );
                  return;
                }
                if (selectedCircleIds.isEmpty) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text("Please select a Team first."),
                      ),
                    );
                  return;
                }
                HapticFeedback.lightImpact();
                LastMinuteInviteSheet.show(
                  context,
                  userUid: effectiveUid,
                  selectedCircleIds: selectedCircleIds,
                  initialSelectedIds: lastMinuteInviteIds,
                  excludeUids: excludeUids,
                  onSaved: onChanged,
                );
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: "Last Minute Invite",
            prefixIcon: Icon(
              Icons.person_add_alt_1,
              color: isDark ? Colors.tealAccent : Colors.teal,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  onPressed: () => showInfoMessage(context),
                ),
                const Icon(Icons.arrow_drop_down),
                const SizedBox(width: 8),
              ],
            ),
            filled: true,
            fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          child: (canSelect && lastMinuteInviteIds.isNotEmpty)
              ? FutureBuilder<String>(
                  future: _resolveSelectedNames(lastMinuteInviteIds),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? fallbackPreviewText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                )
              : Text(
                  fallbackPreviewText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}
