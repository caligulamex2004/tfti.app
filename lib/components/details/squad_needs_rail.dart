import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../forms/squad_needs_sheet.dart';

/// Horizontal task board carousel for event squad needs / roles.
/// Allows attendees to claim or release needs directly on the details page,
/// and allows hosts/co-hosts to add needs on the fly.
class SquadNeedsRail extends StatelessWidget {
  final String eventId;
  final String hostId;
  final bool canEdit;
  final bool isPast;

  const SquadNeedsRail({
    super.key,
    required this.eventId,
    required this.hostId,
    required this.canEdit,
    required this.isPast,
  });

  void _openSquadNeedsSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SquadNeedsSheet(
        eventId: eventId,
        hostId: hostId,
        isPast: isPast,
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context, Color primaryColor) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Squad Need"),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: "e.g. Bag of Ice, Speaker, Driver",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              await FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .collection('roles')
                  .add({
                    'title': text,
                    'addedBy': user.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _claimNeed(
    DocumentSnapshot roleDoc,
    User currentUser,
  ) async {
    HapticFeedback.lightImpact();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final displayName =
        userDoc.data()?['displayName'] ?? currentUser.displayName ?? "Someone";

    await roleDoc.reference.update({
      'claimedByUid': currentUser.uid,
      'claimedByName': displayName,
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _unclaimNeed(DocumentSnapshot roleDoc) async {
    HapticFeedback.lightImpact();
    await roleDoc.reference.update({
      'claimedByUid': FieldValue.delete(),
      'claimedByName': FieldValue.delete(),
      'claimedAt': FieldValue.delete(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) return const SizedBox.shrink();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('roles')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final roles = snapshot.data!.docs;

        // If no roles exist and user cannot edit, collapse cleanly
        if (roles.isEmpty && !canEdit) {
          return const SizedBox.shrink();
        }

        final int claimedCount = roles.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['claimedByUid'] != null;
        }).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_box_outlined,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            "SQUAD NEEDS",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (roles.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: claimedCount == roles.length
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "$claimedCount/${roles.length} Claimed",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: claimedCount == roles.length
                                      ? Colors.green
                                      : primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _openSquadNeedsSheet(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Manage",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 11,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),

              // Horizontal Rail Content
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: roles.isEmpty
                    ? _buildEmptyPrompt(context, isDark, primaryColor)
                    : _buildRolesRail(
                        context,
                        roles,
                        currentUser,
                        isDark,
                        primaryColor,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyPrompt(
    BuildContext context,
    bool isDark,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.pan_tool_outlined,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Need help bringing ice, snacks, or games?",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showQuickAddDialog(context, primaryColor),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              "Add",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesRail(
    BuildContext context,
    List<QueryDocumentSnapshot> roles,
    User currentUser,
    bool isDark,
    Color primaryColor,
  ) {
    // Add 1 extra slot for [+ Add Need] card if user can edit
    final int itemCount = roles.length + (canEdit && !isPast ? 1 : 0);

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // If this is the trailing [+ Add Need] card
          if (index == roles.length) {
            return _buildAddNeedCard(context, isDark, primaryColor);
          }

          final roleDoc = roles[index];
          final roleData = roleDoc.data() as Map<String, dynamic>;
          final title = roleData['title'] ?? 'Item';
          final assigneeId = roleData['claimedByUid'];
          final assigneeName = roleData['claimedByName'] ?? 'Someone';

          final bool isClaimed = assigneeId != null;
          final bool isMe = assigneeId == currentUser.uid;

          return Container(
            width: 154,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isClaimed
                  ? (isDark
                      ? Colors.grey.shade900.withValues(alpha: 0.5)
                      : Colors.green.shade50.withValues(alpha: 0.4))
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isClaimed
                    ? Colors.green.withValues(alpha: isDark ? 0.3 : 0.4)
                    : (isDark
                        ? Colors.grey.shade700
                        : Colors.grey.shade200),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: Status badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isClaimed
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isClaimed ? Icons.check : Icons.hourglass_top,
                            size: 10,
                            color: isClaimed ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isClaimed ? "Claimed" : "Open",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isClaimed ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Middle: Title & Assignee
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isClaimed
                            ? (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700)
                            : (isDark ? Colors.white : Colors.black87),
                        decoration: isClaimed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isClaimed
                          ? (isMe ? "by You ✓" : "by $assigneeName")
                          : "Be a squad hero",
                      style: TextStyle(
                        fontSize: 10,
                        color: isClaimed
                            ? (isMe
                                ? primaryColor
                                : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600))
                            : (isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500),
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),

                // Bottom: Action Button
                if (!isClaimed && !isPast)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _claimNeed(roleDoc, currentUser),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Claim",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (isMe && !isPast)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: OutlinedButton(
                      onPressed: () => _unclaimNeed(roleDoc),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        "Release",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddNeedCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showQuickAddDialog(context, primaryColor),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey.shade900.withValues(alpha: 0.3)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.4),
            width: 1.2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: primaryColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              "Add Need",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
