import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/contact_resolver.dart';
import '../../services/contact_service.dart';
import '../shared/app_avatar.dart';

class TeamAvatarStack extends StatelessWidget {
  final String myUid;
  final String circleId;

  const TeamAvatarStack({
    super.key,
    required this.myUid,
    required this.circleId,
  });

  Future<List<Map<String, dynamic>>> _getValidFacepileMembers(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> validProfiles = [];
    for (var doc in docs) {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(doc.id)
          .get();
      if (userSnap.exists) {
        final data = userSnap.data() as Map<String, dynamic>;
        final friendData = doc.data() as Map<String, dynamic>? ?? {};
        data['uid'] = doc.id;
        data['phoneNumber'] = ContactHelper.pickPhone([
          friendData['phoneNumber'],
          data['phoneNumber'],
        ]);
        validProfiles.add(data);
      }
      if (validProfiles.length >= 4) {
        break;
      }
    }
    return validProfiles;
  }

  Widget _buildEmptyIcon(Color primaryColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Symbols.circles, color: primaryColor, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (Firebase.apps.isEmpty) {
      return _buildEmptyIcon(primaryColor);
    }

    return ListenableBuilder(
      listenable: ContactResolver.instance,
      builder: (context, _) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(myUid)
              .collection('friends')
              .where('circles', arrayContains: circleId)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyIcon(primaryColor);
            }

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getValidFacepileMembers(snapshot.data!.docs),
              builder: (context, validSnap) {
                if (!validSnap.hasData || validSnap.data!.isEmpty) {
                  return _buildEmptyIcon(primaryColor);
                }

                final validDocs = validSnap.data!;
                final int count = validDocs.length;
                final displayDocs = validDocs.take(3).toList();
                final bool hasMore = count > 3;

                return SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    children: [
                      ...displayDocs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final uData = entry.value;

                        final String displayName =
                            uData['displayName'] ?? "Unknown";
                        final String rawPhone = uData['phoneNumber'] ?? "";
                        final String? contactName = ContactResolver.instance
                            .resolveName(rawPhone);
                        final String name =
                            (contactName != null &&
                                contactName.trim().isNotEmpty)
                            ? contactName.trim()
                            : displayName;
                        String? avatarUrl = uData['avatarUrl'];
                        int avatarColor =
                            uData['avatarColor'] ?? Colors.blue.toARGB32();

                        Widget avatar = Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: AppAvatar.fromColorValue(
                            avatarColor: avatarColor,
                            avatarUrl: avatarUrl,
                            displayName: name,
                            fontSize: count == 1 ? 20 : 11,
                          ),
                        );

                        if (count == 1) {
                          return Positioned.fill(child: avatar);
                        }
                        if (count == 2) {
                          if (index == 0) {
                            return Positioned(
                              top: 0,
                              right: 0,
                              width: 32,
                              height: 32,
                              child: avatar,
                            );
                          }
                          return Positioned(
                            bottom: 0,
                            left: 0,
                            width: 32,
                            height: 32,
                            child: avatar,
                          );
                        }
                        if (index == 0) {
                          return Positioned(
                            top: 0,
                            left: 10,
                            width: 28,
                            height: 28,
                            child: avatar,
                          );
                        }
                        if (index == 1) {
                          return Positioned(
                            bottom: 0,
                            left: 0,
                            width: 28,
                            height: 28,
                            child: avatar,
                          );
                        }
                        return Positioned(
                          bottom: 0,
                          right: 0,
                          width: 28,
                          height: 28,
                          child: avatar,
                        );
                      }),
                      if (hasMore)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              "+",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
