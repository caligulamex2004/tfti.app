import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// A standalone widget you can pass to showModalBottomSheet. It manages its own
// stream and strictly enforces the security rules we built earlier.
class SquadNeedsSheet extends StatefulWidget {
  final String eventId;
  final String hostId;
  final bool isPast;

  const SquadNeedsSheet({
    super.key,
    required this.eventId,
    required this.hostId,
    required this.isPast,
  });

  @override
  State<SquadNeedsSheet> createState() => _SquadNeedsSheetState();
}

class _SquadNeedsSheetState extends State<SquadNeedsSheet> {
  final _roleController = TextEditingController();

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _addNeed(String currentUserId) async {
    final title = _roleController.text.trim();
    if (title.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('roles')
        .add({
          'title': title,
          'addedBy': currentUserId, // Secure stamp
          'createdAt': FieldValue.serverTimestamp(),
        });

    _roleController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUser = FirebaseAuth.instance.currentUser!;
    final bool canEdit = !widget.isPast;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  children: [
                    Icon(
                      Icons.check_box_outlined,
                      color: primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Squad Needs",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // The Stream
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .doc(widget.eventId)
                      .collection('roles')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final roles = snapshot.data!.docs;

                    if (roles.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volunteer_activism,
                              size: 48,
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              canEdit
                                  ? "Add items you need help with!"
                                  : "No squad needs were added.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: roles.length,
                      itemBuilder: (context, index) {
                        final roleDoc = roles[index];
                        final roleData = roleDoc.data() as Map<String, dynamic>;
                        final title = roleData['title'] ?? 'Item';
                        final assigneeId = roleData['claimedByUid'];
                        final assigneeName = roleData['claimedByName'];
                        final addedBy = roleData['addedBy'];

                        final isClaimed = assigneeId != null;
                        final isMe = assigneeId == currentUser.uid;

                        // Secure Permissions
                        final isMainHost = widget.hostId == currentUser.uid;
                        final isItemCreator = addedBy == currentUser.uid;
                        final canManageItem = isMainHost || isItemCreator;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isClaimed
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : (isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade100),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isClaimed ? Icons.check : Icons.pan_tool_outlined,
                              color: isClaimed
                                  ? Colors.green
                                  : (isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isClaimed
                                  ? (isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade500)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          subtitle: isClaimed
                              ? Text(
                                  isMe
                                      ? "Claimed by you"
                                      : "Claimed by $assigneeName",
                                  style: TextStyle(
                                    color: isMe
                                        ? primaryColor
                                        : (isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600),
                                    fontWeight: isMe
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isClaimed && canEdit)
                                ElevatedButton(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final userDoc = await FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(currentUser.uid)
                                        .get();
                                    await roleDoc.reference.update({
                                      'claimedByUid': currentUser.uid,
                                      'claimedByName':
                                          userDoc.data()?['displayName'] ??
                                          "Someone",
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    "Claim",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if ((isMe || canManageItem) && canEdit)
                                OutlinedButton(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    await roleDoc.reference.update({
                                      'claimedByUid': FieldValue.delete(),
                                      'claimedByName': FieldValue.delete(),
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(isMe ? "Unclaim" : "Unassign"),
                                ),
                              if (canManageItem && canEdit)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    roleDoc.reference.delete();
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Bottom Input Bar
              if (canEdit) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _roleController,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _addNeed(currentUser.uid),
                          decoration: InputDecoration(
                            hintText: "Add a new need (e.g. Bring Ice)",
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => _addNeed(currentUser.uid),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
