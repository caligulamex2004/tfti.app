import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../components/shared/banner_picker.dart';
import '../components/shared/rpg_glass_card.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import '../components/forms/extras_form_card.dart';
import '../components/forms/important_details_toggle.dart';
import '../components/forms/vitals_form_card.dart';
import '../components/forms/crew_form_card.dart';
import '../components/forms/lockdown_banner.dart';
import '../components/forms/local_squad_needs_sheet.dart';
import '../components/forms/squad_needs_form_card.dart';
import '../components/forms/squad_needs_sheet.dart';
import '../components/forms/team_selection_field.dart';
import '../components/forms/editor_action_buttons.dart';
import '../components/dialogs/season_dialogs.dart';
import '../components/forms/recurring_season_toggle.dart';
import '../models/hangout_submission_request.dart';
import '../utils/event_service.dart';
import '../utils/theme_provider.dart';
import '../utils/responsive_layout.dart';
import '../services/notification_service.dart';

class HangoutEditorPage extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? eventData; // If null, it's a new event

  const HangoutEditorPage({super.key, this.eventId, this.eventData});

  @override
  State<HangoutEditorPage> createState() => _HangoutEditorPageState();
}

class _HangoutEditorPageState extends State<HangoutEditorPage> {
  final _formKey = GlobalKey<FormState>();

  // Page State
  bool get isEditing => widget.eventData != null;
  bool _isLoading = false;
  late bool _isPast;
  late bool _isMainHost;
  late bool _isCoHost;

  // Form Controllers
  final _titleController = TextEditingController();
  final _locController = TextEditingController();
  final _detailsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _inviteAll = false;
  List<String> _selectedCircleIds = [];

  int _rsvpDeadlineOffset = 0;
  int _keepAliveDays = 0;
  bool _isImportantDetails = false;

  // Recurring Season State
  bool _isRecurring = false;
  String _recurringFrequency = 'weekly';
  int _recurringInstances = 16;
  int get _maxRecurringInstances {
    if (_recurringFrequency == 'weekly') return 16;
    if (_recurringFrequency == 'biweekly') return 8;
    if (_recurringFrequency == 'monthly') return 4;
    return 16;
  }

  String? _bannerImagePath;
  Uint8List? _bannerImageBytes;
  bool _removeBanner = false;

  // Squad Needs (Create Mode — local list)
  final List<String> _roles = [];
  final _roleInputController = TextEditingController();

  // Co-Captain State
  String? _selectedCoHostId;
  String? _selectedCoHostName;
  String? _selectedCoHostUsername;
  String? _selectedCoHostAvatarUrl;
  int? _selectedCoHostAvatarColor;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (isEditing) {
      // --- EDIT MODE INITIALIZATION ---
      final data = widget.eventData!;
      _isMainHost = data['hostId'] == user?.uid;
      _isCoHost = data['coHostId'] == user?.uid;

      _titleController.text = data['title'] ?? '';
      _locController.text = data['location'] ?? '';
      _detailsController.text = data['details'] ?? data['description'] ?? '';

      if (data['time'] != null) {
        final dt = (data['time'] as Timestamp).toDate();
        _selectedDate = dt;
        _selectedTime = TimeOfDay.fromDateTime(dt);
      }

      // Co-host loads their own additive scope; main host loads the event scope
      if (_isCoHost && !_isMainHost) {
        _inviteAll = data['coHostInviteAll'] ?? false;
        _selectedCircleIds = List<String>.from(
          data['coHostInvitedCircles'] ?? [],
        );
      } else {
        _inviteAll = data['inviteAll'] ?? true;
        _selectedCircleIds = List<String>.from(data['invitedCircles'] ?? []);
      }
      _rsvpDeadlineOffset = data['rsvpDeadline'] ?? 0;
      _keepAliveDays = data['keepAliveDays'] ?? 0;
      _isImportantDetails = data['isImportantDetails'] ?? false;

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

      _isRecurring = data['seasonId'] != null;

      // Lockdown Check
      final Timestamp? endTs = data['endTime'];
      final DateTime endTime =
          endTs?.toDate() ??
          _selectedDate.add(
            Duration(
              minutes: _keepAliveDays > 0 ? (_keepAliveDays * 24 * 60) : 240,
            ),
          );
      _isPast = (data['isPast'] == true) || DateTime.now().isAfter(endTime);
    } else {
      // --- CREATE MODE INITIALIZATION ---
      _isMainHost = true;
      _isCoHost = false;
      _isPast = false;

      // Smart Default: Round up to the next 15 minute mark
      final now = DateTime.now();
      int remainder = now.minute % 15;
      int addMinutes = remainder == 0 ? 0 : 15 - remainder;
      DateTime rounded = now.add(Duration(minutes: addMinutes));

      _selectedDate = rounded;
      _selectedTime = TimeOfDay.fromDateTime(rounded);
    }
  }

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

    for (int i = 1; i < _recurringInstances; i++) {
      if (_recurringFrequency == 'monthly') {
        int newYear = current.year;
        int newMonth = current.month + 1;
        if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
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

  Widget _buildRecurringToggle() {
    return RecurringSeasonToggle(
      isRecurring: _isRecurring,
      recurringFrequency: _recurringFrequency,
      recurringInstances: _recurringInstances,
      maxRecurringInstances: _maxRecurringInstances,
      onToggle: (val) => setState(() => _isRecurring = val),
      onFrequencyChanged: (val) {
        setState(() {
          _recurringFrequency = val;
          _recurringInstances = _maxRecurringInstances;
        });
      },
      onInstancesChanged: (val) => setState(() => _recurringInstances = val),
    );
  }

  bool _hasUnsavedChanges() {
    if (!isEditing) {
      if (_titleController.text.trim().isNotEmpty) return true;
      if (_locController.text.trim().isNotEmpty) return true;
      if (_detailsController.text.trim().isNotEmpty) return true;
      if (_bannerImagePath != null || _bannerImageBytes != null) return true;
      if (_roles.isNotEmpty) return true;
    }
    return false;
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Discard Changes?"),
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
  void dispose() {
    _titleController.dispose();
    _locController.dispose();
    _detailsController.dispose();
    _roleInputController.dispose();
    super.dispose();
  }

  Future<void> _submitEvent() async {
    // Co-host view has no Form wrapper, so currentState may be null
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    SeasonUpdateScope updateScope = SeasonUpdateScope.single;
    final String? seasonId = widget.eventData?['seasonId'];

    if (isEditing && _isMainHost && seasonId != null && _isRecurring) {
      final scope = await SeasonDialogs.showUpdateSeasonScope(context);
      if (!mounted) return;
      if (scope == null) return;
      updateScope = scope;
    } else if (isEditing && _isMainHost && seasonId != null && !_isRecurring) {
      final confirm =
          await SeasonDialogs.showTurnOffRecurringConfirmation(context);
      if (!mounted) return;
      if (confirm != true) return;
      updateScope = SeasonUpdateScope.toggleOff;
    }

    final request = HangoutSubmissionRequest(
      isEditing: isEditing,
      isMainHost: _isMainHost,
      isCoHost: _isCoHost,
      eventId: widget.eventId,
      eventData: widget.eventData,
      title: _titleController.text.trim(),
      location: _locController.text.trim(),
      details: _detailsController.text.trim(),
      selectedDate: _selectedDate,
      selectedTime: _selectedTime,
      inviteAll: _inviteAll,
      selectedCircleIds: _selectedCircleIds,
      rsvpDeadlineOffset: _rsvpDeadlineOffset,
      keepAliveDays: _keepAliveDays,
      isImportantDetails: _isImportantDetails,
      isRecurring: _isRecurring,
      recurringFrequency: _recurringFrequency,
      recurringInstances: _recurringInstances,
      generateSeasonDates: _generateSeasonDates,
      updateScope: updateScope,
      bannerImagePath: _bannerImagePath,
      bannerImageBytes: _bannerImageBytes,
      removeBanner: _removeBanner,
      coHostId: _selectedCoHostId,
      coHostName: _selectedCoHostName,
      roles: _roles,
    );

    await EventService.submitHangout(
      request: request,
      onLoadingChanged: (val) {
        if (mounted) setState(() => _isLoading = val);
      },
      onSuccess: () {
        if (mounted) {
          Navigator.pop(context);
          NotificationService.instance.showLocalNotification(
            title: isEditing ? "Changes saved! 💾" : "It's official! 🚀",
            body: isEditing
                ? "Your event details have been updated."
                : "Your crew has been notified! 📨",
            type: 'success',
          );
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

  // ---------------------------------------------------------------------------
  // Squad Needs — Create Mode UI
  // ---------------------------------------------------------------------------

  void _showLocalSquadNeedsSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => LocalSquadNeedsSheet(
        roles: _roles,
        onChanged: (updated) => setState(() {
          _roles
            ..clear()
            ..addAll(updated);
        }),
      ),
    );
  }

  /// The tappable chip that opens the local Squad Needs sheet (create mode).
  /// Matches main branch create_event_page.dart styling.
  Widget _buildTogglesRow() {
    return Row(
      children: [
        Expanded(
          child: isEditing
              ? SquadNeedsFormCard(
                  eventId: widget.eventId!,
                  hostId: widget.eventData!['hostId'],
                  isPast: _isPast,
                )
              : _buildSquadNeedsToggleCreateMode(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ImportantDetailsToggle(
            isImportant: _isImportantDetails,
            isPast: _isPast,
            onChanged: (val) {
              setState(() {
                _isImportantDetails = val;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSquadNeedsToggleCreateMode() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: _showLocalSquadNeedsSheet,
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
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _roles.isEmpty ? "Squad Needs" : "${_roles.length} Needs",
                style: TextStyle(
                  fontWeight:
                      _roles.isNotEmpty ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  // ---------------------------------------------------------------------------
  // Co-Host — Restricted Dashboard View
  // ---------------------------------------------------------------------------

  Widget _buildCoHostView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              LockdownBanner(isPast: _isPast),
              RpgGlassCard(
                title: "Co-Captain Dashboard",
                icon: Symbols.military_tech,
                iconColor: Colors.teal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.teal.withValues(alpha: 0.1)
                            : Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Symbols.military_tech,
                            color: Colors.teal,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "You are the Co-Captain! You can manage your own crew and add Squad Needs.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.tealAccent
                                    : Colors.teal.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Team Selector (co-host's own scope)
                    TeamSelectionField(
                      inviteAll: _inviteAll,
                      selectedCircleIds: _selectedCircleIds,
                      enabled: !_isPast,
                      onChanged: (newAll, newIds) {
                        setState(() {
                          _inviteAll = newAll;
                          _selectedCircleIds = newIds;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Squad Needs entry
                    InkWell(
                      onTap: _isPast
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (ctx) => SquadNeedsSheet(
                                  eventId: widget.eventId!,
                                  hostId: widget.eventData!['hostId'],
                                  isPast: _isPast,
                                ),
                              );
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_box_outlined, color: primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Manage Squad Needs",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Text(
                                    "View, add, or delete your roles",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Save Button (no delete for co-host)
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (_isPast || _isLoading) ? null : _submitEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: themeProvider.onPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = context.isWideScreen;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final String appBarTitle = isEditing ? "Manage Hangout" : "Create Hangout";
    final String submitText =
        isEditing ? "Save Changes" : "Throw it out there";

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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SharedSliverAppBar(
                      title: appBarTitle,
                      collapsedTitle: appBarTitle,
                      subtitle: isEditing
                          ? "Update event vitals & crew"
                          : "Assemble the squad and set the vibe",
                      expandedHeight: isLandscape ? 120.0 : 160.0,
                      hasBackButton: true,
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Center(
                            child: InkWell(
                              onTap: (_isPast || _isLoading)
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _submitEvent();
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
                                      color:
                                          primaryColor.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isEditing
                                          ? Icons.check
                                          : Icons.rocket_launch,
                                      size: 15,
                                      color: themeProvider.onPrimaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isEditing ? "Save" : "Go!",
                                      style: TextStyle(
                                        color: themeProvider.onPrimaryColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: (isEditing && _isCoHost && !_isMainHost)
                          ? _buildCoHostView()
                          : Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Form(
                                key: _formKey,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 1000),
                                    child: isLandscape
                                        ? Column(
                                            children: [
                                              LockdownBanner(isPast: _isPast),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Left Column: Banner + Vitals
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        BannerPicker(
                                                          existingImageUrl:
                                                              isEditing
                                                                  ? widget
                                                                      .eventData![
                                                                    'bannerUrl']
                                                                  : null,
                                                          isPast: _isPast,
                                                          onImageChanged: (
                                                            path,
                                                            removed,
                                                          ) {
                                                            setState(() {
                                                              _bannerImagePath =
                                                                  path;
                                                              _removeBanner =
                                                                  removed;
                                                              if (removed) {
                                                                _bannerImageBytes =
                                                                    null;
                                                              }
                                                            });
                                                          },
                                                          onBytesChanged: (
                                                            bytes,
                                                          ) {
                                                            setState(() {
                                                              _bannerImageBytes =
                                                                  bytes;
                                                            });
                                                          },
                                                        ),
                                                        VitalsFormCard(
                                                          titleController:
                                                              _titleController,
                                                          locController:
                                                              _locController,
                                                          isPast: _isPast,
                                                          selectedDate:
                                                              _selectedDate,
                                                          selectedTime:
                                                              _selectedTime,
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
                                                          recurringToggle:
                                                              _buildRecurringToggle(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 24),
                                                  // Right Column: Extras + Crew + Action Buttons
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        ExtrasFormCard(
                                                          detailsController:
                                                              _detailsController,
                                                          isPast: _isPast,
                                                          rsvpDeadlineOffset:
                                                              _rsvpDeadlineOffset,
                                                          keepAliveDays:
                                                              _keepAliveDays,
                                                          onRsvpChanged: (val) {
                                                            setState(() {
                                                              _rsvpDeadlineOffset =
                                                                  val;
                                                            });
                                                          },
                                                          onKeepAliveChanged: (
                                                            val,
                                                          ) {
                                                            setState(() {
                                                              _keepAliveDays =
                                                                  val;
                                                            });
                                                          },
                                                          togglesRow:
                                                              _buildTogglesRow(),
                                                        ),
                                                        CrewFormCard(
                                                          isPast: _isPast,
                                                          inviteAll: _inviteAll,
                                                          selectedCircleIds:
                                                              _selectedCircleIds,
                                                          coHostId:
                                                              _selectedCoHostId,
                                                          coHostName:
                                                              _selectedCoHostName,
                                                          coHostUsername:
                                                              _selectedCoHostUsername,
                                                          coHostAvatarUrl:
                                                              _selectedCoHostAvatarUrl,
                                                          coHostAvatarColor:
                                                              _selectedCoHostAvatarColor,
                                                          onTeamChanged: (
                                                            newAll,
                                                            newIds,
                                                          ) {
                                                            setState(() {
                                                              _inviteAll =
                                                                  newAll;
                                                              _selectedCircleIds =
                                                                  newIds;

                                                              if (!_inviteAll &&
                                                                  _selectedCircleIds
                                                                      .isEmpty) {
                                                                _selectedCoHostId =
                                                                    null;
                                                                _selectedCoHostName =
                                                                    null;
                                                                _selectedCoHostUsername =
                                                                    null;
                                                                _selectedCoHostAvatarUrl =
                                                                    null;
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
                                                                  _selectedCoHostId =
                                                                      id;
                                                                  _selectedCoHostName =
                                                                      name;
                                                                  _selectedCoHostUsername =
                                                                      username;
                                                                  _selectedCoHostAvatarUrl =
                                                                      avatarUrl;
                                                                  _selectedCoHostAvatarColor =
                                                                      avatarColor;
                                                                });
                                                              },
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        EditorActionButtons(
                                                          isEditing: isEditing,
                                                          isMainHost:
                                                              _isMainHost,
                                                          isPast: _isPast,
                                                          isLoading: _isLoading,
                                                          submitText:
                                                              submitText,
                                                          onSubmit:
                                                              _submitEvent,
                                                          onDelete: () =>
                                                              EventService
                                                                  .deleteEventWithConfirmation(
                                                            context: context,
                                                            eventId:
                                                                widget.eventId!,
                                                            isVibeCheck: false,
                                                            seasonId: isEditing
                                                                ? widget
                                                                        .eventData![
                                                                    'seasonId']
                                                                : null,
                                                            eventTime: isEditing
                                                                ? widget
                                                                        .eventData![
                                                                    'time']
                                                                : null,
                                                            onLoadingChanged: (
                                                              val,
                                                            ) {
                                                              if (mounted) {
                                                                setState(() {
                                                                  _isLoading =
                                                                      val;
                                                                });
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 60),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              LockdownBanner(isPast: _isPast),
                                              BannerPicker(
                                                existingImageUrl: isEditing
                                                    ? widget
                                                        .eventData!['bannerUrl']
                                                    : null,
                                                isPast: _isPast,
                                                onImageChanged: (
                                                  path,
                                                  removed,
                                                ) {
                                                  setState(() {
                                                    _bannerImagePath = path;
                                                    _removeBanner = removed;
                                                    if (removed) {
                                                      _bannerImageBytes = null;
                                                    }
                                                  });
                                                },
                                                onBytesChanged: (bytes) {
                                                  setState(() {
                                                    _bannerImageBytes = bytes;
                                                  });
                                                },
                                              ),
                                              VitalsFormCard(
                                                titleController:
                                                    _titleController,
                                                locController: _locController,
                                                isPast: _isPast,
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
                                                recurringToggle:
                                                    _buildRecurringToggle(),
                                              ),
                                              ExtrasFormCard(
                                                detailsController:
                                                    _detailsController,
                                                isPast: _isPast,
                                                rsvpDeadlineOffset:
                                                    _rsvpDeadlineOffset,
                                                keepAliveDays: _keepAliveDays,
                                                onRsvpChanged: (val) {
                                                  setState(() {
                                                    _rsvpDeadlineOffset = val;
                                                  });
                                                },
                                                onKeepAliveChanged: (val) {
                                                  setState(() {
                                                    _keepAliveDays = val;
                                                  });
                                                },
                                                togglesRow: _buildTogglesRow(),
                                              ),
                                              CrewFormCard(
                                                isPast: _isPast,
                                                inviteAll: _inviteAll,
                                                selectedCircleIds:
                                                    _selectedCircleIds,
                                                coHostId: _selectedCoHostId,
                                                coHostName: _selectedCoHostName,
                                                coHostUsername:
                                                    _selectedCoHostUsername,
                                                coHostAvatarUrl:
                                                    _selectedCoHostAvatarUrl,
                                                coHostAvatarColor:
                                                    _selectedCoHostAvatarColor,
                                                onTeamChanged: (
                                                  newAll,
                                                  newIds,
                                                ) {
                                                  setState(() {
                                                    _inviteAll = newAll;
                                                    _selectedCircleIds = newIds;

                                                    if (!_inviteAll &&
                                                        _selectedCircleIds
                                                            .isEmpty) {
                                                      _selectedCoHostId = null;
                                                      _selectedCoHostName =
                                                          null;
                                                      _selectedCoHostUsername =
                                                          null;
                                                      _selectedCoHostAvatarUrl =
                                                          null;
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
                                                        _selectedCoHostName =
                                                            name;
                                                        _selectedCoHostUsername =
                                                            username;
                                                        _selectedCoHostAvatarUrl =
                                                            avatarUrl;
                                                        _selectedCoHostAvatarColor =
                                                            avatarColor;
                                                      });
                                                    },
                                              ),
                                              const SizedBox(height: 12),
                                              EditorActionButtons(
                                                isEditing: isEditing,
                                                isMainHost: _isMainHost,
                                                isPast: _isPast,
                                                isLoading: _isLoading,
                                                submitText: submitText,
                                                onSubmit: _submitEvent,
                                                onDelete: () =>
                                                    EventService
                                                        .deleteEventWithConfirmation(
                                                  context: context,
                                                  eventId: widget.eventId!,
                                                  isVibeCheck: false,
                                                  seasonId: isEditing
                                                      ? widget.eventData![
                                                          'seasonId']
                                                      : null,
                                                  eventTime: isEditing
                                                      ? widget
                                                          .eventData!['time']
                                                      : null,
                                                  onLoadingChanged: (val) {
                                                    if (mounted) {
                                                      setState(() {
                                                        _isLoading = val;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
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
