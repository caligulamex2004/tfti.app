import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_provider.dart';

class EventRolesPage extends StatefulWidget {
  final String eventId;
  final bool
  isHost; // Used to determine if the user can view the "Add" text input

  const EventRolesPage({
    super.key,
    required this.eventId,
    required this.isHost,
  });

  @override
  State<EventRolesPage> createState() => _EventRolesPageState();
}

class _EventRolesPageState extends State<EventRolesPage> {
  final _roleController = TextEditingController();

  // --- NEW: TRACK MAIN HOST FOR DELETE PERMISSIONS ---
  String? _mainHostId;

  @override
  void initState() {
    super.initState();
    _fetchMainHost();
  }

  Future<void> _fetchMainHost() async {
    final doc = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _mainHostId = doc.data()?['hostId'];
      });
    }
  }

  Future<void> _addRole() async {
    if (_roleController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('roles')
        .add({
          'title': _roleController.text.trim(),
          'addedBy': user.uid, // <-- NEW: STAMP OWNERSHIP
          'claimedByUid': null,
          'claimedByName': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

    _roleController.clear();
  }

  Future<void> _deleteRole(String roleId) async {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('roles')
        .doc(roleId)
        .delete();
  }

  Future<void> _toggleClaim(
    String roleId,
    String? currentClaimantUid,
    String? currentClaimantName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('roles')
        .doc(roleId);

    if (currentClaimantUid == user.uid) {
      await docRef.update({'claimedByUid': null, 'claimedByName': null});
    } else if (currentClaimantUid == null) {
      final myName = user.displayName ?? "A Guest";
      await docRef.update({'claimedByUid': user.uid, 'claimedByName': myName});
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Already claimed by $currentClaimantName")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Squad Needs (Dibs)"),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: Column(
        children: [
          if (widget.isHost)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _roleController,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "e.g. Bring a Bluetooth speaker",
                        counterText: "",
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addRole,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: themeProvider.onPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                    child: const Text("Add"),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(widget.eventId)
                  .collection('roles')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist_rtl,
                          size: 60,
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isHost
                              ? "Add items you need help with above!"
                              : "The host hasn't added any roles yet.",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final roles = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: roles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = roles[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final roleId = doc.id;
                    final title = data['title'] ?? 'Role';
                    final claimedByUid = data['claimedByUid'];
                    final claimedByName = data['claimedByName'];

                    // --- NEW: READ OWNERSHIP ---
                    final addedBy = data['addedBy'];

                    final bool isMine = claimedByUid == myUid;
                    final bool isClaimed = claimedByUid != null;

                    // --- NEW: DELETE PERMISSION ENGINE ---
                    // The Main Host can delete anything. The Co-Host can only delete what they added!
                    final bool isMainHost = _mainHostId == myUid;
                    final bool canDelete = isMainHost || addedBy == myUid;

                    return Card(
                      elevation: isDark ? 1 : 2,
                      color: isMine
                          ? primaryColor.withValues(alpha: 0.1)
                          : Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isMine
                            ? BorderSide(color: primaryColor, width: 1.5)
                            : (isDark
                                  ? BorderSide(color: Colors.grey.shade800)
                                  : BorderSide.none),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isMine
                              ? Icons.check_circle
                              : (isClaimed
                                    ? Icons.person
                                    : Icons.radio_button_unchecked),
                          color: isMine
                              ? primaryColor
                              : (isClaimed ? Colors.grey : primaryColor),
                          size: 28,
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isClaimed && !isMine
                                ? Colors.grey
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        subtitle: Text(
                          isMine
                              ? "Claimed by you"
                              : (isClaimed
                                    ? "Claimed by $claimedByName"
                                    : "Unclaimed"),
                          style: TextStyle(
                            color: isMine
                                ? primaryColor
                                : (isClaimed
                                      ? Colors.grey
                                      : (isDark
                                            ? Colors.grey.shade400
                                            : Colors.black54)),
                            fontWeight: isMine
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        // --- NEW: ONLY RENDER TRASHCAN IF AUTHORIZED ---
                        trailing: (widget.isHost && canDelete)
                            ? IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: isDark ? Colors.redAccent : Colors.red,
                                ),
                                onPressed: () => _deleteRole(roleId),
                              )
                            : null,
                        onTap: () =>
                            _toggleClaim(roleId, claimedByUid, claimedByName),
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
