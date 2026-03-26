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
  final _nameController = TextEditingController();

  String? _selectedCircleId;
  String? _selectedCircleName;
  bool _autoOpenNewCircle = false;

  Future<void> _createCircle() async {
    if (_nameController.text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('circles')
        .add({
          'name': _nameController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

    final circleName = _nameController.text.trim();
    _nameController.clear();

    if (mounted) {
      Navigator.pop(context);

      if (MediaQuery.of(context).orientation == Orientation.landscape) {
        setState(() {
          _selectedCircleId = docRef.id;
          _selectedCircleName = circleName;
          _autoOpenNewCircle = true;
        });
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CircleMembersPage(
              circleId: docRef.id,
              circleName: circleName,
              autoOpenAddMembers: true,
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteCircle(String circleId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (_selectedCircleId == circleId) {
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

  Future<void> _renameCircle(String circleId, String newName) async {
    if (newName.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('circles')
        .doc(circleId)
        .update({'name': newName});

    if (_selectedCircleId == circleId) {
      setState(() {
        _selectedCircleName = newName;
      });
    }
  }

  void _showAddDialog() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Squad Circle"),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "e.g. Movie Buffs",
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _createCircle,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: themeProvider.onPrimaryColor,
            ),
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(String circleId, String currentName) async {
    final renameController = TextEditingController(text: currentName);
    final primaryColor = Theme.of(context).colorScheme.primary;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Circle"),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _renameCircle(circleId, renameController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: themeProvider.onPrimaryColor,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(Color primaryColor) {
    return FloatingActionButton(
      onPressed: _showAddDialog,
      backgroundColor: primaryColor,
      foregroundColor: themeProvider.onPrimaryColor,
      heroTag: "btn_create_circle",
      child: const Icon(Icons.add),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Select a Team to view members",
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
                Icon(
                  Icons.supervised_user_circle_outlined,
                  size: 80,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "No Teams Yet",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create one to group your friends!",
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 8.0 : 12.0,
            vertical: 12.0,
          ),
          itemCount: circles.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
          itemBuilder: (context, index) {
            final data = circles[index].data() as Map<String, dynamic>;
            final circleId = circles[index].id;
            final circleName = data['name'] ?? 'Circle';

            final isSelected = isLandscape && _selectedCircleId == circleId;

            return Dismissible(
              key: Key(circleId),
              direction: DismissDirection.horizontal,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20.0),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Colors.white),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  _showRenameDialog(circleId, circleName);
                  return false;
                } else if (direction == DismissDirection.endToStart) {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Team?"),
                      content: Text("Delete '$circleName'?"),
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return false;
              },
              onDismissed: (direction) {
                if (direction == DismissDirection.endToStart) {
                  _deleteCircle(circleId);
                }
              },
              // --- FIX: CUSTOM ROW REPLACES LISTTILE FOR 100% LAYOUT CONTROL ---
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
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
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // ALIGNED ABSOLUTE LEFT
                      CircleAvatar(
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                        child: Icon(Symbols.circles, color: primaryColor),
                      ),
                      const SizedBox(width: 16),
                      // EXPANDS TO FILL 100% OF REMAINING MIDDLE SPACE
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
                      const SizedBox(width: 16),
                      // ALIGNED ABSOLUTE RIGHT
                      Icon(
                        isLandscape
                            ? Icons.chevron_right
                            : Icons.arrow_forward_ios,
                        size: isLandscape ? 24 : 14,
                        color: isSelected ? primaryColor : Colors.grey,
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
        title: const Text("Teams"),
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
                    floatingActionButton: _buildFab(primaryColor),
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
              floatingActionButton: _buildFab(primaryColor),
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
        _showAddMembersDialog();
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
      ).showSnackBar(const SnackBar(content: Text("Removed!")));
    }
  }

  Future<void> _showAddMembersDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

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

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            return AlertDialog(
              title: Text("Add to ${widget.circleName}"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedAvailable.length,
                  itemBuilder: (context, index) {
                    final profile = sortedAvailable[index];
                    final uid = profile['uid'];
                    final isSelected = selectedIds.contains(uid);
                    final String name = profile['displayName'] ?? "Unknown";

                    final String? avatarUrl = profile['avatarUrl'];

                    Color avatarColor = Colors.grey;
                    if (profile['avatarColor'] is int) {
                      avatarColor = Color(profile['avatarColor']);
                    }

                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(name),
                      secondary: CircleAvatar(
                        backgroundColor: avatarColor,
                        radius: 16,
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      activeColor: primaryColor,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedIds.add(uid);
                          } else {
                            selectedIds.remove(uid);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);

                          final batch = FirebaseFirestore.instance.batch();
                          final userFriendsRef = FirebaseFirestore.instance
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
                  ),
                  child: const Text("Add"),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.circleName),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMembersDialog,
        backgroundColor: primaryColor,
        foregroundColor: themeProvider.onPrimaryColor,
        heroTag: "btn_add_members",
        child: const Icon(Icons.person_add),
      ),
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

          final friendDocs = snapshot.data!.docs;
          if (friendDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off,
                    size: 60,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "This team is empty.",
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchAndSortMembers(friendDocs),
            builder: (context, profileSnap) {
              if (!profileSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final profiles = profileSnap.data!;

              return ListView.separated(
                itemCount: profiles.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: isLandscape ? 16 : 70, // Better underline formatting
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final displayName = profile['displayName'] ?? "Unknown";

                  final phone = PhoneFormatter.beautify(
                    profile['phoneNumber'] ?? profile['phone'] ?? "",
                  );

                  final String? avatarUrl = profile['avatarUrl'];

                  Color avatarColor = Colors.blue;
                  if (profile['avatarColor'] is int) {
                    avatarColor = Color(profile['avatarColor']);
                  }

                  // --- FIX: CUSTOM ROW REPLACES LISTTILE FOR 100% LAYOUT CONTROL ---
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
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
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: isDark ? Colors.redAccent : Colors.red,
                          ),
                          onPressed: () => _removeMember(profile['uid']),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
