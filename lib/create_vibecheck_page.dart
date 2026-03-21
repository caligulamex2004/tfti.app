import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_provider.dart';
import 'friend_circles_page.dart';
import 'location_search_page.dart';

class CreateVibeCheckPage extends StatefulWidget {
  const CreateVibeCheckPage({super.key});

  @override
  State<CreateVibeCheckPage> createState() => _CreateVibeCheckPageState();
}

class _CreateVibeCheckPageState extends State<CreateVibeCheckPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _inviteAll = false;
  final List<String> _selectedCircleIds = [];
  bool _isLoading = false;
  int _rsvpDeadlineOffset = -60; // Default to 1 hr before for Vibe Checks

  // Dynamic list of poll options
  final List<Map<String, TextEditingController>> _pollOptions = [
    {'title': TextEditingController(), 'location': TextEditingController()},
    {'title': TextEditingController(), 'location': TextEditingController()},
  ];

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
    _detailsController.dispose();
    for (var option in _pollOptions) {
      option['title']?.dispose();
      option['location']?.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_pollOptions.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum of 5 options allowed.")),
      );
      return;
    }
    setState(() {
      _pollOptions.add({
        'title': TextEditingController(),
        'location': TextEditingController(),
      });
    });
  }

  void _removeOption(int index) {
    if (_pollOptions.length <= 2) return;
    setState(() {
      _pollOptions[index]['title']?.dispose();
      _pollOptions[index]['location']?.dispose();
      _pollOptions.removeAt(index);
    });
  }

  // --- NEW: SMART LOCATION SEARCH FOR POLL OPTIONS ---
  Future<void> _selectOptionLocation(int index) async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationSearchPage()),
    );

    if (selectedAddress != null) {
      setState(() {
        _pollOptions[index]['location']!.text = selectedAddress;
      });
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
      counterText: "",
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
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
              title: const Text("Who's getting the feeler?"),
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
                          if (val) _selectedCircleIds.clear();
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
                              if (_selectedCircleIds.isEmpty) _inviteAll = true;
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

  Future<void> _saveVibeCheck() async {
    if (!_formKey.currentState!.validate()) return;

    int validOptions = 0;
    List<Map<String, dynamic>> finalPollOptions = [];

    for (int i = 0; i < _pollOptions.length; i++) {
      final title = _pollOptions[i]['title']!.text.trim();
      final location = _pollOptions[i]['location']!.text.trim();

      if (title.isNotEmpty) {
        validOptions++;
        finalPollOptions.add({
          'id': 'opt_$i',
          'title': title,
          'location': location.isNotEmpty ? location : "TBD",
        });
      }
    }

    if (validOptions < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill out at least two Activity Options."),
        ),
      );
      return;
    }

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
            'type': 'vibe_check',
            'pollOptions': finalPollOptions,
            'lockedOptionId': null,
            'isTieBreakerNeeded': false,
            'hostId': user.uid,
            'title': _titleController.text.trim(),
            'details': _detailsController.text.trim(),
            'time': Timestamp.fromDate(finalDateTime),
            'created_at': FieldValue.serverTimestamp(),
            'visibleTo': visibleToIds.toList(),
            'inviteAll': _inviteAll,
            'invitedCircles': _selectedCircleIds,
            'rsvpDeadline': _rsvpDeadlineOffset,
          });

      final batch = FirebaseFirestore.instance.batch();

      for (var friendDoc in friendsToInvite) {
        final inviteRef = eventRef.collection('invitations').doc(friendDoc.id);
        batch.set(inviteRef, {
          'uid': friendDoc.id,
          'role': 'guest',
          'status': 'pending',
          'votes': [],
          'sentAt': FieldValue.serverTimestamp(),
        });
      }

      final hostRef = eventRef.collection('invitations').doc(user.uid);
      batch.set(hostRef, {
        'uid': user.uid,
        'role': 'host',
        'status': 'going',
        'votes': ['whatever'],
        'sentAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Feeler sent out! 🎣"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
        label: "What's the vibe?",
        hint: "e.g. Sunday Funday, Post-Work Drinks",
        prefixIcon: Icon(Symbols.campaign, color: primaryColor),
      ),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );

    final dateTimeRow = Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _buildInputDecoration(
                label: "When?",
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
                label: "Roughly what time?",
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
        label: "Lock it in automatically...",
        prefixIcon: Icon(Icons.auto_awesome, color: primaryColor),
      ),
      dropdownColor: Theme.of(context).cardColor,
      items: const [
        DropdownMenuItem(value: -1440, child: Text("24 hours before")),
        DropdownMenuItem(value: -240, child: Text("4 hours before")),
        DropdownMenuItem(value: -120, child: Text("2 hours before")),
        DropdownMenuItem(value: -60, child: Text("1 hour before (Default)")),
        DropdownMenuItem(value: -30, child: Text("30 mins before")),
        DropdownMenuItem(value: 0, child: Text("At event start")),
      ],
      onChanged: (val) => setState(() => _rsvpDeadlineOffset = val ?? -60),
    );

    final detailsField = TextFormField(
      controller: _detailsController,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 300,
      decoration: _buildInputDecoration(
        label: "Any other details? (Optional)",
        hint: "e.g. Dog friendly, BYOB...",
        prefixIcon: Icon(
          Icons.notes,
          color: isDark ? Colors.grey.shade400 : Colors.grey,
        ),
      ).copyWith(alignLabelWithHint: true),
      maxLines: 2,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Vibe Check"),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildResponsiveRow(isLandscape, titleField, dateTimeRow),
                      _buildResponsiveRow(isLandscape, detailsField, rsvpField),

                      const SizedBox(height: 10),
                      Text(
                        "Activity Options",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Guests will vote on these options. The winner gets locked in automatically.",
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dynamic List of Poll Options
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pollOptions.length,
                        itemBuilder: (context, index) {
                          return Card(
                            elevation: isDark ? 1 : 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isDark
                                  ? BorderSide(color: Colors.grey.shade800)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Option ${index + 1}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (index > 1)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed: () => _removeOption(index),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _pollOptions[index]['title'],
                                    maxLength: 30,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      hintText: "Activity (e.g. Disc Golf)",
                                      counterText: "",
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // --- UPDATED LOCATION INPUT ---
                                  TextFormField(
                                    controller: _pollOptions[index]['location'],
                                    readOnly: true,
                                    onTap: () => _selectOptionLocation(index),
                                    maxLength: 100,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      hintText:
                                          "Tap to search address... (Optional)",
                                      counterText: "",
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade100,
                                      prefixIcon: const Icon(
                                        Icons.location_on,
                                        size: 18,
                                      ),
                                      suffixIcon:
                                          _pollOptions[index]['location']!
                                              .text
                                              .isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                size: 18,
                                              ),
                                              onPressed: () => setState(
                                                () =>
                                                    _pollOptions[index]['location']!
                                                        .clear(),
                                              ),
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      if (_pollOptions.length < 5)
                        Center(
                          child: TextButton.icon(
                            onPressed: _addOption,
                            icon: Icon(Icons.add_circle, color: primaryColor),
                            label: Text(
                              "Add another option",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

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

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showCircleDialog(circles),
                              child: InputDecorator(
                                decoration: _buildInputDecoration(
                                  label: "Who's getting the feeler?",
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
                          },
                        ),
                      ],

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _saveVibeCheck,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: themeProvider.onPrimaryColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Throw it out there",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
