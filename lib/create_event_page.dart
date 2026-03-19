import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'location_search_page.dart';
import 'theme_provider.dart';
import 'friend_circles_page.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _locController = TextEditingController();
  final _detailsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _inviteAll = false;
  final List<String> _selectedCircleIds = [];
  bool _isLoading = false;

  bool _isImportantDetails = false;
  int _rsvpDeadlineOffset = 0;

  final List<String> _roles = [];
  final _roleInputController = TextEditingController();

  bool _isLocFavorite = false;
  String? _favoriteDocId;

  String? _selectedCoHostId;
  String? _selectedCoHostName;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    int nextMinute = now.minute < 30 ? 30 : 0;
    int addHour = now.minute >= 30 ? 1 : 0;

    final roundedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour + addHour,
      nextMinute,
    );

    _selectedDate = roundedDateTime;
    _selectedTime = TimeOfDay.fromDateTime(roundedDateTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locController.dispose();
    _detailsController.dispose();
    _roleInputController.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus(String address) async {
    if (address.isEmpty) {
      setState(() {
        _isLocFavorite = false;
        _favoriteDocId = null;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorite_places')
        .where('address', isEqualTo: address)
        .get();

    if (snap.docs.isNotEmpty) {
      setState(() {
        _isLocFavorite = true;
        _favoriteDocId = snap.docs.first.id;
      });
    } else {
      setState(() {
        _isLocFavorite = false;
        _favoriteDocId = null;
      });
    }
  }

  Future<void> _toggleFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _locController.text.isEmpty) return;

    if (_isLocFavorite && _favoriteDocId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorite_places')
          .doc(_favoriteDocId)
          .delete();

      setState(() {
        _isLocFavorite = false;
        _favoriteDocId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Removed from favorites")));
      }
    } else {
      String name = '';
      final primaryColor = Theme.of(context).colorScheme.primary;

      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Save Favorite Place"),
          content: TextField(
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: "e.g. Bob's House, Poker Room",
              counterText: "",
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (val) => name = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text(
                "Save",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (saved == true && name.trim().isNotEmpty) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorite_places')
            .add({
              'name': name.trim(),
              'address': _locController.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });

        setState(() {
          _isLocFavorite = true;
          _favoriteDocId = docRef.id;
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Saved to favorites!")));
        }
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cardColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: primaryColor.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Future<void> _selectLocation() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationSearchPage()),
    );

    if (selectedAddress != null) {
      setState(() {
        _locController.text = selectedAddress;
      });
      _checkFavoriteStatus(selectedAddress);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showCreateCircleImpromptu() {
    final nameController = TextEditingController();
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Friend Circle"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
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

              setState(() {
                _selectedCircleIds.add(docRef.id);
                _inviteAll = false;
                _selectedCoHostId = null;
                _selectedCoHostName = null;
              });

              Navigator.pop(context);

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
            },
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
              title: const Text("Who's getting the i?"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      activeThumbColor: primaryColor,
                      title: const Text(
                        "All Friends",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _inviteAll,
                      onChanged: (val) {
                        setDialogState(() {
                          _inviteAll = val;
                          if (val) {
                            _selectedCircleIds.clear();
                          }
                          _selectedCoHostId = null;
                          _selectedCoHostName = null;
                        });
                        setState(() {});
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
                        child: Text("No circles created yet."),
                      ),
                    ...circles.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isChecked = _selectedCircleIds.contains(doc.id);
                      return SwitchListTile(
                        activeThumbColor: primaryColor,
                        title: Text(data['name'] ?? 'Unnamed'),
                        value: isChecked,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val) {
                              _selectedCircleIds.add(doc.id);
                              _inviteAll = false;
                            } else {
                              _selectedCircleIds.remove(doc.id);
                              if (_selectedCircleIds.isEmpty) {
                                _inviteAll = true;
                              }
                            }
                            _selectedCoHostId = null;
                            _selectedCoHostName = null;
                          });
                          setState(() {});
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
                        "Create New Circle",
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
                  onPressed: () => Navigator.pop(ctx),
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

  void _showRolesDialog() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Squad Needs (Optional)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Add things you need guests to bring or do (e.g. Bring ice, Drive 1st half)",
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _roles.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_roles[index]),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setSheetState(() => _roles.removeAt(index));
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _roleInputController,
                          maxLength: 30,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: "New item...",
                            counterText: "",
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (_roleInputController.text.trim().isNotEmpty) {
                            setSheetState(() {
                              _roles.add(_roleInputController.text.trim());
                              _roleInputController.clear();
                            });
                            setState(() {});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: themeProvider.onPrimaryColor,
                        ),
                        child: const Text("Add"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchEligibleCoHosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final friendsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .get();

    List<String> eligibleUids = [];
    for (var friendDoc in friendsSnapshot.docs) {
      final data = friendDoc.data();
      final friendCircles = List<String>.from(data['circles'] ?? []);

      if (_inviteAll ||
          _selectedCircleIds.any((id) => friendCircles.contains(id))) {
        eligibleUids.add(friendDoc.id);
      }
    }

    if (eligibleUids.isEmpty) return [];

    List<Map<String, dynamic>> profiles = [];
    await Future.wait(
      eligibleUids.map((uid) async {
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

    profiles.sort(
      (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
        (b['displayName'] ?? '').toString().toLowerCase(),
      ),
    );
    return profiles;
  }

  void _showCoHostDialog() {
    if (!_inviteAll && _selectedCircleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Select 'Who's getting the i?' first to pick a co-host!",
          ),
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              const SizedBox(height: 16),
              const Text(
                "Select Co-Host",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              if (_selectedCoHostId != null)
                ListTile(
                  leading: const Icon(Icons.person_remove, color: Colors.red),
                  title: const Text(
                    "Remove Co-Host",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedCoHostId = null;
                      _selectedCoHostName = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),

              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchEligibleCoHosts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("No friends found in selected circles."),
                      );
                    }

                    final profiles = snapshot.data!;
                    return ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final String name = profile['displayName'] ?? "Unknown";
                        final String uid = profile['uid'];
                        final String? avatarUrl = profile['avatarUrl'];
                        Color avatarColor = Colors.blue;
                        if (profile['avatarColor'] is int) {
                          avatarColor = Color(profile['avatarColor']);
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: avatarColor,
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
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCoHostId = uid;
                              _selectedCoHostName = name;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final finalDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();

        Set<String> visibleToIds = {user.uid};
        Set<DocumentSnapshot> friendsToInvite = {};

        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data();
          final friendCircles = List<String>.from(data['circles'] ?? []);

          if (_inviteAll ||
              _selectedCircleIds.any((id) => friendCircles.contains(id))) {
            friendsToInvite.add(friendDoc);
            visibleToIds.add(friendDoc.id);
          }
        }

        if (friendsToInvite.isEmpty && !_inviteAll) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("No friends found in selected circles!"),
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        final eventRef = await FirebaseFirestore.instance
            .collection('events')
            .add({
              'hostId': user.uid,
              'coHostId': _selectedCoHostId,
              'title': _titleController.text.trim(),
              'location': _locController.text.trim(),
              'details': _detailsController.text.trim(),
              'time': Timestamp.fromDate(finalDateTime),
              'created_at': FieldValue.serverTimestamp(),
              'visibleTo': visibleToIds.toList(),
              'inviteAll': _inviteAll,
              'invitedCircles': _selectedCircleIds,
              'isImportantDetails': _isImportantDetails,
              'rsvpDeadline': _rsvpDeadlineOffset,
            });

        final batch = FirebaseFirestore.instance.batch();

        for (var friendDoc in friendsToInvite) {
          final isCoHost = friendDoc.id == _selectedCoHostId;
          final inviteRef = eventRef
              .collection('invitations')
              .doc(friendDoc.id);

          batch.set(inviteRef, {
            'uid': friendDoc.id,
            'role': isCoHost ? 'co-host' : 'guest',
            'status': 'pending',
            'sentAt': FieldValue.serverTimestamp(),
          });
        }

        final hostRef = eventRef.collection('invitations').doc(user.uid);
        batch.set(hostRef, {
          'uid': user.uid,
          'role': 'host',
          'status': 'going',
          'sentAt': FieldValue.serverTimestamp(),
        });

        for (String roleTitle in _roles) {
          final roleRef = eventRef.collection('roles').doc();
          batch.set(roleRef, {
            'title': roleTitle,
            'addedBy': user.uid,
            'claimedByUid': null,
            'claimedByName': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Invited ${friendsToInvite.length} friends!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildResponsiveRow(bool isLandscape, Widget child1, Widget child2) {
    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: child1),
            const SizedBox(width: 16),
            Expanded(child: child2),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          child1,
          const SizedBox(height: 16),
          child2,
          const SizedBox(height: 16),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = FirebaseAuth.instance.currentUser;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final dateString =
        "${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}";
    final timeString = _selectedTime.format(context);

    final titleField = TextFormField(
      controller: _titleController,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 50,
      decoration: _buildInputDecoration(
        label: "Let's do...",
        hint: "e.g. Taco Night 🌮",
        prefixIcon: Icon(Symbols.campaign, color: primaryColor),
      ).copyWith(counterText: ""),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );

    final locationField = TextFormField(
      controller: _locController,
      readOnly: true,
      onTap: _selectLocation,
      maxLength: 100,
      decoration: _buildInputDecoration(
        label: "Where at?",
        hint: "Tap to search address...",
        prefixIcon: Icon(
          Icons.location_on,
          color: isDark ? Colors.redAccent : Colors.red,
        ),
        suffixIcon: _locController.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  _isLocFavorite ? Icons.star : Icons.star_border,
                  color: _isLocFavorite
                      ? Colors.amber
                      : (isDark ? Colors.grey.shade500 : Colors.grey),
                  size: 26,
                ),
                onPressed: _toggleFavoriteStatus,
              )
            : Icon(
                Icons.search,
                color: isDark ? Colors.grey.shade500 : Colors.grey,
              ),
      ).copyWith(counterText: ""),
      validator: (v) => v!.isEmpty ? "Please select a location" : null,
    );

    final dateTimeRow = Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _buildInputDecoration(
                label: "Date",
                prefixIcon: Icon(
                  Icons.calendar_today,
                  color: isDark ? Colors.lightBlueAccent : Colors.blue,
                ),
              ),
              child: Text(dateString, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickTime,
            child: InputDecorator(
              decoration: _buildInputDecoration(
                label: "Time",
                prefixIcon: Icon(
                  Icons.access_time,
                  color: isDark ? Colors.orangeAccent : Colors.orange,
                ),
              ),
              child: Text(timeString, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );

    final rsvpField = DropdownButtonFormField<int>(
      initialValue: _rsvpDeadlineOffset,
      decoration: _buildInputDecoration(
        label: "RSVP Deadline",
        prefixIcon: Icon(Icons.timer_off_outlined, color: primaryColor),
      ),
      dropdownColor: Theme.of(context).cardColor,
      icon: const Icon(Icons.arrow_drop_down),
      items: const [
        DropdownMenuItem(value: -240, child: Text("4 hours before")),
        DropdownMenuItem(value: -120, child: Text("2 hours before")),
        DropdownMenuItem(value: -60, child: Text("1 hour before")),
        DropdownMenuItem(value: -30, child: Text("30 mins before")),
        DropdownMenuItem(value: 0, child: Text("At event start (Default)")),
        DropdownMenuItem(value: 30, child: Text("30 mins after")),
        DropdownMenuItem(value: 60, child: Text("1 hour after")),
        DropdownMenuItem(value: 120, child: Text("2 hours after")),
        DropdownMenuItem(value: 240, child: Text("4 hours after")),
      ],
      onChanged: (val) => setState(() => _rsvpDeadlineOffset = val ?? 0),
    );

    final detailsField = TextFormField(
      controller: _detailsController,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 500,
      decoration: _buildInputDecoration(
        label: "Need to Know",
        hint: "e.g. Meet in the lobby at 7...",
        prefixIcon: Icon(
          Icons.notes,
          color: isDark ? Colors.grey.shade400 : Colors.grey,
        ),
      ).copyWith(alignLabelWithHint: true, counterText: ""),
      maxLines: 3,
      keyboardType: TextInputType.multiline,
    );

    final togglesRow = Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _showRolesDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _roles.isNotEmpty
                      ? primaryColor
                      : (isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.05)),
                  width: _roles.isNotEmpty ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_box_outlined,
                    color: _roles.isNotEmpty
                        ? primaryColor
                        : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _roles.isEmpty ? "Squad Needs" : "${_roles.length} Needs",
                      style: TextStyle(
                        fontWeight: _roles.isNotEmpty
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _roles.isNotEmpty
                            ? primaryColor
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () =>
                setState(() => _isImportantDetails = !_isImportantDetails),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isImportantDetails
                      ? Colors.red
                      : (isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.05)),
                  width: _isImportantDetails ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isImportantDetails
                        ? Icons.campaign
                        : Icons.campaign_outlined,
                    color: _isImportantDetails
                        ? Colors.red
                        : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Important",
                      style: TextStyle(
                        fontWeight: _isImportantDetails
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _isImportantDetails
                            ? Colors.red
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("What's the Plan?"),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildResponsiveRow(
                        isLandscape,
                        titleField,
                        locationField,
                      ),
                      _buildResponsiveRow(isLandscape, dateTimeRow, rsvpField),
                      _buildResponsiveRow(
                        isLandscape,
                        detailsField,
                        togglesRow,
                      ),

                      if (user != null) ...[
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('circles')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final circles = snapshot.hasData
                                ? snapshot.data!.docs
                                : <DocumentSnapshot>[];

                            String targetPreviewText = "Select guests...";
                            if (_inviteAll) {
                              targetPreviewText = "All Friends";
                            } else if (_selectedCircleIds.isNotEmpty) {
                              final selectedNames = circles
                                  .where(
                                    (c) => _selectedCircleIds.contains(c.id),
                                  )
                                  .map(
                                    (c) =>
                                        (c.data()
                                            as Map<String, dynamic>)['name'] ??
                                        'Unnamed',
                                  )
                                  .join(', ');
                              targetPreviewText = selectedNames.isNotEmpty
                                  ? selectedNames
                                  : "Selected Circles";
                            }

                            final circlesField = InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showCircleDialog(circles),
                              child: InputDecorator(
                                decoration: _buildInputDecoration(
                                  label: "Who's getting the i?",
                                  prefixIcon: Icon(
                                    Icons.people,
                                    color: isDark
                                        ? Colors.tealAccent
                                        : Colors.teal,
                                  ),
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                ),
                                child: Text(
                                  targetPreviewText,
                                  style: const TextStyle(fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );

                            final coHostField = InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _showCoHostDialog,
                              child: InputDecorator(
                                decoration: _buildInputDecoration(
                                  label: "Add co-host (optional)",
                                  prefixIcon: Icon(
                                    Icons.person_add_alt_1,
                                    color: isDark
                                        ? Colors.amberAccent
                                        : Colors.amber.shade700,
                                  ),
                                  suffixIcon: _selectedCoHostId != null
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() {
                                            _selectedCoHostId = null;
                                            _selectedCoHostName = null;
                                          }),
                                        )
                                      : const Icon(Icons.arrow_drop_down),
                                ),
                                child: Text(
                                  _selectedCoHostName ??
                                      "Select a trusted friend...",
                                  style: const TextStyle(fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );

                            return _buildResponsiveRow(
                              isLandscape,
                              circlesField,
                              coHostField,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _saveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: themeProvider.onPrimaryColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "send out the i's",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
