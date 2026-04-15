import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'pages/places_search_page.dart';
import 'utils/theme_provider.dart';
import 'pages/teams_page.dart';

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
  String? _bannerImagePath;

  // Advanced Season State
  bool _isRecurring = false;
  String _recurringFrequency = 'weekly'; // 'weekly', 'biweekly', 'monthly'
  int _recurringInstances = 16; // Default starting value

  // Dynamically limits the stepper based on their frequency choice
  int get _maxRecurringInstances {
    if (_recurringFrequency == 'weekly') return 16;
    if (_recurringFrequency == 'biweekly') return 8;
    if (_recurringFrequency == 'monthly') return 4;
    return 16;
  }

  // State for the new tactile Chip Rows
  int _rsvpDeadlineOffset = 0;
  int _keepAliveDays = 0; // 0 = default 4 hours. 1-10 = multi-day event

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

  // --- NEW: SEASON DATE GENERATOR ---
  List<DateTime> _generateSeasonDates(DateTime start) {
    List<DateTime> dates = [start];
    if (!_isRecurring) return dates;

    int daysToAdd = 0;
    if (_recurringFrequency == 'weekly') {
      daysToAdd = 7;
    } else if (_recurringFrequency == 'biweekly') {
      daysToAdd = 14;
    }

    DateTime current = start;

    // Loops exactly to the user's requested number of instances!
    for (int i = 1; i < _recurringInstances; i++) {
      if (_recurringFrequency == 'monthly') {
        int newYear = current.year;
        int newMonth = current.month + 1;
        if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
        // Safety check so Jan 31 doesn't crash in Feb
        int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        int newDay = current.day > daysInNewMonth
            ? daysInNewMonth
            : current.day;

        current = DateTime(
          newYear,
          newMonth,
          newDay,
          current.hour,
          current.minute,
        );
      } else {
        current = current.add(Duration(days: daysToAdd));
      }
      dates.add(current);
    }
    return dates;
  }

  // --- MODERNIZED INPUT DECORATION ---
  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    // Input fields now sit on top of the card color, so we tint them slightly darker/lighter
    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
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
        title: const Text("New Team"),
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
                        "Entire Squad",
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
                        child: Text("No teams created yet."),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  const SizedBox(height: 16),
                  const Text(
                    "Squad Needs",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Add things you need the crew to bring or do (e.g. Bring ice, Drive 1st half)",
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _roles.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            _roles[index],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                        child: const Text(
                          "Add",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
            "Select 'Who's getting the i?' first to pick a co-captain!",
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
              const SizedBox(height: 16),
              const Text(
                "Select Co-Captain",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              if (_selectedCoHostId != null)
                ListTile(
                  leading: const Icon(Icons.person_remove, color: Colors.red),
                  title: const Text(
                    "Remove Co-Captain",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
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
                        child: Text("No friends found in selected teams."),
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

        // 1. Generate the timeline! (1 date if single, up to 16 if Season)
        final List<DateTime> eventDates = _generateSeasonDates(finalDateTime);

        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();

        Set<String> visibleToIds = {user.uid};
        Set<DocumentSnapshot> friendsToInvite = {};

        for (var friendDoc in friendsSnapshot.docs) {
          final data = friendDoc.data() as Map<String, dynamic>? ?? {};
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
                content: Text("No friends found in selected teams!"),
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        // --- THE DYNAMIC BATCH ENGINE ---
        WriteBatch batch = FirebaseFirestore.instance.batch();
        int operationCount = 0;

        // Helper to prevent Firebase from crashing if we exceed 500 writes!
        Future<void> commitBatchIfNeeded() async {
          if (operationCount > 450) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            operationCount = 0;
          }
        }

        // 2. Create the Season Parent (ONLY if it's recurring!)
        String? seasonId;
        DocumentReference? seasonRef;

        if (_isRecurring && eventDates.length > 1) {
          seasonRef = FirebaseFirestore.instance.collection('seasons').doc();
          seasonId = seasonRef.id;

          batch.set(seasonRef, {
            'hostId': user.uid,
            'coHostId': _selectedCoHostId,
            'title': _titleController.text.trim(),
            'location': _locController.text.trim(),
            'details': _detailsController.text.trim(),
            'frequency': _recurringFrequency,
            'totalInstances': eventDates.length,
            'createdAt': FieldValue.serverTimestamp(),
          });
          operationCount++;
        }

        List<DocumentReference> createdEventRefs = [];

        // 3. Loop through and create all the Hangouts!
        for (int i = 0; i < eventDates.length; i++) {
          final date = eventDates[i];
          final eventRef = FirebaseFirestore.instance
              .collection('events')
              .doc();
          createdEventRefs.add(eventRef);

          // Calculate exact end time
          int durationMinutes = _keepAliveDays > 0
              ? (_keepAliveDays * 24 * 60)
              : 240;
          DateTime endTime = date.add(Duration(minutes: durationMinutes));

          batch.set(eventRef, {
            'hostId': user.uid,
            'coHostId': _selectedCoHostId,
            'title': _titleController.text.trim(),
            'location': _locController.text.trim(),
            'details': _detailsController.text.trim(),
            'time': Timestamp.fromDate(date),
            'endTime': Timestamp.fromDate(endTime),
            'isPast': false,
            'created_at': FieldValue.serverTimestamp(),
            'visibleTo': visibleToIds.toList(),
            'inviteAll': _inviteAll,
            'invitedCircles': _selectedCircleIds,
            'isImportantDetails': _isImportantDetails,
            'rsvpDeadline': _rsvpDeadlineOffset,
            'keepAliveDays': _keepAliveDays,
            'pointsAwarded': false,
            'seasonId': seasonId,
            'seasonInstance': i + 1,
            'seasonTotal': eventDates.length,
          });
          operationCount++;
          await commitBatchIfNeeded();

          // Invitations for guests
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
            operationCount++;
          }
          await commitBatchIfNeeded();

          // Invitation for host
          final hostRef = eventRef.collection('invitations').doc(user.uid);
          batch.set(hostRef, {
            'uid': user.uid,
            'role': 'host',
            'status': 'going',
            'sentAt': FieldValue.serverTimestamp(),
          });
          operationCount++;
          await commitBatchIfNeeded();

          // Squad Needs (Roles)
          for (String roleTitle in _roles) {
            final roleRef = eventRef.collection('roles').doc();
            batch.set(roleRef, {
              'title': roleTitle,
              'addedBy': user.uid,
              'claimedByUid': null,
              'claimedByName': null,
              'createdAt': FieldValue.serverTimestamp(),
            });
            operationCount++;
          }
          await commitBatchIfNeeded();
        }

        // Commit any remaining operations
        if (operationCount > 0) {
          await batch.commit();
        }

        // 4. Handle Banner Upload (We only upload the image ONCE!)
        if (_bannerImagePath != null && createdEventRefs.isNotEmpty) {
          try {
            final File file = File(_bannerImagePath!);
            final Uint8List bytes = await file.readAsBytes();

            final Uint8List compressedBytes =
                await FlutterImageCompress.compressWithList(
                  bytes,
                  minWidth: 1280,
                  minHeight: 720,
                  quality: 75,
                );

            // Store image under the Season ID (if recurring) or the single event ID
            final String storageFolderId =
                seasonId ?? createdEventRefs.first.id;
            final Reference ref = FirebaseStorage.instance.ref().child(
              'event_banners/$storageFolderId/banner.jpg',
            );

            final UploadTask uploadTask = ref.putData(
              compressedBytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );

            final TaskSnapshot snapshot = await uploadTask;
            final String downloadUrl = await snapshot.ref.getDownloadURL();

            // Update the Season document
            if (seasonRef != null) {
              await seasonRef.update({'bannerUrl': downloadUrl});
            }

            // Fast-update ALL event documents with the shared URL
            WriteBatch urlBatch = FirebaseFirestore.instance.batch();
            int urlOps = 0;
            for (var eRef in createdEventRefs) {
              urlBatch.update(eRef, {'bannerUrl': downloadUrl});
              urlOps++;
              if (urlOps > 450) {
                await urlBatch.commit();
                urlBatch = FirebaseFirestore.instance.batch();
                urlOps = 0;
              }
            }
            if (urlOps > 0) await urlBatch.commit();
          } catch (e) {
            debugPrint("Failed to upload banner: $e");
          }
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                eventDates.length > 1
                    ? "Season created! ${eventDates.length} hangouts scheduled."
                    : "Invited ${friendsToInvite.length} squadmates!",
              ),
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

  // --- NEW: CARD WRAPPER UI ---
  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  // --- NEW: TACTILE CHIP ROW UI ---
  Widget _buildChipRow({
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required dynamic selectedValue,
    required Function(dynamic) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = selectedValue == opt['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(opt['label']),
                  selected: isSelected,
                  onSelected: (selected) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    if (selected) onSelected(opt['value']);
                  },
                  selectedColor: primaryColor.withValues(alpha: 0.15),
                  backgroundColor: isDark
                      ? Colors.grey.shade900
                      : Colors.grey.shade50,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? primaryColor
                        : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.5)
                        : (isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showBannerOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndCropBanner(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take a Photo"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndCropBanner(ImageSource.camera);
              },
            ),
            if (_bannerImagePath != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Remove Banner",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _bannerImagePath = null);
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropBanner(ImageSource source) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(
        ratioX: 16,
        ratioY: 9,
      ), // 👇 Locks to widescreen!
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Banner',
          toolbarColor: primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Adjust Banner',
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Save',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() => _bannerImagePath = croppedFile.path);
    }
  }

  Widget _buildBannerPicker(bool isDark, Color primaryColor) {
    final hasImage = _bannerImagePath != null;

    return GestureDetector(
      onTap: _showBannerOptions,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasImage
                    ? primaryColor
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                width: hasImage ? 2 : 1.5,
              ),
              image: hasImage
                  ? DecorationImage(
                      image: FileImage(File(_bannerImagePath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasImage
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Add Event Banner",
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "16:9 Widescreen",
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bannerPicker = _buildBannerPicker(isDark, primaryColor);
    final user = FirebaseAuth.instance.currentUser;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final dateString =
        "${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}";
    final timeString = _selectedTime.format(context);

    // --- FORM FIELDS ---
    final titleField = TextFormField(
      controller: _titleController,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 50,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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

    // The "Season" Toggle UI with Stepper
    final recurringToggle = Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isRecurring
              ? primaryColor
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: _isRecurring ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: primaryColor,
            title: const Text(
              "Keep it rolling",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Turn this into a recurring Season",
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            value: _isRecurring,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              setState(() => _isRecurring = val);
            },
          ),
          if (_isRecurring) ...[
            Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              height: 1,
            ),
            const SizedBox(height: 12),
            _buildChipRow(
              label: "Frequency",
              icon: Icons.autorenew,
              selectedValue: _recurringFrequency,
              onSelected: (val) {
                setState(() {
                  _recurringFrequency = val;
                  // Auto-clamp their instances if they switch to Monthly!
                  if (_recurringInstances > _maxRecurringInstances) {
                    _recurringInstances = _maxRecurringInstances;
                  }
                });
              },
              options: [
                {'label': 'Weekly', 'value': 'weekly'},
                {'label': 'Bi-Weekly', 'value': 'biweekly'},
                {'label': 'Monthly', 'value': 'monthly'},
              ],
            ),
            const SizedBox(height: 16),

            // The Tactile Stepper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Hangouts",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _recurringInstances > 2
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() => _recurringInstances--);
                              }
                            : null,
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: _recurringInstances > 2
                              ? primaryColor
                              : Colors.grey,
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          "$_recurringInstances",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _recurringInstances < _maxRecurringInstances
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() => _recurringInstances++);
                              }
                            : null,
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: _recurringInstances < _maxRecurringInstances
                              ? primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );

    final detailsField = TextFormField(
      controller: _detailsController,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 500,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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

    // --- TACTILE ACTIONS FOR "THE VIBE" CARD ---
    final togglesRow = Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _showRolesDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _roles.isNotEmpty
                      ? primaryColor
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
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
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isImportantDetails
                      ? Colors.red
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  width: _isImportantDetails ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isImportantDetails
                        ? Icons.gpp_maybe
                        : Icons.gpp_maybe_outlined,
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

    // --- PRE-BUILD THE CARDS ---

    final vitalsCard = _buildFormCard(
      title: "The Vitals",
      icon: Icons.push_pin,
      child: Column(
        children: [
          titleField,
          const SizedBox(height: 16),
          locationField,
          const SizedBox(height: 16),
          dateTimeRow,
          recurringToggle,
        ],
      ),
    );

    final extrasCard = _buildFormCard(
      title: "The Extras",
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipRow(
            label: "Active for...",
            icon: Icons.timelapse,
            selectedValue: _keepAliveDays,
            onSelected: (val) => setState(() => _keepAliveDays = val),
            options: [
              {'label': 'A few hours', 'value': 0},
              {'label': '1 Day', 'value': 1},
              {'label': '2 Days', 'value': 2},
              {'label': '3 Days', 'value': 3},
              {'label': '4 Days', 'value': 4},
              {'label': '5 Days', 'value': 5},
              {'label': '1 Week', 'value': 7},
              {'label': '10 Days', 'value': 10},
            ],
          ),
          const SizedBox(height: 24),
          _buildChipRow(
            label: "RSVP Deadline",
            icon: Icons.timer_off_outlined,
            selectedValue: _rsvpDeadlineOffset,
            onSelected: (val) => setState(() => _rsvpDeadlineOffset = val),
            options: [
              {'label': 'On time', 'value': 0},
              {'label': '30 mins before', 'value': -30},
              {'label': '1 hr before', 'value': -60},
              {'label': '2 hrs before', 'value': -120},
              {'label': '4 hrs before', 'value': -240},
              {'label': '6 hrs before', 'value': -360},
              {'label': '24 hrs before', 'value': -1440},
            ],
          ),
          const SizedBox(height: 24),
          detailsField,
          const SizedBox(height: 16),
          togglesRow,
          const SizedBox(height: 24),
        ],
      ),
    );

    final crewCard = user == null
        ? const SizedBox.shrink()
        : _buildFormCard(
            title: "The Crew",
            icon: Icons.group,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('circles')
                  .snapshots(),
              builder: (context, snapshot) {
                final circles = snapshot.hasData
                    ? snapshot.data!.docs.toList()
                    : <DocumentSnapshot>[];

                circles.sort((a, b) {
                  final nameA =
                      (a.data() as Map<String, dynamic>)['name']
                          ?.toString()
                          .toLowerCase() ??
                      '';
                  final nameB =
                      (b.data() as Map<String, dynamic>)['name']
                          ?.toString()
                          .toLowerCase() ??
                      '';
                  return nameA.compareTo(nameB);
                });

                String targetPreviewText = "Select Teams...";
                if (_inviteAll) {
                  targetPreviewText = "Entire Squad";
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
                      : "Selected Teams";
                }

                final circlesField = InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showCircleDialog(circles),
                  child: InputDecorator(
                    decoration: _buildInputDecoration(
                      label: "Who's getting the i?",
                      prefixIcon: Icon(
                        Icons.people,
                        color: isDark ? Colors.tealAccent : Colors.teal,
                      ),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      targetPreviewText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                      label: "Add Co-Captain (optional)",
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
                      _selectedCoHostName ?? "Select a squadmate...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _selectedCoHostId != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );

                return Column(
                  children: [
                    circlesField,
                    const SizedBox(height: 16),
                    coHostField,
                  ],
                );
              },
            ),
          );

    final submitButton = SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _saveEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: themeProvider.onPrimaryColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text(
          "send out the i's",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Let's do...",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                      // --- DYNAMIC RESPONSIVE LAYOUT ---
                      if (isLandscape)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [bannerPicker, vitalsCard, crewCard],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: Column(children: [extrasCard])),
                          ],
                        )
                      else
                        Column(
                          children: [
                            bannerPicker,
                            vitalsCard,
                            extrasCard,
                            crewCard,
                          ],
                        ),

                      const SizedBox(height: 12),
                      submitButton,
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
