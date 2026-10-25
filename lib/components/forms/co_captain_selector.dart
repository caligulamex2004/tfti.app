import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../shared/app_avatar.dart';

class CoCaptainSelector extends StatelessWidget {
  final bool isPast;
  final bool inviteAll;
  final List<String> selectedCircleIds;
  final List<String> lastMinuteInviteIds;
  final String? coHostId;
  final String? coHostName;
  final String? coHostUsername;
  final String? coHostAvatarUrl;
  final int? coHostAvatarColor;
  final Function(
    String? id,
    String? name,
    String? username,
    String? avatarUrl,
    int? avatarColor,
  )
  onChanged;

  const CoCaptainSelector({
    super.key,
    required this.isPast,
    required this.inviteAll,
    required this.selectedCircleIds,
    this.lastMinuteInviteIds = const [],
    required this.coHostId,
    required this.coHostName,
    required this.coHostUsername,
    required this.coHostAvatarUrl,
    required this.coHostAvatarColor,
    required this.onChanged,
  });

  void _showSelectionSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return FractionallySizedBox(
          heightFactor: 0.7,
          child: SafeArea(
            child: Column(
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
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Assign Co-Captain",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person_off, color: Colors.white),
                  ),
                  title: const Text(
                    "None",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    onChanged(null, null, null, null, null);
                    Navigator.pop(ctx);
                  },
                ),
                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('friends')
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allFriends = snapshot.data!.docs;
                      final friends = allFriends.where((doc) {
                        if (inviteAll) {
                          return true;
                        }
                        if (lastMinuteInviteIds.contains(doc.id)) {
                          return true;
                        }
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final friendCircles = List<String>.from(
                          data['circles'] ?? [],
                        );
                        for (String circleId in selectedCircleIds) {
                          if (friendCircles.contains(circleId)) {
                            return true;
                          }
                        }
                        return false;
                      }).toList();

                      if (friends.isEmpty) {
                        return const Center(
                          child: Text(
                            "No eligible friends found in the selected teams.",
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friendId = friends[index].id;
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(friendId)
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData || !userSnap.data!.exists) {
                                return const SizedBox.shrink();
                              }
                              final data =
                                  userSnap.data!.data() as Map<String, dynamic>;
                              final name = data['displayName'] ?? 'Unknown';
                              final username = data['username'] ?? '';
                              final avatarUrl = data['avatarUrl'];
                              final avatarColorVal = data['avatarColor'] is int
                                  ? data['avatarColor']
                                  : Colors.blue.toARGB32();
                              final avatarColor = Color(avatarColorVal);

                              return ListTile(
                                leading: AppAvatar(
                                  avatarColor: avatarColor,
                                  avatarUrl: avatarUrl,
                                  displayName: name,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: username.isNotEmpty
                                    ? Text(
                                        "@$username",
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  onChanged(
                                    friendId,
                                    name,
                                    username,
                                    avatarUrl,
                                    avatarColorVal,
                                  );
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Opacity(
      opacity: (inviteAll || selectedCircleIds.isNotEmpty) ? 1.0 : 0.5,
      child: InkWell(
        onTap: isPast
            ? null
            : () {
                if (!inviteAll && selectedCircleIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please select a Team or Entire Squad first.",
                      ),
                    ),
                  );
                  return;
                }
                _showSelectionSheet(context);
              },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              if (coHostId == null)
                Icon(Symbols.shield_person, color: primaryColor, size: 40)
              else
                AppAvatar.fromColorValue(
                  radius: 20,
                  avatarColor: coHostAvatarColor,
                  avatarUrl: coHostAvatarUrl,
                  displayName: coHostName ?? "?",
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Co-Captain",
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      coHostName ?? "None Assigned",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (coHostUsername != null && coHostUsername!.isNotEmpty)
                      Text(
                        "@$coHostUsername",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
