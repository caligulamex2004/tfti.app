import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../components/shared/shared_sliver_app_bar.dart';
import '../components/forms/vibe_options_card.dart';
import '../components/forms/crew_form_card.dart';
import '../components/forms/vibe_host_actions_card.dart';
import '../components/forms/vitals_form_card.dart';
import '../components/forms/extras_form_card.dart';
import '../models/vibe_check_submission_request.dart';
import '../utils/event_service.dart';
import '../utils/theme_provider.dart';
import '../utils/responsive_layout.dart';
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

    final request = VibeCheckSubmissionRequest(
      isEditing: isEditing,
      eventId: widget.eventId,
      eventData: widget.eventData,
      title: _titleController.text.trim(),
      details: _detailsController.text.trim(),
      selectedDate: _selectedDate,
      selectedTime: _selectedTime,
      pollOptions: finalPollOptions,
      inviteAll: _inviteAll,
      selectedCircleIds: _selectedCircleIds,
      rsvpDeadlineOffset: _rsvpDeadlineOffset,
      coHostId: _selectedCoHostId,
      coHostName: _selectedCoHostName,
    );

    await EventService.submitVibeCheck(
      request: request,
      onLoadingChanged: (val) {
        if (mounted) setState(() => _isLoading = val);
      },
      onSuccess: () {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? "Changes saved!" : "Feeler sent out! 🎣",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $msg")),
          );
        }
      },
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select the Winner"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: validOptions.map((opt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                  title: Text(
                    opt['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    opt['location'] == 'TBD' ? 'No location' : opt['location'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${opt['votes']} Votes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    _confirmConvert(opt);
                  },
                ),
              );
            }).toList(),
          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
    await EventService.convertVibeCheck(
      eventId: widget.eventId!,
      option: option,
      onLoadingChanged: (val) {
        if (mounted) setState(() => _isLoading = val);
      },
      onSuccess: () {
        if (mounted) {
          Navigator.pop(context);
        }
      },
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg')),
          );
        }
      },
    );
  }

  bool _hasUnsavedChanges() {
    if (!isEditing) {
      if (_titleController.text.trim().isNotEmpty) return true;
      if (_detailsController.text.trim().isNotEmpty) return true;
      for (var opt in _pollOptions) {
        final title = (opt['title'] as TextEditingController).text.trim();
        final loc = (opt['location'] as TextEditingController).text.trim();
        if (title.isNotEmpty || loc.isNotEmpty) return true;
      }
    }
    return false;
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Discard Changes?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: const Text(
          "You have unsaved changes. Are you sure you want to discard them?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep Editing"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Discard", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = context.isWideScreen;

    final String appBarTitle = isEditing ? "Edit Vibe Check" : "Vibe Check";
    final String submitText = isEditing ? "Save Changes" : "Throw it out there";

    final submitButton = SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                HapticFeedback.lightImpact();
                _submitVibeCheck();
              },
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

    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showDiscardDialog();
        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: CustomScrollView(
            slivers: [
              SharedSliverAppBar(
                title: appBarTitle,
                collapsedTitle: appBarTitle,
                subtitle: isEditing
                    ? "Adjust options & voting deadline"
                    : "Give options and let the squad decide",
                expandedHeight: isLandscape ? 120.0 : 160.0,
                hasBackButton: true,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Center(
                      child: InkWell(
                        onTap: _isLoading
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _submitVibeCheck();
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLoading)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else ...[
                                Icon(
                                  isEditing ? Icons.check : Icons.send_rounded,
                                  size: 15,
                                  color: themeProvider.onPrimaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isEditing ? "Save" : "Send",
                                  style: TextStyle(
                                    color: themeProvider.onPrimaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: isLandscape
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Vitals + Vibe Options
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
                                          titleHint:
                                              "e.g. Sunday Funday, Happy Hour",
                                        ),
                                        VibeOptionsCard(
                                          pollOptions: _pollOptions,
                                          onAddOption: _addOption,
                                          onRemoveOption: _removeOption,
                                          onSelectLocation:
                                              _selectOptionLocation,
                                          onClearLocation:
                                              _clearOptionLocation,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right Column: Extras + Crew + Host Actions + Submit
                                  Expanded(
                                    child: Column(
                                      children: [
                                        ExtrasFormCard(
                                          detailsController: _detailsController,
                                          isPast: false,
                                          rsvpDeadlineOffset:
                                              _rsvpDeadlineOffset,
                                          onRsvpChanged: (val) {
                                            setState(() {
                                              _rsvpDeadlineOffset = val;
                                            });
                                          },
                                          detailsLabel:
                                              "Any other details? (Optional)",
                                          detailsHint:
                                              "e.g. Dog friendly, BYOB...",
                                          rsvpLabel: "Voting Deadline",
                                          show48HourOption: true,
                                        ),
                                        CrewFormCard(
                                          isPast: false,
                                          inviteAll: _inviteAll,
                                          selectedCircleIds: _selectedCircleIds,
                                          coHostId: _selectedCoHostId,
                                          coHostName: _selectedCoHostName,
                                          coHostUsername:
                                              _selectedCoHostUsername,
                                          coHostAvatarUrl:
                                              _selectedCoHostAvatarUrl,
                                          coHostAvatarColor:
                                              _selectedCoHostAvatarColor,
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
                                                _selectedCoHostAvatarColor =
                                                    null;
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
                                                  _selectedCoHostUsername =
                                                      username;
                                                  _selectedCoHostAvatarUrl =
                                                      avatarUrl;
                                                  _selectedCoHostAvatarColor =
                                                      avatarColor;
                                                });
                                              },
                                        ),
                                        VibeHostActionsCard(
                                          isEditing: isEditing,
                                          onConvert: _showConvertDialog,
                                          onDelete: () =>
                                              EventService
                                                  .deleteEventWithConfirmation(
                                            context: context,
                                            eventId: widget.eventId!,
                                            isVibeCheck: true,
                                            onLoadingChanged: (val) {
                                              if (mounted) {
                                                setState(() {
                                                  _isLoading = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        submitButton,
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
                                    detailsLabel:
                                        "Any other details? (Optional)",
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
                                    coHostAvatarColor:
                                        _selectedCoHostAvatarColor,
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
                                            _selectedCoHostAvatarUrl =
                                                avatarUrl;
                                            _selectedCoHostAvatarColor =
                                                avatarColor;
                                          });
                                        },
                                  ),
                                  VibeHostActionsCard(
                                    isEditing: isEditing,
                                    onConvert: _showConvertDialog,
                                    onDelete: () =>
                                        EventService
                                            .deleteEventWithConfirmation(
                                      context: context,
                                      eventId: widget.eventId!,
                                      isVibeCheck: true,
                                      onLoadingChanged: (val) {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  submitButton,
                                  const SizedBox(height: 60),
                                ],
                              ),
                      ),
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
