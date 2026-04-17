import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/theme_provider.dart';
import '../components/shared/rpg_glass_card.dart';
import '../components/forms/custom_input_field.dart';
import '../components/forms/tactile_chip_row.dart';
import '../components/forms/date_time_row.dart';
import '../components/forms/vibe_options_card.dart';
import 'places_search_page.dart';
import 'teams_page.dart'; // Needed for CircleMembersPage routing

class VibeCheckEditorPage extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? eventData; // If null, it's a NEW Vibe Check!

  const VibeCheckEditorPage({super.key, this.eventId, this.eventData});

  @override
  State<VibeCheckEditorPage> createState() => _VibeCheckEditorPageState();
}

class _VibeCheckEditorPageState extends State<VibeCheckEditorPage> {
  final _formKey = GlobalKey<FormState>();

  // Page State
  bool get isEditing => widget.eventData != null;
  bool _isLoading = false;

  // Form Controllers
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _inviteAll = false;
  List<String> _selectedCircleIds = [];
  int _rsvpDeadlineOffset = -60; // Default: 1 hour before

  // Dynamic list of poll options holding the ID and the text controllers
  final List<Map<String, dynamic>> _pollOptions = [];

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      // --- EDIT MODE INITIALIZATION ---
      final data = widget.eventData!;
      _titleController.text = data['title'] ?? '';
      _detailsController.text = data['details'] ?? '';

      if (data['time'] != null) {
        final dt = (data['time'] as Timestamp).toDate();
        _selectedDate = dt;
        _selectedTime = TimeOfDay.fromDateTime(dt);
      }

      _rsvpDeadlineOffset = data['rsvpDeadline'] ?? -60;
      _inviteAll = data['inviteAll'] ?? true;
      _selectedCircleIds = List<String>.from(data['invitedCircles'] ?? []);

      final List<dynamic> existingOptions = data['pollOptions'] ?? [];
      for (var opt in existingOptions) {
        _pollOptions.add({
          'id': opt['id'],
          'title': TextEditingController(text: opt['title']),
          'location': TextEditingController(
            text: opt['location'] == 'TBD' ? '' : opt['location'],
          ),
        });
      }
    } else {
      // --- CREATE MODE INITIALIZATION ---
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

    // Always ensure at least 2 empty options are available to start
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

  // --- VIBE OPTION METHODS ---

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
    if (_pollOptions.length <= 2) {
      return;
    }
    setState(() {
      (_pollOptions[index]['title'] as TextEditingController).dispose();
      (_pollOptions[index]['location'] as TextEditingController).dispose();
      _pollOptions.removeAt(index);
    });
  }

  Future<void> _selectOptionLocation(int index) async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlacesSearchPage()),
    );
    if (selectedAddress != null && mounted) {
      setState(() {
        (_pollOptions[index]['location'] as TextEditingController).text =
            selectedAddress;
      });
    }
  }

  void _clearOptionLocation(int index) {
    setState(() {
      (_pollOptions[index]['location'] as TextEditingController).clear();
    });
  }

  // --- RESTORED CREW LOGIC ---
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
              if (nameController.text.trim().isEmpty) {
                return;
              }
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

              if (!ctx.mounted) {
                return;
              }
              Navigator.pop(ctx); // Close Dialog

              if (!mounted) {
                return;
              }

              setState(() {
                _selectedCircleIds.add(docRef.id);
                _inviteAll = false;
              });

              Navigator.pop(context); // Close the Circle selection sheet

              // Open the team builder page!
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
                          if (val) {
                            _selectedCircleIds.clear();
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

  // --- DATABASE METHODS ---

  Future<void> _submitVibeCheck() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate Vibe Options
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
    if (user == null) {
      return;
    }

    try {
      final newDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final batch = FirebaseFirestore.instance.batch();

      if (isEditing) {
        // ==========================================
        //         EDIT MODE (UPDATE VIBE CHECK)
        // ==========================================
        final int keepAliveDays = widget.eventData!['keepAliveDays'] ?? 0;
        final int durationMinutes = keepAliveDays > 0
            ? (keepAliveDays * 24 * 60)
            : 240;
        final newEndTime = newDateTime.add(Duration(minutes: durationMinutes));

        final Map<String, dynamic> updateData = {
          'title': _titleController.text.trim(),
          'details': _detailsController.text.trim(),
          'time': Timestamp.fromDate(newDateTime),
          'endTime': Timestamp.fromDate(newEndTime),
          'pollOptions': finalPollOptions,
          'rsvpDeadline': _rsvpDeadlineOffset,
          'inviteAll': _inviteAll,
          'invitedCircles': _selectedCircleIds,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };

        // Dynamic Invite Sync
        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();
        Set<String> newIntendedIds = {};
        Set<String> oldIntendedIds = {};

        final bool oldInviteAll = widget.eventData!['inviteAll'] ?? true;
        final List<String> oldCircles = List<String>.from(
          widget.eventData!['invitedCircles'] ?? [],
        );

        for (var friendDoc in friendsSnapshot.docs) {
          final friendCircles = List<String>.from(
            friendDoc.data()['circles'] ?? [],
          );
          if (_inviteAll ||
              _selectedCircleIds.any((id) => friendCircles.contains(id))) {
            newIntendedIds.add(friendDoc.id);
          }
          if (oldInviteAll ||
              oldCircles.any((id) => friendCircles.contains(id))) {
            oldIntendedIds.add(friendDoc.id);
          }
        }

        final currentInvitesSnap = await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .collection('invitations')
            .get();
        final Set<String> currentlyInvitedIds = currentInvitesSnap.docs
            .map((d) => d.id)
            .toSet();

        Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
        Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);
        toRemove.remove(widget.eventData!['hostId']);

        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId);

        if (toAdd.isNotEmpty) {
          updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
          for (String uid in toAdd) {
            if (!currentlyInvitedIds.contains(uid)) {
              batch.set(eventRef.collection('invitations').doc(uid), {
                'uid': uid,
                'role': 'guest',
                'status': 'pending',
                'votes': [],
                'sentAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        if (toRemove.isNotEmpty) {
          updateData['visibleTo'] = FieldValue.arrayRemove(toRemove.toList());
          for (String uid in toRemove) {
            batch.delete(eventRef.collection('invitations').doc(uid));
          }
        }

        batch.update(eventRef, updateData);
        batch.set(
          eventRef.collection('invitations').doc(user.uid),
          {'lastViewedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      } else {
        // ==========================================
        //        CREATE MODE (NEW VIBE CHECK)
        // ==========================================
        final defaultEndTime = newDateTime.add(const Duration(hours: 4));
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
          }
          setState(() => _isLoading = false);
          return;
        }

        final eventRef = FirebaseFirestore.instance.collection('events').doc();
        batch.set(eventRef, {
          'type': 'vibe_check',
          'pollOptions': finalPollOptions,
          'lockedOptionId': null,
          'isTieBreakerNeeded': false,
          'hostId': user.uid,
          'title': _titleController.text.trim(),
          'details': _detailsController.text.trim(),
          'time': Timestamp.fromDate(newDateTime),
          'endTime': Timestamp.fromDate(defaultEndTime),
          'keepAliveDays': 0,
          'pointsAwarded': false,
          'created_at': FieldValue.serverTimestamp(),
          'visibleTo': visibleToIds.toList(),
          'inviteAll': _inviteAll,
          'invitedCircles': _selectedCircleIds,
          'rsvpDeadline': _rsvpDeadlineOffset,
        });

        for (var friendDoc in friendsToInvite) {
          batch.set(eventRef.collection('invitations').doc(friendDoc.id), {
            'uid': friendDoc.id,
            'role': 'guest',
            'status': 'pending',
            'votes': [],
            'sentAt': FieldValue.serverTimestamp(),
          });
        }

        batch.set(eventRef.collection('invitations').doc(user.uid), {
          'uid': user.uid,
          'role': 'host',
          'status': 'going',
          'votes': ['placeholder'],
          'sentAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? "Changes saved!" : "Feeler sent out! 🎣"),
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId);

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
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _showConvertDialog() async {
    setState(() => _isLoading = true);

    Map<String, int> voteCounts = {};
    try {
      final invitesSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('invitations')
          .get();
      for (var doc in invitesSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'declined') {
          continue;
        }
        final votes = List<String>.from(data['votes'] ?? []);
        for (String optId in votes) {
          voteCounts[optId] = (voteCounts[optId] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint("Error fetching votes: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    List<Map<String, dynamic>> validOptions = [];
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
        validOptions.add({
          'id': id,
          'title': title,
          'location': location.isNotEmpty ? location : "TBD",
          'votes': voteCounts[id] ?? 0,
        });
      }
    }

    if (validOptions.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please provide at least two Activity Options before converting.",
            ),
          ),
        );
      }
      return;
    }

    validOptions.sort(
      (a, b) => (b['votes'] as int).compareTo(a['votes'] as int),
    );

    if (!mounted) {
      return;
    }
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select the Winner"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: validOptions.map((opt) {
            return ListTile(
              leading: const Icon(Icons.workspace_premium, color: Colors.amber),
              title: Text(
                opt['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                opt['location'] == 'TBD' ? 'No location' : opt['location'],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${opt['votes']} Votes",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmConvert(opt);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmConvert(Map<String, dynamic> option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Lock In Winner?"),
        content: Text(
          "Are you sure you want to lock in '${option['title']}'?\n\nThis will instantly close the voting and convert this Vibe Check into a finalized Hangout. RSVPs will automatically update for anyone who voted for this option.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text(
              "Lock In",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId);

      batch.update(eventRef, {
        'type': 'event',
        'lockedOptionId': option['id'],
        'title': option['title'],
        'location': option['location'],
        'isTieBreakerNeeded': false,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      final invitesSnap = await eventRef.collection('invitations').get();
      for (var doc in invitesSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'declined') {
          continue;
        }

        final votes = List<String>.from(data['votes'] ?? []);
        String newStatus = votes.contains(option['id']) ? 'going' : 'pending';

        if (data['role'] == 'host' || data['role'] == 'co-host') {
          newStatus = 'going';
        }
        batch.update(doc.reference, {'status': newStatus});
      }

      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI HELPER METHODS ---

  // Custom Input Decoration for inline forms (restored from old logic)
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Widget _buildVitalsCard(bool isDark, Color primaryColor) {
    return RpgGlassCard(
      title: "The Vitals",
      icon: Icons.push_pin,
      child: Column(
        children: [
          CustomInputField(
            controller: _titleController,
            label: "What's the vibe?",
            hint: "e.g. Sunday Funday, Post-Work Drinks",
            prefixIcon: Symbols.campaign,
            validator: (v) {
              if (v!.isEmpty) {
                return "Required";
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DateTimeRow(
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            onDateChanged: (d) {
              setState(() => _selectedDate = d);
            },
            onTimeChanged: (t) {
              setState(() => _selectedTime = t);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasCard(bool isDark, Color primaryColor) {
    return RpgGlassCard(
      title: "The Extras",
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TactileChipRow<int>(
            label: "Voting Deadline",
            icon: Icons.timer_off_outlined,
            options: const [
              {'label': 'On time', 'value': 0},
              {'label': '30 mins before', 'value': -30},
              {'label': '1 hr before', 'value': -60},
              {'label': '2 hrs before', 'value': -120},
              {'label': '4 hrs before', 'value': -240},
              {'label': '24 hrs before', 'value': -1440},
              {'label': '48 hrs before', 'value': -2880},
            ],
            selectedValue: _rsvpDeadlineOffset,
            onSelected: (v) => setState(() => _rsvpDeadlineOffset = v),
          ),
          const SizedBox(height: 24),
          CustomInputField(
            controller: _detailsController,
            label: "Any other details? (Optional)",
            hint: "e.g. Dog friendly, BYOB...",
            prefixIcon: Icons.notes,
            prefixIconColor: isDark ? Colors.grey.shade400 : Colors.grey,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCrewCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RpgGlassCard(
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

          String targetPreviewText = "Select Squads...";
          if (_inviteAll) {
            targetPreviewText = "Entire Squad";
          } else if (_selectedCircleIds.isNotEmpty) {
            final selectedNames = circles
                .where((c) => _selectedCircleIds.contains(c.id))
                .map(
                  (c) =>
                      (c.data() as Map<String, dynamic>)['name'] ?? 'Unnamed',
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
  }

  Widget _buildHostActionsCard(bool isDark) {
    if (!isEditing) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: RpgGlassCard(
        title: "Host Actions",
        icon: Icons.admin_panel_settings,
        iconColor: Colors.amber,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _showConvertDialog,
                icon: Icon(
                  Icons.done_all,
                  color: isDark ? Colors.greenAccent : Colors.green,
                ),
                label: Text(
                  "Lock In Winner & Convert",
                  style: TextStyle(
                    color: isDark ? Colors.greenAccent : Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark
                        ? Colors.greenAccent.withValues(alpha: 0.5)
                        : Colors.green.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final String appBarTitle = isEditing ? "Edit Vibe Check" : "Vibe Check";
    final String submitText = isEditing ? "Save Changes" : "Throw it out there";

    final submitButton = SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitVibeCheck,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: themeProvider.onPrimaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                submitText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: isLandscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildVitalsCard(isDark, primaryColor),
                              _buildExtrasCard(isDark, primaryColor),
                              _buildCrewCard(),
                              _buildHostActionsCard(isDark),
                              const SizedBox(height: 12),
                              submitButton,
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
                              // NEW COMPONENT IMPORTED
                              VibeOptionsCard(
                                pollOptions: _pollOptions,
                                onAddOption: _addOption,
                                onRemoveOption: _removeOption,
                                onSelectLocation: _selectOptionLocation,
                                onClearLocation: _clearOptionLocation,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildVitalsCard(isDark, primaryColor),
                        // NEW COMPONENT IMPORTED
                        VibeOptionsCard(
                          pollOptions: _pollOptions,
                          onAddOption: _addOption,
                          onRemoveOption: _removeOption,
                          onSelectLocation: _selectOptionLocation,
                          onClearLocation: _clearOptionLocation,
                        ),
                        _buildExtrasCard(isDark, primaryColor),
                        _buildCrewCard(),
                        _buildHostActionsCard(isDark),
                        const SizedBox(height: 12),
                        submitButton,
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
