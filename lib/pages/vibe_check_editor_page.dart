import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../components/forms/vibe_options_card.dart';
import '../components/forms/crew_form_card.dart';
import '../components/forms/vibe_host_actions_card.dart';
import '../components/forms/vitals_form_card.dart';
import '../components/forms/extras_form_card.dart';
import '../utils/event_service.dart';
import '../utils/theme_provider.dart';
import 'places_search_page.dart';

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

  // Co-Captain State
  String? _selectedCoHostId;
  String? _selectedCoHostName;
  String? _selectedCoHostUsername;
  String? _selectedCoHostAvatarUrl;
  int? _selectedCoHostAvatarColor;

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

      _selectedCoHostId = data['coHostId'];
      _selectedCoHostName = data['coHostName'];

      // Fetch Co-Host Avatar & Username silently if one exists
      if (_selectedCoHostId != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(_selectedCoHostId)
            .get()
            .then((doc) {
              if (mounted && doc.exists) {
                setState(() {
                  _selectedCoHostUsername = doc.data()?['username'];
                  _selectedCoHostAvatarUrl = doc.data()?['avatarUrl'];
                  _selectedCoHostAvatarColor = doc.data()?['avatarColor'];
                });
              }
            });
      }

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

    setState(() {
      _isLoading = true;
    });
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

        // --- THE MISSING CRITICAL CHANGE DETECTOR FOR VIBE CHECKS ---
        List<String> changedFields = [];
        List<String> oldValues = [];
        List<String> newValues = [];

        // Helper to format dates cleanly
        String formatDateTime(DateTime dt) {
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          final hour = dt.hour > 12
              ? dt.hour - 12
              : (dt.hour == 0 ? 12 : dt.hour);
          final min = dt.minute.toString().padLeft(2, '0');
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          return '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
        }

        // Helper to format options dynamically
        String formatOptions(List<dynamic> opts) {
          return opts
              .map((opt) {
                if (opt is! Map) return '';
                final title = opt['title'] ?? 'Option';
                final loc = opt['location'];
                if (loc != null &&
                    loc.toString().trim().isNotEmpty &&
                    loc != 'TBD') {
                  return '$title ($loc)';
                }
                return title.toString();
              })
              .join(", ");
        }

        // 1. Check Date/Time
        final oldTimeTs = widget.eventData!['time'] as Timestamp?;
        if (oldTimeTs != null) {
          final oldDt = oldTimeTs.toDate();
          if (oldDt.year != newDateTime.year ||
              oldDt.month != newDateTime.month ||
              oldDt.day != newDateTime.day ||
              oldDt.hour != newDateTime.hour ||
              oldDt.minute != newDateTime.minute) {
            changedFields.add("Time");
            oldValues.add(formatDateTime(oldDt));
            newValues.add(formatDateTime(newDateTime));
          }
        }

        // 2. Check Poll Options for changes
        final oldOptions =
            widget.eventData!['pollOptions'] as List<dynamic>? ?? [];
        bool optionsChanged = false;

        if (oldOptions.length != finalPollOptions.length) {
          optionsChanged = true;
        } else {
          for (int i = 0; i < oldOptions.length; i++) {
            final oldTitle = oldOptions[i]['title'] ?? '';
            final newTitle = finalPollOptions[i]['title'] ?? '';
            final oldLoc = oldOptions[i]['location'] ?? 'TBD';
            final newLoc = finalPollOptions[i]['location'] ?? 'TBD';

            if (oldTitle != newTitle || oldLoc != newLoc) {
              optionsChanged = true;
              break;
            }
          }
        }

        if (optionsChanged) {
          changedFields.add("Options");
          oldValues.add(formatOptions(oldOptions));
          newValues.add(formatOptions(finalPollOptions));
        }
        // -------------------------------------------------------------

        final Map<String, dynamic> updateData = {
          'title': _titleController.text.trim(),
          'details': _detailsController.text.trim(),
          'time': Timestamp.fromDate(newDateTime),
          'endTime': Timestamp.fromDate(newEndTime),
          'pollOptions': finalPollOptions,
          'rsvpDeadline': _rsvpDeadlineOffset,
          'inviteAll': _inviteAll,
          'invitedCircles': _selectedCircleIds,
          'coHostId': _selectedCoHostId,
          'coHostName': _selectedCoHostName,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };

        // 3. Attach compound banner payload if needed
        if (changedFields.isNotEmpty) {
          updateData['latestCriticalChange'] = {
            'field': changedFields.join(" & "),
            'original': oldValues.join(" | "),
            'new': newValues.join(" | "),
            'timestamp': FieldValue.serverTimestamp(),
          };
        }

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
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final eventRef = FirebaseFirestore.instance.collection('events').doc();
        batch.set(eventRef, {
          'type': 'vibe_check',
          'pollOptions': finalPollOptions,
          'lockedOptionId': null,
          'isTieBreakerNeeded': false,
          'hostId': user.uid,
          'coHostId': _selectedCoHostId,
          'coHostName': _selectedCoHostName,
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showConvertDialog() async {
    setState(() {
      _isLoading = true;
    });

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
      setState(() {
        _isLoading = false;
      });
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
    setState(() {
      _isLoading = true;
    });

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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              VitalsFormCard(
                                titleController: _titleController,
                                isPast: false,
                                selectedDate: _selectedDate,
                                selectedTime: _selectedTime,
                                onDateChanged: (d) {
                                  setState(() {
                                    _selectedDate = d;
                                  });
                                },
                                onTimeChanged: (t) {
                                  setState(() {
                                    _selectedTime = t;
                                  });
                                },
                                titleLabel: "What's the vibe?",
                                titleHint: "e.g. Sunday Funday, Happy Hour",
                              ),
                              ExtrasFormCard(
                                detailsController: _detailsController,
                                isPast: false,
                                rsvpDeadlineOffset: _rsvpDeadlineOffset,
                                onRsvpChanged: (val) {
                                  setState(() {
                                    _rsvpDeadlineOffset = val;
                                  });
                                },
                                detailsLabel: "Any other details? (Optional)",
                                detailsHint: "e.g. Dog friendly, BYOB...",
                                rsvpLabel: "Voting Deadline",
                                show48HourOption: true,
                              ),
                              CrewFormCard(
                                isPast: false,
                                inviteAll: _inviteAll,
                                selectedCircleIds: _selectedCircleIds,
                                coHostId: _selectedCoHostId,
                                coHostName: _selectedCoHostName,
                                coHostUsername: _selectedCoHostUsername,
                                coHostAvatarUrl: _selectedCoHostAvatarUrl,
                                coHostAvatarColor: _selectedCoHostAvatarColor,
                                onTeamChanged: (newAll, newIds) {
                                  setState(() {
                                    _inviteAll = newAll;
                                    _selectedCircleIds = newIds;

                                    if (!_inviteAll &&
                                        _selectedCircleIds.isEmpty) {
                                      _selectedCoHostId = null;
                                      _selectedCoHostName = null;
                                      _selectedCoHostUsername = null;
                                      _selectedCoHostAvatarUrl = null;
                                      _selectedCoHostAvatarColor = null;
                                    }
                                  });
                                },
                                onCoCaptainChanged:
                                    (
                                      id,
                                      name,
                                      username,
                                      avatarUrl,
                                      avatarColor,
                                    ) {
                                      setState(() {
                                        _selectedCoHostId = id;
                                        _selectedCoHostName = name;
                                        _selectedCoHostUsername = username;
                                        _selectedCoHostAvatarUrl = avatarUrl;
                                        _selectedCoHostAvatarColor =
                                            avatarColor;
                                      });
                                    },
                              ),
                              VibeHostActionsCard(
                                isEditing: isEditing,
                                onConvert: _showConvertDialog,
                                onDelete: () =>
                                    EventService.deleteEventWithConfirmation(
                                      context: context,
                                      eventId: widget.eventId!,
                                      isVibeCheck: true,
                                      onLoadingChanged: (val) {
                                        setState(() {
                                          _isLoading = val;
                                        });
                                      },
                                    ),
                              ),
                              const SizedBox(height: 12),
                              submitButton,
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
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
                        VitalsFormCard(
                          titleController: _titleController,
                          isPast: false,
                          selectedDate: _selectedDate,
                          selectedTime: _selectedTime,
                          onDateChanged: (d) {
                            setState(() {
                              _selectedDate = d;
                            });
                          },
                          onTimeChanged: (t) {
                            setState(() {
                              _selectedTime = t;
                            });
                          },
                          titleLabel: "What's the vibe?",
                          titleHint: "e.g. Sunday Funday, Happy Hour",
                        ),
                        VibeOptionsCard(
                          pollOptions: _pollOptions,
                          onAddOption: _addOption,
                          onRemoveOption: _removeOption,
                          onSelectLocation: _selectOptionLocation,
                          onClearLocation: _clearOptionLocation,
                        ),
                        ExtrasFormCard(
                          detailsController: _detailsController,
                          isPast: false,
                          rsvpDeadlineOffset: _rsvpDeadlineOffset,
                          onRsvpChanged: (val) {
                            setState(() {
                              _rsvpDeadlineOffset = val;
                            });
                          },
                          detailsLabel: "Any other details? (Optional)",
                          detailsHint: "e.g. Dog friendly, BYOB...",
                          rsvpLabel: "Voting Deadline",
                          show48HourOption: true,
                        ),
                        CrewFormCard(
                          isPast: false,
                          inviteAll: _inviteAll,
                          selectedCircleIds: _selectedCircleIds,
                          coHostId: _selectedCoHostId,
                          coHostName: _selectedCoHostName,
                          coHostUsername: _selectedCoHostUsername,
                          coHostAvatarUrl: _selectedCoHostAvatarUrl,
                          coHostAvatarColor: _selectedCoHostAvatarColor,
                          onTeamChanged: (newAll, newIds) {
                            setState(() {
                              _inviteAll = newAll;
                              _selectedCircleIds = newIds;

                              if (!_inviteAll && _selectedCircleIds.isEmpty) {
                                _selectedCoHostId = null;
                                _selectedCoHostName = null;
                                _selectedCoHostUsername = null;
                                _selectedCoHostAvatarUrl = null;
                                _selectedCoHostAvatarColor = null;
                              }
                            });
                          },
                          onCoCaptainChanged:
                              (id, name, username, avatarUrl, avatarColor) {
                                setState(() {
                                  _selectedCoHostId = id;
                                  _selectedCoHostName = name;
                                  _selectedCoHostUsername = username;
                                  _selectedCoHostAvatarUrl = avatarUrl;
                                  _selectedCoHostAvatarColor = avatarColor;
                                });
                              },
                        ),
                        VibeHostActionsCard(
                          isEditing: isEditing,
                          onConvert: _showConvertDialog,
                          onDelete: () =>
                              EventService.deleteEventWithConfirmation(
                                context: context,
                                eventId: widget.eventId!,
                                isVibeCheck: true,
                                onLoadingChanged: (val) {
                                  setState(() {
                                    _isLoading = val;
                                  });
                                },
                              ),
                        ),
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
