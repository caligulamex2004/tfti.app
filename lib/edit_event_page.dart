import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'event_roles_page.dart';
import 'location_search_page.dart';
import 'theme_provider.dart';
import 'friend_circles_page.dart';

class EditEventPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EditEventPage({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _detailsController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _inviteAll = false;
  List<String> _selectedCircleIds = [];
  bool _isLoading = false;

  bool _isImportantDetails = false;
  int _rsvpDeadlineOffset = 0;

  bool _isLocFavorite = false;
  String? _favoriteDocId;

  late bool _isMainHost;
  late bool _isCoHost;

  String? _selectedCoHostId;
  String? _selectedCoHostName;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    _isMainHost = widget.eventData['hostId'] == user?.uid;
    _isCoHost = widget.eventData['coHostId'] == user?.uid;

    _titleController = TextEditingController(text: widget.eventData['title']);
    _locationController = TextEditingController(
      text: widget.eventData['location'],
    );

    String currentDetails =
        widget.eventData['details'] ?? widget.eventData['description'] ?? '';
    _detailsController = TextEditingController(text: currentDetails);

    if (widget.eventData['time'] != null) {
      Timestamp ts = widget.eventData['time'];
      DateTime dt = ts.toDate();
      _selectedDate = dt;
      _selectedTime = TimeOfDay.fromDateTime(dt);
    }

    _isImportantDetails = widget.eventData['isImportantDetails'] ?? false;
    _rsvpDeadlineOffset = widget.eventData['rsvpDeadline'] ?? 0;

    if (_isCoHost && !_isMainHost) {
      _inviteAll = widget.eventData['coHostInviteAll'] ?? false;
      _selectedCircleIds = List<String>.from(
        widget.eventData['coHostInvitedCircles'] ?? [],
      );
    } else {
      _inviteAll = widget.eventData['inviteAll'] ?? true;
      _selectedCircleIds = List<String>.from(
        widget.eventData['invitedCircles'] ?? [],
      );

      _selectedCoHostId = widget.eventData['coHostId'];
      if (_selectedCoHostId != null) {
        _loadCoHostName(_selectedCoHostId!);
      }
    }

    _checkFavoriteStatus(_locationController.text);
  }

  Future<void> _loadCoHostName(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _selectedCoHostName = doc.data()?['displayName'] ?? "Unknown";
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
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
    if (user == null || _locationController.text.isEmpty) return;

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
            decoration: InputDecoration(
              hintText: "e.g. Bob's House, Poker Room",
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
              'address': _locationController.text.trim(),
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

  String _formatDate(DateTime dt) {
    return "${dt.month}/${dt.day}/${dt.year}";
  }

  String _formatTime(TimeOfDay t) {
    return t.format(context);
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
        _locationController.text = selectedAddress;
      });
      _checkFavoriteStatus(selectedAddress);
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
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: "e.g. Work Besties",
            border: OutlineInputBorder(),
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

              // 1. Guard the dialog's context and pop it
              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              // 2. Guard the State's context using 'mounted'
              if (!mounted) return;

              setState(() {
                _selectedCircleIds.add(docRef.id);
                _inviteAll = false;
                if (_isMainHost) {
                  _selectedCoHostId = null;
                  _selectedCoHostName = null;
                }
              });

              Navigator.pop(context); // Pop the outer Circle Selector Dialog

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
              title: const Text("Update Guest List"),
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
                          if (_isMainHost) {
                            _selectedCoHostId = null;
                            _selectedCoHostName = null;
                          }
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
                            if (_isMainHost) {
                              _selectedCoHostId = null;
                              _selectedCoHostName = null;
                            }
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
            "Select \"Who's getting the i?\" first to pick a co-host!",
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

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text(
          'This will permanently delete the event, the guest list, and the chat history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final firestore = FirebaseFirestore.instance;
        final eventRef = firestore.collection('events').doc(widget.eventId);

        final invitations = await eventRef.collection('invitations').get();
        for (var doc in invitations.docs) {
          await doc.reference.delete();
        }

        final messages = await eventRef.collection('messages').get();
        for (var doc in messages.docs) {
          await doc.reference.delete();
        }

        final roles = await eventRef.collection('roles').get();
        for (var doc in roles.docs) {
          await doc.reference.delete();
        }

        await eventRef.delete();

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _updateEvent() async {
    if (_isMainHost && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final Map<String, dynamic> updateData = {
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };

      String? oldCoHostId = widget.eventData['coHostId'];

      if (_isMainHost) {
        final newDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        final newLocation = _locationController.text.trim();
        final oldTimestamp = widget.eventData['time'] as Timestamp;
        final oldDateTime = oldTimestamp.toDate();
        final oldLocation = (widget.eventData['location'] ?? '')
            .toString()
            .trim();

        if (newLocation != oldLocation) {
          updateData['latestCriticalChange'] = {
            'field': 'Location',
            'original': oldLocation,
            'new': newLocation,
            'timestamp': FieldValue.serverTimestamp(),
          };
        } else if (newDateTime != oldDateTime) {
          final oldDateStr =
              "${_formatDate(oldDateTime)} @ ${_formatTime(TimeOfDay.fromDateTime(oldDateTime))}";
          final newDateStr =
              "${_formatDate(newDateTime)} @ ${_formatTime(TimeOfDay.fromDateTime(newDateTime))}";

          updateData['latestCriticalChange'] = {
            'field': 'Time/Date',
            'original': oldDateStr,
            'new': newDateStr,
            'timestamp': FieldValue.serverTimestamp(),
          };
        }

        updateData['title'] = _titleController.text.trim();
        updateData['location'] = newLocation;
        updateData['details'] = _detailsController.text.trim();
        updateData['time'] = Timestamp.fromDate(newDateTime);
        updateData['isImportantDetails'] = _isImportantDetails;
        updateData['rsvpDeadline'] = _rsvpDeadlineOffset;
        updateData['inviteAll'] = _inviteAll;
        updateData['invitedCircles'] = _selectedCircleIds;
        updateData['coHostId'] = _selectedCoHostId;
      } else if (_isCoHost) {
        updateData['coHostInviteAll'] = _inviteAll;
        updateData['coHostInvitedCircles'] = _selectedCircleIds;
      }

      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();

      Set<String> newIntendedIds = {};
      Set<String> oldIntendedIds = {};

      final bool oldInviteAll = _isCoHost
          ? (widget.eventData['coHostInviteAll'] ?? false)
          : (widget.eventData['inviteAll'] ?? true);

      final List<String> oldCircles = List<String>.from(
        _isCoHost
            ? (widget.eventData['coHostInvitedCircles'] ?? [])
            : (widget.eventData['invitedCircles'] ?? []),
      );

      for (var friendDoc in friendsSnapshot.docs) {
        final data = friendDoc.data();
        final friendCircles = List<String>.from(data['circles'] ?? []);

        if (_inviteAll ||
            _selectedCircleIds.any((id) => friendCircles.contains(id))) {
          newIntendedIds.add(friendDoc.id);
        }

        if (oldInviteAll ||
            oldCircles.any((id) => friendCircles.contains(id))) {
          oldIntendedIds.add(friendDoc.id);
        }
      }

      Set<String> toAdd = newIntendedIds.difference(oldIntendedIds);
      Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);

      toRemove.remove(widget.eventData['hostId']);
      if (widget.eventData['coHostId'] != null) {
        toRemove.remove(widget.eventData['coHostId']);
      }

      final batch = FirebaseFirestore.instance.batch();
      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId);

      if (toAdd.isNotEmpty) {
        updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
        for (String uid in toAdd) {
          batch.set(eventRef.collection('invitations').doc(uid), {
            'uid': uid,
            'role': uid == _selectedCoHostId ? 'co-host' : 'guest',
            'status': 'pending',
            'sentAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (toRemove.isNotEmpty) {
        updateData['visibleTo'] = FieldValue.arrayRemove(toRemove.toList());
        for (String uid in toRemove) {
          batch.delete(eventRef.collection('invitations').doc(uid));
        }
      }

      if (_isMainHost && oldCoHostId != _selectedCoHostId) {
        if (oldCoHostId != null && newIntendedIds.contains(oldCoHostId)) {
          batch.update(eventRef.collection('invitations').doc(oldCoHostId), {
            'role': 'guest',
          });
        }
        if (_selectedCoHostId != null && !toAdd.contains(_selectedCoHostId)) {
          batch.update(
            eventRef.collection('invitations').doc(_selectedCoHostId),
            {'role': 'co-host'},
          );
        }
      }

      batch.update(eventRef, updateData);
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // --- RESPONSIVE HELPER ---
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

  Widget _buildCoHostView(bool isDark, Color primaryColor, User user) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.teal.withValues(alpha: 0.2)
                  : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal),
            ),
            child: Row(
              children: [
                const Icon(Icons.handshake, color: Colors.teal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You are the Co-Host! You can manage your own guest list and add Squad Needs.",
                    style: TextStyle(
                      color: isDark ? Colors.tealAccent : Colors.teal.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

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
                targetPreviewText = "All My Friends";
              } else if (_selectedCircleIds.isNotEmpty) {
                final selectedNames = circles
                    .where((c) => _selectedCircleIds.contains(c.id))
                    .map(
                      (c) =>
                          (c.data() as Map<String, dynamic>)['name'] ??
                          'Unnamed',
                    )
                    .join(', ');
                targetPreviewText = selectedNames.isNotEmpty
                    ? selectedNames
                    : "Selected Circles";
              }

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showCircleDialog(circles),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: "Update My Guest List",
                    prefixIcon: Icon(
                      Icons.people,
                      color: isDark ? Colors.tealAccent : Colors.teal,
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
            },
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: ListTile(
              leading: Icon(Icons.check_box_outlined, color: primaryColor),
              title: const Text(
                "Manage Squad Needs",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                "View, add, or delete your roles",
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EventRolesPage(eventId: widget.eventId, isHost: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _updateEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: themeProvider.onPrimaryColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Save Changes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = FirebaseAuth.instance.currentUser;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // --- EXTRACTED FORM FIELDS FOR MAIN HOST ---
    final titleField = TextFormField(
      controller: _titleController,
      decoration: _buildInputDecoration(
        label: 'Event Title',
        prefixIcon: Icon(Symbols.campaign, color: primaryColor),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );

    final locationField = TextFormField(
      controller: _locationController,
      readOnly: true,
      onTap: _selectLocation,
      decoration: _buildInputDecoration(
        label: 'Location',
        hint: "Tap to search address...",
        prefixIcon: Icon(
          Icons.location_on,
          color: isDark ? Colors.redAccent : Colors.red,
        ),
        suffixIcon: _locationController.text.isNotEmpty
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
      ),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
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
              child: Text(
                _selectedDate == null
                    ? 'Select Date'
                    : "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}",
                style: const TextStyle(fontSize: 16),
              ),
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
              child: Text(
                _selectedTime == null
                    ? 'Select Time'
                    : _selectedTime!.format(context),
                style: const TextStyle(fontSize: 16),
              ),
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
      decoration: _buildInputDecoration(
        label: 'Details / Description',
        prefixIcon: Icon(
          Icons.notes,
          color: isDark ? Colors.grey.shade400 : Colors.grey,
        ),
      ).copyWith(alignLabelWithHint: true),
      maxLines: 3,
    );

    final togglesRow = Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EventRolesPage(eventId: widget.eventId, isHost: true),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_box_outlined, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Squad Needs",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
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
        title: Text(_isMainHost ? "Change of Plans?" : "Manage Event"),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_isCoHost && !_isMainHost)
          ? _buildCoHostView(isDark, primaryColor, user!)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- RESPONSIVE LAYOUT ASSEMBLY ---
                    _buildResponsiveRow(isLandscape, titleField, locationField),
                    _buildResponsiveRow(isLandscape, dateTimeRow, rsvpField),
                    _buildResponsiveRow(isLandscape, detailsField, togglesRow),

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
                                .where((c) => _selectedCircleIds.contains(c.id))
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
                                label: "Update Guest List",
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
                                label: "Change co-host",
                                prefixIcon: Icon(
                                  Icons.person_add_alt_1,
                                  color: isDark
                                      ? Colors.amberAccent
                                      : Colors.amber.shade700,
                                ),
                                suffixIcon: _selectedCoHostId != null
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 20),
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

                          // Apply responsive layout to the final two inputs
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
                        onPressed: _updateEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: themeProvider.onPrimaryColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Save Changes",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _deleteEvent,
                        icon: Icon(
                          Icons.delete,
                          color: isDark ? Colors.redAccent : Colors.red,
                        ),
                        label: Text(
                          "Delete Event",
                          style: TextStyle(
                            color: isDark ? Colors.redAccent : Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? Colors.redAccent : Colors.red,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
