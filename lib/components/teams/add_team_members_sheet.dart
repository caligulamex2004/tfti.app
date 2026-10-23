import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tftiapp/services/contact_resolver.dart';
import 'package:tftiapp/services/contact_service.dart';
import 'package:tftiapp/services/team_service.dart';
import 'package:tftiapp/services/user_cache_repository.dart';
import 'package:tftiapp/utils/theme_provider.dart';
import '../shared/app_avatar.dart';

class AddTeamMembersSheet extends StatefulWidget {
  final String circleId;
  final String circleName;
  final String userUid;
  final VoidCallback? onMembersAdded;

  const AddTeamMembersSheet({
    super.key,
    required this.circleId,
    required this.circleName,
    required this.userUid,
    this.onMembersAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String circleId,
    required String circleName,
    required String userUid,
    VoidCallback? onMembersAdded,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final allFriendsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userUid)
        .collection('friends')
        .get();

    final availableFriendDocs = allFriendsSnapshot.docs
        .where(
          (doc) => !List<String>.from(
            doc.data()['circles'] ?? [],
          ).contains(circleId),
        )
        .toList();

    if (!context.mounted) return;

    if (availableFriendDocs.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Everyone is already in here!")),
      );
      return;
    }

    final friendUids = availableFriendDocs.map((d) => d.id).toList();
    final userMap = await UserCacheRepository.instance.getUsers(friendUids);

    List<Map<String, dynamic>> sortedAvailable = [];
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
        sortedAvailable.add(data);
      }
    }

    String getEffectiveName(Map<String, dynamic> item) {
      final phone = item['phoneNumber'] as String?;
      final fallback = (item['displayName'] ?? '').toString();
      final firstName = ContactResolver.instance.resolveFirstName(
        phone,
        fallbackName: fallback,
      );
      if (firstName != null && firstName.trim().isNotEmpty) {
        return firstName.trim().toLowerCase();
      }
      return fallback.toLowerCase();
    }

    sortedAvailable.sort(
      (a, b) => getEffectiveName(a).compareTo(getEffectiveName(b)),
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddTeamMembersSheet(
        circleId: circleId,
        circleName: circleName,
        userUid: userUid,
        onMembersAdded: onMembersAdded,
      ),
    );
  }

  @override
  State<AddTeamMembersSheet> createState() => _AddTeamMembersSheetState();
}

class _AddTeamMembersSheetState extends State<AddTeamMembersSheet> {
  final Set<String> _selectedIds = {};
  List<Map<String, dynamic>> _sortedAvailable = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableFriends();
  }

  Future<void> _loadAvailableFriends() async {
    final allFriendsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('friends')
        .get();

    final availableFriendDocs = allFriendsSnapshot.docs
        .where(
          (doc) => !List<String>.from(
            doc.data()['circles'] ?? [],
          ).contains(widget.circleId),
        )
        .toList();

    final friendUids = availableFriendDocs.map((d) => d.id).toList();
    final userMap = await UserCacheRepository.instance.getUsers(friendUids);

    List<Map<String, dynamic>> list = [];
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
      final firstName = ContactResolver.instance.resolveFirstName(
        phone,
        fallbackName: fallback,
      );
      if (firstName != null && firstName.trim().isNotEmpty) {
        return firstName.trim().toLowerCase();
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
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Add to ${widget.circleName}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListenableBuilder(
                      listenable: ContactResolver.instance,
                      builder: (context, _) {
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: _sortedAvailable.length,
                          itemBuilder: (context, index) {
                            final profile = _sortedAvailable[index];
                            final uid = profile['uid'];
                            final isSelected = _selectedIds.contains(uid);
                            final displayName =
                                profile['displayName'] ?? "Unknown";
                            final username = profile['username'] ?? "";
                            final rawPhone = profile['phoneNumber'] ?? "";
                            final contactName = ContactResolver.instance
                                .resolveName(rawPhone);
                            final bool hasContactName =
                                contactName != null &&
                                contactName.trim().isNotEmpty;
                            final String primaryName =
                                ContactResolver.instance.resolveFirstName(
                                      rawPhone,
                                      fallbackName: displayName,
                                    ) ??
                                    ContactHelper.extractFirstName(displayName);
                            final avatarUrl = profile['avatarUrl'];
                            final avatarColor = Color(
                              profile['avatarColor'] is int
                                  ? profile['avatarColor']
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
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await TeamService.addMembersToTeam(
                            uid: widget.userUid,
                            circleId: widget.circleId,
                            memberUids: _selectedIds.toList(),
                          );
                          widget.onMembersAdded?.call();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Added ${_selectedIds.length} friends!",
                                ),
                              ),
                            );
                          }
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
                        ? "Select Friends"
                        : "Add ${_selectedIds.length} to Team",
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
