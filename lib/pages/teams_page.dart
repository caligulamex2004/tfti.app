import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/theme_provider.dart';
import '../components/shared/user_profile_sheet.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  String? _selectedCircleId;
  String? _selectedCircleName;
  bool _autoOpenNewCircle = false;

  void _showCreateTeamSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "New Team",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "e.g. Work Besties",
                      counterText: "",
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade50,
                      prefixIcon: Icon(Symbols.circles, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: primaryColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        final name = nameController.text.trim();
                        final user = FirebaseAuth.instance.currentUser!;

                        final docRef = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('circles')
                            .add({
                              'name': name,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;

                        if (MediaQuery.of(context).orientation ==
                            Orientation.landscape) {
                          setState(() {
                            _selectedCircleId = docRef.id;
                            _selectedCircleName = name;
                            _autoOpenNewCircle = true;
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CircleMembersPage(
                                circleId: docRef.id,
                                circleName: name,
                                autoOpenAddMembers: true,
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
                        elevation: 2,
                      ),
                      child: const Text(
                        "Create Team",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNoFriendsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.group_off_outlined, color: primaryColor, size: 28),
            const SizedBox(width: 10),
            const Text(
              "Empty Squad!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Teams are groups made up of people already in your Squad.\n\nHead over to the Squad tab and add some friends first before building a Team!",
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: themeProvider.onPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Got it!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateTeamTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final friendsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .limit(1)
          .get();
      if (friendsSnap.docs.isEmpty) {
        if (mounted) _showNoFriendsDialog();
        return;
      }
      _showCreateTeamSheet();
    } catch (e) {
      _showCreateTeamSheet();
    }
  }

  void _showRenameTeamSheet(String circleId, String currentName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final renameController = TextEditingController(text: currentName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Rename Team",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: renameController,
                    autofocus: true,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Team Name",
                      counterText: "",
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade50,
                      prefixIcon: Icon(Icons.edit, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: primaryColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = renameController.text.trim();
                        if (newName.isEmpty) return;
                        final user = FirebaseAuth.instance.currentUser;
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user!.uid)
                            .collection('circles')
                            .doc(circleId)
                            .update({'name': newName});

                        if (_selectedCircleId == circleId && mounted) {
                          setState(() => _selectedCircleName = newName);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: themeProvider.onPrimaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTeamOptionsSheet(String circleId, String currentName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
              const SizedBox(height: 24),
              Text(
                currentName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text(
                  "Rename Team",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameTeamSheet(circleId, currentName);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Delete Team",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Team?"),
                      content: Text(
                        "Are you sure you want to delete '$currentName'? Your friends will not be deleted from your account.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            "Delete",
                            style: TextStyle(
                              color: isDark ? Colors.redAccent : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final user = FirebaseAuth.instance.currentUser;
                    if (_selectedCircleId == circleId && mounted) {
                      setState(() {
                        _selectedCircleId = null;
                        _selectedCircleName = null;
                      });
                    }
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('circles')
                        .doc(circleId)
                        .delete();
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

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
        data['uid'] = doc.id;
        validProfiles.add(data);
      }
      if (validProfiles.length >= 4) break;
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

  Widget _buildiMessageStyleGroupIcon(
    String myUid,
    String circleId,
    bool isDark,
    Color primaryColor,
  ) {
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

                    String name = uData['displayName'] ?? "Unknown";
                    String? avatarUrl = uData['avatarUrl'];
                    int avatarColor =
                        uData['avatarColor'] ?? Colors.blue.toARGB32();

                    Widget avatar = Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Color(avatarColor),
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : "?",
                                style: TextStyle(
                                  fontSize: count == 1 ? 20 : 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    );

                    if (count == 1) return Positioned.fill(child: avatar);
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
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.touch_app,
              size: 64,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Select a Team to view members",
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.of(context).size.width > 600;

    Widget listContent = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('circles')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final circles = snapshot.data!.docs;

        if (circles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.supervised_user_circle_outlined,
                    size: 64,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "No Teams Yet",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create one to group your friends!",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 8.0 : 16.0,
            vertical: 16.0,
          ),
          itemCount: circles.length,
          itemBuilder: (context, index) {
            final data = circles[index].data() as Map<String, dynamic>;
            final circleId = circles[index].id;
            final circleName = data['name'] ?? 'Circle';
            final isSelected = isLandscape && _selectedCircleId == circleId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (isLandscape) {
                    setState(() {
                      _selectedCircleId = circleId;
                      _selectedCircleName = circleName;
                      _autoOpenNewCircle = false;
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CircleMembersPage(
                          circleId: circleId,
                          circleName: circleName,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 12.0 : 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.1)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (!isDark && !isSelected)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildiMessageStyleGroupIcon(
                        user.uid,
                        circleId,
                        isDark,
                        primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          circleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                        onPressed: () =>
                            _showTeamOptionsSheet(circleId, circleName),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Teams",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 40,
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: listContent,
                    floatingActionButton: FloatingActionButton(
                      onPressed: _handleCreateTeamTap,
                      backgroundColor: primaryColor,
                      foregroundColor: themeProvider.onPrimaryColor,
                      heroTag: "btn_create_circle",
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                Expanded(
                  flex: 60,
                  child:
                      _selectedCircleId != null && _selectedCircleName != null
                      ? CircleMembersPage(
                          key: ValueKey(_selectedCircleId),
                          circleId: _selectedCircleId!,
                          circleName: _selectedCircleName!,
                          autoOpenAddMembers: _autoOpenNewCircle,
                        )
                      : _buildPlaceholder(isDark),
                ),
              ],
            )
          : Scaffold(
              backgroundColor: Colors.transparent,
              body: listContent,
              floatingActionButton: FloatingActionButton(
                onPressed: _handleCreateTeamTap,
                backgroundColor: primaryColor,
                foregroundColor: themeProvider.onPrimaryColor,
                heroTag: "btn_create_circle",
                child: const Icon(Icons.add),
              ),
            ),
    );
  }
}

// --- CIRCLE MEMBERS SUBLIST ---

class CircleMembersPage extends StatefulWidget {
  final String circleId;
  final String circleName;
  final bool autoOpenAddMembers;

  const CircleMembersPage({
    super.key,
    required this.circleId,
    required this.circleName,
    this.autoOpenAddMembers = false,
  });

  @override
  State<CircleMembersPage> createState() => _CircleMembersPageState();
}

class _CircleMembersPageState extends State<CircleMembersPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAddMembers) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showAddMembersBottomSheet(),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndSortMembers(
    List<DocumentSnapshot> friendDocs,
  ) async {
    List<Map<String, dynamic>> profiles = [];
    await Future.wait(
      friendDocs.map((doc) async {
        final uid = doc.id;
        final friendData = doc.data() as Map<String, dynamic>? ?? {};
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          data['uid'] = uid;
          data['isGoated'] = friendData['isGoated'] ?? false;
          profiles.add(data);
        }
      }),
    );
    profiles.sort(
      (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
        (b['displayName'] ?? '').toString().toLowerCase(),
      ),
    );
    return profiles;
  }

  Future<bool> _removeMember(String friendUid, String friendName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove from Team?"),
        content: Text("Remove $friendName from ${widget.circleName}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.redAccent : Colors.red,
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('friends')
          .doc(friendUid)
          .update({
            'circles': FieldValue.arrayRemove([widget.circleId]),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$friendName removed from team!")),
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _showAddMembersBottomSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final allFriendsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('friends')
        .get();
    final availableFriendDocs = allFriendsSnapshot.docs
        .where(
          (doc) => !List<String>.from(
            doc.data()['circles'] ?? [],
          ).contains(widget.circleId),
        )
        .toList();

    if (!mounted) return;
    final sortedAvailable = await _fetchAndSortMembers(availableFriendDocs);

    if (!mounted) return;
    if (sortedAvailable.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Everyone is already in here!")),
      );
      return;
    }

    final Set<String> selectedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
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
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
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
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: sortedAvailable.length,
                        itemBuilder: (context, index) {
                          final profile = sortedAvailable[index];
                          final uid = profile['uid'];
                          final isSelected = selectedIds.contains(uid);
                          final name = profile['displayName'] ?? "Unknown";
                          final username = profile['username'] ?? "";
                          final avatarUrl = profile['avatarUrl'];
                          final avatarColor = Color(
                            profile['avatarColor'] is int
                                ? profile['avatarColor']
                                : Colors.grey.toARGB32(),
                          );

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
                              child: CircleAvatar(
                                backgroundColor: avatarColor,
                                radius: 20,
                                backgroundImage: avatarUrl != null
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: username.isNotEmpty
                                ? Text(
                                    "@$username",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                            onTap: () => setDialogState(
                              () => isSelected
                                  ? selectedIds.remove(uid)
                                  : selectedIds.add(uid),
                            ),
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
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(innerContext);
                                  final batch = FirebaseFirestore.instance
                                      .batch();
                                  final userFriendsRef = FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('friends');
                                  for (final friendId in selectedIds) {
                                    batch.update(userFriendsRef.doc(friendId), {
                                      'circles': FieldValue.arrayUnion([
                                        widget.circleId,
                                      ]),
                                    });
                                  }
                                  await batch.commit();
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Added ${selectedIds.length} friends!",
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
                            selectedIds.isEmpty
                                ? "Select Friends"
                                : "Add ${selectedIds.length} to Team",
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('friends')
            .where('circles', arrayContains: widget.circleId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchAndSortMembers(snapshot.data!.docs),
            builder: (context, profileSnap) {
              if (!profileSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final profiles = profileSnap.data!;
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    stretch: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    foregroundColor: Colors.white,
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: themeProvider.appGradient,
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: 20,
                              top: 40,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.circleName,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${profiles.length} Members",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: _showAddMembersBottomSheet,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_add,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              "Add",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (profiles.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.group_off,
                                size: 64,
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "This team is empty.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap 'Add' to recruit some squadmates!",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (profiles.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final profile = profiles[index];
                          final String uid = profile['uid'];
                          final displayName =
                              profile['displayName'] ?? "Unknown";
                          final String username = profile['username'] ?? "";
                          final String statusText = profile['statusText'] ?? "";
                          final String? avatarUrl = profile['avatarUrl'];
                          final Color avatarColor =
                              profile['avatarColor'] is int
                              ? Color(profile['avatarColor'])
                              : Colors.blue;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Dismissible(
                              key: Key(uid),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24.0),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.person_remove,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              confirmDismiss: (direction) async =>
                                  await _removeMember(uid, displayName),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24),
                                        ),
                                      ),
                                      builder: (ctx) => UserProfileSheet(
                                        userData: profile,
                                        currentUserId: user.uid,
                                        isGoated: profile['isGoated'] ?? false,
                                        // Because a team only shows friends, they can't be blocked!
                                        isBlocked: false,
                                        onToggleGoated: (currentGoated) async {
                                          Navigator.pop(ctx);
                                          HapticFeedback.mediumImpact();
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .collection('friends')
                                              .doc(uid)
                                              .set({
                                                'isGoated': !currentGoated,
                                              }, SetOptions(merge: true));
                                        },
                                        onToggleBlocked:
                                            (currentBlocked) async {
                                              Navigator.pop(ctx);
                                              HapticFeedback.heavyImpact();
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .update({
                                                    'blockedUids':
                                                        FieldValue.arrayUnion([
                                                          uid,
                                                        ]),
                                                  });
                                            },
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: avatarColor.withValues(
                                                  alpha: 0.4,
                                                ),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            backgroundColor: avatarColor,
                                            radius: 26,
                                            backgroundImage: avatarUrl != null
                                                ? CachedNetworkImageProvider(
                                                    avatarUrl,
                                                  )
                                                : null,
                                            child: avatarUrl == null
                                                ? Text(
                                                    displayName.isNotEmpty
                                                        ? displayName[0]
                                                              .toUpperCase()
                                                        : "?",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 17,
                                                  letterSpacing: -0.3,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (username.isNotEmpty ||
                                                  statusText.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4.0,
                                                      ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      if (username
                                                          .isNotEmpty) ...[
                                                        Flexible(
                                                          child: Text(
                                                            "@$username",
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  primaryColor,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (statusText
                                                            .isNotEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      6.0,
                                                                ),
                                                            child: Text(
                                                              "•",
                                                              style: TextStyle(
                                                                color: isDark
                                                                    ? Colors
                                                                          .grey
                                                                          .shade600
                                                                    : Colors
                                                                          .grey
                                                                          .shade400,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                      if (statusText.isNotEmpty)
                                                        Flexible(
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .secondaryContainer,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color: primaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              statusText,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    primaryColor,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: isDark
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }, childCount: profiles.length),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
