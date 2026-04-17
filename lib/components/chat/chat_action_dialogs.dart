import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- SQUAD DIBS SHEET ---
class SquadDibsSheet extends StatelessWidget {
  final String eventId;
  final Function(String roleTitle) onClaimed;

  const SquadDibsSheet({
    super.key,
    required this.eventId,
    required this.onClaimed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Squad Needs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .collection('roles')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final roles = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['claimedByUid'] == null;
                }).toList();

                if (roles.isEmpty) {
                  return const Center(child: Text("Everything is covered! 🎉"));
                }

                return ListView.builder(
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final roleDoc = roles[index];
                    final roleData = roleDoc.data() as Map<String, dynamic>;

                    return ListTile(
                      leading: Icon(Icons.pan_tool, color: primaryColor),
                      title: Text(
                        roleData['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context); // Close the sheet

                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser.uid)
                              .get();
                          final myName =
                              userDoc.data()?['displayName'] ?? "Someone";

                          // Update the role in the database
                          await roleDoc.reference.update({
                            'claimedByUid': currentUser.uid,
                            'claimedByName': myName,
                          });

                          // Tell the chat page to send the announcement message
                          onClaimed(roleData['title']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text("Claim"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- BRING ITEM DIALOG ---
class BringItemDialog extends StatefulWidget {
  final String eventId;
  final Function(String itemTitle) onAnnounce;

  const BringItemDialog({
    super.key,
    required this.eventId,
    required this.onAnnounce,
  });

  @override
  State<BringItemDialog> createState() => _BringItemDialogState();
}

class _BringItemDialogState extends State<BringItemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("I'm bringing..."),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: "e.g. A pack of sodas"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              return;
            }

            Navigator.pop(context); // Close the dialog

            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) {
              return;
            }

            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            final myName = userDoc.data()?['displayName'] ?? "Someone";

            // Add the new role/item to the database
            await FirebaseFirestore.instance
                .collection('events')
                .doc(widget.eventId)
                .collection('roles')
                .add({
                  'title': text,
                  'createdAt': FieldValue.serverTimestamp(),
                  'addedBy': currentUser.uid,
                  'claimedByUid': currentUser.uid,
                  'claimedByName': myName,
                });

            // Tell the chat page to send the announcement message
            widget.onAnnounce(text);
          },
          child: const Text(
            "Announce",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
