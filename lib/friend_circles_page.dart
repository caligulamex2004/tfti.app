import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'theme_provider.dart';
import 'phone_formatter.dart';

class FriendCirclesPage extends StatefulWidget {
  const FriendCirclesPage({super.key});

  @override
  State<FriendCirclesPage> createState() => _FriendCirclesPageState();
}

class _FriendCirclesPageState extends State<FriendCirclesPage> {
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
                          setState(() {
                            _selectedCircleName = newName;
                          });
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

  // --- NEW: iMESSAGE-STYLE GROUP AVATAR ---
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
          .limit(4) // Get up to 4 to see if we need a "+X" badge
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Fallback if the team is completely empty
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

        final docs = snapshot.data!.docs;
        final int count = docs.length;
        final displayDocs = docs.take(3).toList();
        final bool hasMore = count > 3;

        return SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              ...displayDocs.asMap().entries.map((entry) {
                final index = entry.key;
                final doc = entry.value;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(doc.id)
                      .get(),
                  builder: (context, userSnap) {
                    String name = "Unknown";
                    String? avatarUrl;
                    int avatarColor = Colors.blue.toARGB32();

                    if (userSnap.hasData && userSnap.data!.exists) {
                      final uData =
                          userSnap.data!.data() as Map<String, dynamic>;
                      name = uData['displayName'] ?? name;
                      avatarUrl = uData['avatarUrl'];
                      avatarColor = uData['avatarColor'] ?? avatarColor;
                    }

                    // Base Avatar Widget with cutout border
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

                    // Positioning logic based on member count
                    if (count == 1) {
                      return Positioned.fill(child: avatar);
                    } else if (count == 2) {
                      if (index == 0) {
                        return Positioned(
                          top: 0,
                          right: 0,
                          width: 32,
                          height: 32,
                          child: avatar,
                        );
                      } else {
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          width: 32,
                          height: 32,
                          child: avatar,
                        );
                      }
                    } else {
                      // 3 or more members
                      if (index == 0) {
                        return Positioned(
                          top: 0,
                          left: 10,
                          width: 28,
                          height: 28,
                          child: avatar,
                        );
                      } else if (index == 1) {
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          width: 28,
                          height: 28,
                          child: avatar,
                        );
                      } else {
                        return Positioned(
                          bottom: 0,
                          right: 0,
                          width: 28,
                          height: 28,
                          child: avatar,
                        );
                      }
                    }
                  },
                );
              }),

              // The tiny '+' badge for overflowing members
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
                      // 👇 UPDATED: The new iMessage Style Facepile!
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
                      onPressed: _showCreateTeamSheet,
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
                onPressed: _showCreateTeamSheet,
                backgroundColor: primaryColor,
                foregroundColor: themeProvider.onPrimaryColor,
                heroTag: "btn_create_circle",
                child: const Icon(Icons.add),
              ),
            ),
    );
  }
}

// --- POLISHED MEMBERS PAGE ---

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddMembersBottomSheet();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndSortMembers(
    List<DocumentSnapshot> friendDocs,
  ) async {
    List<Map<String, dynamic>> profiles = [];

    await Future.wait(
      friendDocs.map((doc) async {
        final uid = doc.id;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          data['uid'] = uid;
          profiles.add(data);
        }
      }),
    );

    profiles.sort((a, b) {
      final nameA = (a['displayName'] ?? '').toString().toLowerCase();
      final nameB = (b['displayName'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    return profiles;
  }

  Future<void> _removeMember(String friendUid) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Removed from Team!")));
    }
  }

  Future<void> _showAddMembersBottomSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Fetch ALL friends
    final allFriendsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('friends')
        .get();

    final availableFriendDocs = allFriendsSnapshot.docs.where((doc) {
      final circles = List<String>.from(doc.data()['circles'] ?? []);
      return !circles.contains(widget.circleId);
    }).toList();

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
                          final String name =
                              profile['displayName'] ?? "Unknown";
                          final String? avatarUrl = profile['avatarUrl'];

                          Color avatarColor = Colors.grey;
                          if (profile['avatarColor'] is int) {
                            avatarColor = Color(profile['avatarColor']);
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
                              setDialogState(() {
                                if (isSelected) {
                                  selectedIds.remove(uid);
                                } else {
                                  selectedIds.add(uid);
                                }
                              });
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

  void _showFriendProfileBottomSheet(
    BuildContext context,
    Map<String, dynamic> userData,
    bool isDark,
    Color primaryColor,
  ) {
    final displayName = userData['displayName'] ?? "No Name";
    final rawPhone = userData['phoneNumber'] ?? "";
    final bool showPhone = userData['showPhoneNumber'] == true;
    final String statusText = userData['statusText'] ?? "";
    final displayPhone = showPhone ? PhoneFormatter.beautify(rawPhone) : "";

    final String? avatarUrl = userData['avatarUrl'];
    Color avatarColor = Colors.blue.shade100;
    if (userData['avatarColor'] is int) {
      avatarColor = Color(userData['avatarColor']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 32),

                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: avatarColor,
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 40,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (statusText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(
                          top: 16,
                          left: 32,
                          right: 32,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            height: 1.4,
                          ),
                        ),
                      ),

                    if (showPhone && displayPhone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_iphone,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayPhone,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
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
          int memberCount = 0;
          List<DocumentSnapshot> friendDocs = [];

          if (snapshot.hasData) {
            friendDocs = snapshot.data!.docs;
            memberCount = friendDocs.length;
          }

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
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$memberCount Members",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                // 👇 FIXED: Custom InkWell container instead of ActionChip to prevent the white box bug!
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
                                      borderRadius: BorderRadius.circular(12),
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

              if (friendDocs.isEmpty &&
                  snapshot.connectionState == ConnectionState.active)
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

              if (friendDocs.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchAndSortMembers(friendDocs),
                    builder: (context, profileSnap) {
                      if (!profileSnap.hasData) {
                        return const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final profiles = profileSnap.data!;

                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final profile = profiles[index];
                          final displayName =
                              profile['displayName'] ?? "Unknown";

                          final rawPhone =
                              profile['phoneNumber'] ?? profile['phone'] ?? "";
                          final bool showPhone =
                              profile['showPhoneNumber'] == true;
                          final String statusText = profile['statusText'] ?? "";

                          final displayPhone = showPhone
                              ? PhoneFormatter.beautify(rawPhone)
                              : "";

                          final String? avatarUrl = profile['avatarUrl'];

                          Color avatarColor = Colors.blue;
                          if (profile['avatarColor'] is int) {
                            avatarColor = Color(profile['avatarColor']);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
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
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: ListTile(
                                onTap: () => _showFriendProfileBottomSheet(
                                  context,
                                  profile,
                                  isDark,
                                  primaryColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: avatarColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: avatarColor,
                                    radius: 24,
                                    backgroundImage: avatarUrl != null
                                        ? CachedNetworkImageProvider(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : "?",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: (!showPhone && statusText.isEmpty)
                                    ? null
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6.0,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (showPhone) ...[
                                              Text(
                                                displayPhone,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                              if (statusText.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                      ),
                                                  child: Text(
                                                    "•",
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.grey.shade600
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
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: primaryColor
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    statusText,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: primaryColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.remove_circle_outline,
                                    color: isDark
                                        ? Colors.redAccent
                                        : Colors.red,
                                  ),
                                  onPressed: () =>
                                      _removeMember(profile['uid']),
                                ),
                              ),
                            ),
                          );
                        }, childCount: profiles.length),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
