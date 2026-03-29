import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_provider.dart';
import 'friend_circles_page.dart';
import 'location_search_page.dart';

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

    while (_pollOptions.length < 2) {
      _pollOptions.add({
        'id': null,
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

    setState(() {
      (_pollOptions[index]['title'] as TextEditingController).dispose();
      (_pollOptions[index]['location'] as TextEditingController).dispose();
      _pollOptions.removeAt(index);
    });
  }

  Future<void> _selectOptionLocation(int index) async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationSearchPage()),
    );

    if (selectedAddress != null) {
      setState(() {
        (_pollOptions[index]['location'] as TextEditingController).text =
            selectedAddress;
      });
    }
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
    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;

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
        title: const Text("New Team"),
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
                        "Entire Squad",
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
                        "Create New Team",
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

      // Only protect the host from being removed
      toRemove.remove(widget.eventData['hostId']);

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
                label: "What time?",
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

    // --- CARDS ---

    final vitalsCard = _buildFormCard(
      title: "The Vitals",
      icon: Icons.push_pin,
      child: Column(
        children: [titleField, const SizedBox(height: 16), dateTimeRow],
      ),
    );

    final optionsCard = _buildFormCard(
      title: "Vibe Options",
      icon: Icons.format_list_bulleted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Pick some ideas and let the crew decide! You can always update the options later if plans change.",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                elevation: 0,
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Option ${index + 1}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
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
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: "Activity (e.g. Disc Golf)",
                          counterText: "",
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
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
                        readOnly: true,
                        onTap: () => _selectOptionLocation(index),
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: "Tap to search address... (Optional)",
                          counterText: "",
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          prefixIcon: const Icon(Icons.location_on, size: 18),
                          suffixIcon:
                              (_pollOptions[index]['location']
                                      as TextEditingController)
                                  .text
                                  .isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(
                                    () =>
                                        (_pollOptions[index]['location']
                                                as TextEditingController)
                                            .clear(),
                                  ),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
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
        ],
      ),
    );

    final extrasCard = _buildFormCard(
      title: "The Extras",
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          detailsField,
          const SizedBox(height: 24),
          _buildChipRow(
            label: "Voting Deadline",
            icon: Icons.timer_off_outlined,
            selectedValue: _rsvpDeadlineOffset,
            onSelected: (val) => setState(() => _rsvpDeadlineOffset = val),
            options: [
              {'label': 'At start time', 'value': 0},
              {'label': '30 mins before', 'value': -30},
              {'label': '1 hr before (Default)', 'value': -60},
              {'label': '2 hrs before', 'value': -120},
              {'label': '4 hrs before', 'value': -240},
              {'label': '24 hrs before', 'value': -1440},
            ],
          ),
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
                    ? snapshot.data!.docs
                    : <DocumentSnapshot>[];

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

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showCircleDialog(circles),
                  child: InputDecorator(
                    decoration: _buildInputDecoration(
                      label: "Update Squad List",
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
              },
            ),
          );

    final actionButtons = Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _updateVibeCheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: themeProvider.onPrimaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Save Changes",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                color: isDark
                    ? Colors.redAccent.withValues(alpha: 0.5)
                    : Colors.red.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Edit Vibe Check",
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
                                children: [
                                  vitalsCard,
                                  extrasCard,
                                  crewCard,
                                  actionButtons,
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: Column(children: [optionsCard])),
                          ],
                        )
                      else
                        Column(
                          children: [
                            vitalsCard,
                            optionsCard,
                            extrasCard,
                            crewCard,
                            const SizedBox(height: 12),
                            actionButtons,
                          ],
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
