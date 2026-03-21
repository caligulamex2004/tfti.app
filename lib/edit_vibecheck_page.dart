import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_provider.dart';
import 'friend_circles_page.dart';

class EditVibeCheckPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EditVibeCheckPage({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EditVibeCheckPage> createState() => _EditVibeCheckPageState();
}

class _EditVibeCheckPageState extends State<EditVibeCheckPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _detailsController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _inviteAll = false;
  List<String> _selectedCircleIds = [];
  bool _isLoading = false;

  int _rsvpDeadlineOffset = -60;

  // Dynamic list of poll options holding the ID and the text controllers
  final List<Map<String, dynamic>> _pollOptions = [];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.eventData['title']);
    _detailsController = TextEditingController(
      text: widget.eventData['details'],
    );

    if (widget.eventData['time'] != null) {
      Timestamp ts = widget.eventData['time'];
      DateTime dt = ts.toDate();
      _selectedDate = dt;
      _selectedTime = TimeOfDay.fromDateTime(dt);
    }

    _rsvpDeadlineOffset = widget.eventData['rsvpDeadline'] ?? -60;
    _inviteAll = widget.eventData['inviteAll'] ?? true;
    _selectedCircleIds = List<String>.from(
      widget.eventData['invitedCircles'] ?? [],
    );

    // Load existing poll options and preserve their IDs so votes aren't lost
    final List<dynamic> existingOptions = widget.eventData['pollOptions'] ?? [];
    for (var opt in existingOptions) {
      _pollOptions.add({
        'id': opt['id'],
        'title': TextEditingController(text: opt['title']),
        'location': TextEditingController(
          text: opt['location'] == 'TBD' ? '' : opt['location'],
        ),
      });
    }

    // Ensure there are at least 2 fields showing, even if data is missing
    while (_pollOptions.length < 2) {
      _pollOptions.add({
        'id': null, // Will be generated on save
        'title': TextEditingController(),
        'location': TextEditingController(),
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    for (var option in _pollOptions) {
      (option['title'] as TextEditingController).dispose();
      (option['location'] as TextEditingController).dispose();
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
        'id': null,
        'title': TextEditingController(),
        'location': TextEditingController(),
      });
    });
  }

  void _removeOption(int index) {
    if (_pollOptions.length <= 2) return;

    // Note: If an option with existing votes is removed, those votes will just
    // be ignored by the UI since the ID no longer exists in the pollOptions array.
    setState(() {
      (_pollOptions[index]['title'] as TextEditingController).dispose();
      (_pollOptions[index]['location'] as TextEditingController).dispose();
      _pollOptions.removeAt(index);
    });
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

  Future<void> _deleteVibeCheck() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vibe Check?'),
        content: const Text(
          'This will permanently delete the feeler, the votes, and the chat history.',
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

  Future<void> _updateVibeCheck() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    int validOptions = 0;
    List<Map<String, dynamic>> finalPollOptions = [];

    for (int i = 0; i < _pollOptions.length; i++) {
      final title = (_pollOptions[i]['title'] as TextEditingController).text
          .trim();
      final location = (_pollOptions[i]['location'] as TextEditingController)
          .text
          .trim();

      // Keep original ID if it exists, otherwise generate a new one for newly added options
      final id =
          _pollOptions[i]['id'] ??
          'opt_${DateTime.now().millisecondsSinceEpoch}_$i';

      if (title.isNotEmpty) {
        validOptions++;
        finalPollOptions.add({
          'id': id,
          'title': title,
          'location': location.isNotEmpty ? location : "TBD",
        });
      }
    }

    if (validOptions < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide at least two Activity Options."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final newDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final Map<String, dynamic> updateData = {
        'title': _titleController.text.trim(),
        'details': _detailsController.text.trim(),
        'time': Timestamp.fromDate(newDateTime),
        'pollOptions': finalPollOptions,
        'rsvpDeadline': _rsvpDeadlineOffset,
        'inviteAll': _inviteAll,
        'invitedCircles': _selectedCircleIds,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };

      // Diff the Guest List
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();

      Set<String> newIntendedIds = {};
      Set<String> oldIntendedIds = {};

      final bool oldInviteAll = widget.eventData['inviteAll'] ?? true;
      final List<String> oldCircles = List<String>.from(
        widget.eventData['invitedCircles'] ?? [],
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

      toRemove.remove(widget.eventData['hostId']); // Never remove the host

      final batch = FirebaseFirestore.instance.batch();
      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId);

      if (toAdd.isNotEmpty) {
        updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
        for (String uid in toAdd) {
          batch.set(eventRef.collection('invitations').doc(uid), {
            'uid': uid,
            'role': 'guest',
            'status': 'pending',
            'votes': [],
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

      batch.update(eventRef, updateData);
      await batch.commit();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    final dateString = _selectedDate != null
        ? "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}"
        : "Select Date";
    final timeString = _selectedTime != null
        ? _selectedTime!.format(context)
        : "Select Time";

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
        title: const Text("Edit Vibe Check"),
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
                                    controller:
                                        _pollOptions[index]['title']
                                            as TextEditingController,
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
                                  TextFormField(
                                    controller:
                                        _pollOptions[index]['location']
                                            as TextEditingController,
                                    maxLength: 50,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      hintText: "Location (Optional)",
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
                          },
                        ),
                      ],

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _updateVibeCheck,
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
                          onPressed: _deleteVibeCheck,
                          icon: Icon(
                            Icons.delete,
                            color: isDark ? Colors.redAccent : Colors.red,
                          ),
                          label: Text(
                            "Delete Vibe Check",
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
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
