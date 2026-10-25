import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tftiapp/services/contact_resolver.dart';
import 'package:tftiapp/services/contact_service.dart';
import 'package:tftiapp/services/user_cache_repository.dart';
import 'package:tftiapp/utils/theme_provider.dart';
import '../shared/app_avatar.dart';

class LastMinuteInviteSheet extends StatefulWidget {
  final String userUid;
  final List<String> selectedCircleIds;
  final List<String> initialSelectedIds;
  final Set<String> excludeUids;
  final ValueChanged<List<String>> onSaved;

  const LastMinuteInviteSheet({
    super.key,
    required this.userUid,
    required this.selectedCircleIds,
    required this.initialSelectedIds,
    this.excludeUids = const {},
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String userUid,
    required List<String> selectedCircleIds,
    required List<String> initialSelectedIds,
    Set<String> excludeUids = const {},
    required ValueChanged<List<String>> onSaved,
  }) async {
    ContactResolver.instance.warmUpIfPermitted();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => LastMinuteInviteSheet(
        userUid: userUid,
        selectedCircleIds: selectedCircleIds,
        initialSelectedIds: initialSelectedIds,
        excludeUids: excludeUids,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<LastMinuteInviteSheet> createState() => _LastMinuteInviteSheetState();
}

class _LastMinuteInviteSheetState extends State<LastMinuteInviteSheet> {
  late final Set<String> _selectedIds;
  List<Map<String, dynamic>> _sortedAvailable = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
    _loadEligibleFriends();
  }

  Future<void> _loadEligibleFriends() async {
    try {
      final allFriendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('friends')
          .get();

      // Exclude friends who are already invited via the selected Team(s)
      final availableFriendDocs = allFriendsSnapshot.docs.where((doc) {
        if (widget.excludeUids.contains(doc.id)) return false;
        final friendCircles = List<String>.from(doc.data()['circles'] ?? []);
        final isAlreadyInSelectedTeam = widget.selectedCircleIds.any(
          (circleId) => friendCircles.contains(circleId),
        );
        return !isAlreadyInSelectedTeam;
      }).toList();

      final availableIdsSet = availableFriendDocs.map((d) => d.id).toSet();
      _selectedIds.removeWhere((id) => !availableIdsSet.contains(id));

      final friendUids = availableFriendDocs.map((d) => d.id).toList();
      final userMap = await UserCacheRepository.instance.getUsers(friendUids);

      final List<Map<String, dynamic>> list = [];
      for (final doc in availableFriendDocs) {
        final profile = userMap[doc.id];
        if (profile != null) {
          final data = profile.toMap();
          data['uid'] = doc.id;
          final docData = doc.data();
          final phone = ContactHelper.pickPhone([
            docData['phoneNumber'],
            data['phoneNumber'],
          ]);
          data['phoneNumber'] = phone;
          list.add(data);
        }
      }

      String getEffectiveName(Map<String, dynamic> item) {
        final phone = item['phoneNumber'] as String?;
        final fallback = (item['displayName'] ?? '').toString();
        final resolvedName = ContactResolver.instance.resolveMiniProfileName(
          phone,
          fallbackName: fallback,
        );
        if (resolvedName != null && resolvedName.trim().isNotEmpty) {
          return resolvedName.trim().toLowerCase();
        }
        return fallback.toLowerCase();
      }

      list.sort((a, b) => getEffectiveName(a).compareTo(getEffectiveName(b)));

      if (mounted) {
        setState(() {
          _sortedAvailable = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Last Minute Invite",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedIds.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedIds.clear());
                          },
                          child: const Text("Clear All"),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Select one or more to join the Crew on this one.",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sortedAvailable.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 52,
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Everyone in your squad is already in the selected team(s)!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListenableBuilder(
                      listenable: ContactResolver.instance,
                      builder: (context, _) {
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: _sortedAvailable.length,
                          itemBuilder: (context, index) {
                            final profile = _sortedAvailable[index];
                            final uid = profile['uid'] as String;
                            final isSelected = _selectedIds.contains(uid);
                            final displayName =
                                (profile['displayName'] ?? "Unknown")
                                    .toString();
                            final username = (profile['username'] ?? "")
                                .toString();
                            final rawPhone = (profile['phoneNumber'] ?? "")
                                .toString();
                            final contactName = ContactResolver.instance
                                .resolveName(rawPhone);
                            final bool hasContactName =
                                contactName != null &&
                                contactName.trim().isNotEmpty;
                            final String primaryName =
                                ContactResolver.instance.resolveMiniProfileName(
                                  rawPhone,
                                  fallbackName: displayName,
                                ) ??
                                ContactResolver.instance
                                    .formatMiniProfileFallback(displayName);
                            final avatarUrl = profile['avatarUrl'] as String?;
                            final avatarColor = Color(
                              profile['avatarColor'] is int
                                  ? profile['avatarColor'] as int
                                  : Colors.grey.toARGB32(),
                            );

                            String? subtitleText;
                            if (hasContactName &&
                                displayName.isNotEmpty &&
                                displayName != primaryName) {
                              subtitleText =
                                  "~ $displayName${username.isNotEmpty ? ' (@$username)' : ''}";
                            } else if (username.isNotEmpty) {
                              subtitleText = "@$username";
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: avatarColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: AppAvatar(
                                  avatarColor: avatarColor,
                                  radius: 20,
                                  avatarUrl: avatarUrl,
                                  displayName: primaryName,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      primaryName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasContactName)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Tooltip(
                                        message: "From your contacts",
                                        child: Icon(
                                          Icons.contact_phone_outlined,
                                          size: 14,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: subtitleText != null
                                  ? Text(
                                      subtitleText,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: primaryColor,
                                      size: 28,
                                    )
                                  : Icon(
                                      Icons.circle_outlined,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                      size: 28,
                                    ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(uid);
                                  } else {
                                    _selectedIds.add(uid);
                                  }
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isSaving)
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          setState(() => _isSaving = true);
                          final updated = _selectedIds.toList();
                          Navigator.pop(context);
                          widget.onSaved(updated);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: themeProvider.onPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selectedIds.isEmpty
                        ? "Save (None Selected)"
                        : "Save (${_selectedIds.length} Selected)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
