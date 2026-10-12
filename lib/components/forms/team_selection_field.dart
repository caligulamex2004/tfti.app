import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/team_members_page.dart';

// This encapsulates the complex StreamBuilder, the Teams Dialog, and the
// Impromptu Team Creation logic.
class TeamSelectionField extends StatefulWidget {
  final bool inviteAll;
  final List<String> selectedCircleIds;
  final bool enabled;
  // Passes the updated values back to the parent form when closed
  final Function(bool newInviteAll, List<String> newSelectedIds) onChanged;

  const TeamSelectionField({
    super.key,
    required this.inviteAll,
    required this.selectedCircleIds,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<TeamSelectionField> createState() => _TeamSelectionFieldState();
}

class _TeamSelectionFieldState extends State<TeamSelectionField> {
  late bool _localInviteAll;
  late List<String> _localSelectedIds;

  @override
  void initState() {
    super.initState();
    _localInviteAll = widget.inviteAll;
    _localSelectedIds = List.from(widget.selectedCircleIds);
  }

  void _showCreateCircleImpromptu() {
    final nameController = TextEditingController();
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Team"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: "e.g. Work Besties",
            border: OutlineInputBorder(),
            counterText: "",
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
              if (nameController.text.trim().isEmpty) return;
              final user = FirebaseAuth.instance.currentUser!;

              final docRef = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('circles')
                  .add({
                    'name': nameController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

              if (!ctx.mounted) return;
              Navigator.pop(ctx); // Close Create Dialog

              if (!mounted) return;
              Navigator.pop(context); // Close Update Dialog

              setState(() {
                _localSelectedIds.add(docRef.id);
                _localInviteAll = false;
              });
              widget.onChanged(_localInviteAll, _localSelectedIds);

              // Navigate to add members
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamMembersPage(
                    // Use your actual Teams Page Class
                    circleId: docRef.id,
                    circleName: nameController.text.trim(),
                    autoOpenAddMembers: true,
                  ),
                ),
              );
            },
            child: const Text("Create"),
          ),
        ],
      ),
    ).then((_) => nameController.dispose());
  }

  void _showCircleDialog(List<DocumentSnapshot> circles) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Update The Crew"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      activeThumbColor: primaryColor,
                      title: const Text(
                        "Entire Squad",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _localInviteAll,
                      onChanged: (val) {
                        setDialogState(() {
                          _localInviteAll = val;
                          if (val) _localSelectedIds.clear();
                        });
                      },
                    ),
                    Divider(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                    if (circles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No teams created yet."),
                      ),
                    ...circles.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isChecked = _localSelectedIds.contains(doc.id);
                      return SwitchListTile(
                        activeThumbColor: primaryColor,
                        title: Text(data['name'] ?? 'Unnamed'),
                        value: isChecked,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val) {
                              _localSelectedIds.add(doc.id);
                              _localInviteAll = false;
                            } else {
                              _localSelectedIds.remove(doc.id);
                              if (_localSelectedIds.isEmpty) {
                                _localInviteAll = true;
                              }
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 8),
                    Divider(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.add_circle_outline,
                        color: primaryColor,
                      ),
                      title: Text(
                        "New Team",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: _showCreateCircleImpromptu,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    widget.onChanged(_localInviteAll, _localSelectedIds);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    "Done",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('circles')
          .snapshots(),
      builder: (context, snapshot) {
        final circles = snapshot.hasData
            ? snapshot.data!.docs.toList()
            : <DocumentSnapshot>[];
        circles.sort(
          (a, b) => ((a.data() as Map)['name'] ?? '').compareTo(
            (b.data() as Map)['name'] ?? '',
          ),
        );

        String targetPreviewText = "Select Squads...";
        if (_localInviteAll) {
          targetPreviewText = "Entire Squad";
        } else if (_localSelectedIds.isNotEmpty) {
          final selectedNames = circles
              .where((c) => _localSelectedIds.contains(c.id))
              .map(
                (c) => (c.data() as Map<String, dynamic>)['name'] ?? 'Unnamed',
              )
              .join(', ');
          targetPreviewText = selectedNames.isNotEmpty
              ? selectedNames
              : "Selected Teams";
        }

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: !widget.enabled ? null : () => _showCircleDialog(circles),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: "Update Squad List",
              prefixIcon: Icon(
                Icons.people,
                color: isDark ? Colors.tealAccent : Colors.teal,
              ),
              suffixIcon: const Icon(Icons.arrow_drop_down),
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
            child: Text(
              targetPreviewText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
