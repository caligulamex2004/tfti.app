import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../components/shared/banner_picker.dart';
import '../components/shared/rpg_glass_card.dart';
import '../components/forms/extras_form_card.dart';
import '../components/forms/vitals_form_card.dart';
import '../components/forms/crew_form_card.dart';
import '../components/forms/lockdown_banner.dart';
import '../components/forms/local_squad_needs_sheet.dart';
import '../components/forms/squad_needs_form_card.dart';
import '../components/forms/squad_needs_sheet.dart';
import '../components/forms/team_selection_field.dart';
import '../components/forms/editor_action_buttons.dart';
import '../utils/event_service.dart';
import '../utils/theme_provider.dart';

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

  String? _bannerImagePath;
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
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
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
      final int durationMinutes = _keepAliveDays > 0
          ? (_keepAliveDays * 24 * 60)
          : 240;
      final newEndTime = newDateTime.add(Duration(minutes: durationMinutes));

      if (isEditing) {
        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId);
        final batch = FirebaseFirestore.instance.batch();

        final Map<String, dynamic> updateData = {
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };

        // --- CRITICAL CHANGE DETECTOR (host & co-host) ---
        List<String> changedFields = [];
        List<String> oldValues = [];
        List<String> newValues = [];

        String formatDateTime(DateTime dt) {
          final months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          final hour = dt.hour > 12
              ? dt.hour - 12
              : (dt.hour == 0 ? 12 : dt.hour);
          final min = dt.minute.toString().padLeft(2, '0');
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          return '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
        }

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

        final oldLoc = (widget.eventData!['location'] ?? '')
            .toString()
            .trim();
        final newLoc = _locController.text.trim();
        if (oldLoc != newLoc) {
          changedFields.add("Location");
          oldValues.add(oldLoc.isEmpty ? "TBD" : oldLoc);
          newValues.add(newLoc.isEmpty ? "TBD" : newLoc);
        }

        if (changedFields.isNotEmpty) {
          updateData['latestCriticalChange'] = {
            'field': changedFields.join(" & "),
            'original': oldValues.join(" | "),
            'new': newValues.join(" | "),
            'timestamp': FieldValue.serverTimestamp(),
          };
        }

        // --- Standard updates (host & co-host) ---
        updateData['title'] = _titleController.text.trim();
        updateData['location'] = _locController.text.trim();
        updateData['details'] = _detailsController.text.trim();
        updateData['time'] = Timestamp.fromDate(newDateTime);
        updateData['endTime'] = Timestamp.fromDate(newEndTime);
        updateData['isImportantDetails'] = _isImportantDetails;
        updateData['rsvpDeadline'] = _rsvpDeadlineOffset;
        updateData['keepAliveDays'] = _keepAliveDays;

        if (_removeBanner) {
          updateData['bannerUrl'] = FieldValue.delete();
          try {
            await FirebaseStorage.instance
                .ref()
                .child('event_banners/${widget.eventId}/banner.jpg')
                .delete();
          } catch (_) {}
        } else if (_bannerImagePath != null) {
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
            final ref = FirebaseStorage.instance.ref().child(
              'event_banners/${widget.eventId}/banner.jpg',
            );
            await ref.putData(
              compressedBytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            updateData['bannerUrl'] = await ref.getDownloadURL();
          } catch (e) {
            debugPrint("Failed to upload new banner: $e");
          }
        }

        // --- INVITATION ROSTER MANAGEMENT ---
        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();

        final currentInvitesSnap = await eventRef
            .collection('invitations')
            .get();
        final Set<String> currentlyInvitedIds = currentInvitesSnap.docs
            .map((d) => d.id)
            .toSet();

        if (_isMainHost) {
          // Host: full roster control (add + remove) & co-captain assignment
          updateData['inviteAll'] = _inviteAll;
          updateData['invitedCircles'] = _selectedCircleIds;
          updateData['coHostId'] = _selectedCoHostId;
          updateData['coHostName'] = _selectedCoHostName;

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

          Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
          Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);
          toRemove.remove(widget.eventData!['hostId']);

          if (toAdd.isNotEmpty) {
            updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
            for (String uid in toAdd) {
              if (!currentlyInvitedIds.contains(uid)) {
                batch.set(eventRef.collection('invitations').doc(uid), {
                  'uid': uid,
                  'role': 'guest',
                  'status': 'pending',
                  'sentAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
          if (toRemove.isNotEmpty) {
            updateData['visibleTo'] =
                FieldValue.arrayRemove(toRemove.toList());
            for (String uid in toRemove) {
              batch.delete(eventRef.collection('invitations').doc(uid));
            }
          }
        } else {
          // Co-host: additive-only invitations from their own squad
          // Cannot remove existing guests or reassign co-captain
          updateData['coHostInviteAll'] = _inviteAll;
          updateData['coHostInvitedCircles'] = _selectedCircleIds;

          Set<String> coHostIntendedIds = {};

          for (var friendDoc in friendsSnapshot.docs) {
            final friendCircles = List<String>.from(
              friendDoc.data()['circles'] ?? [],
            );
            if (_inviteAll ||
                _selectedCircleIds.any((id) => friendCircles.contains(id))) {
              coHostIntendedIds.add(friendDoc.id);
            }
          }

          Set<String> toAdd =
              coHostIntendedIds.difference(currentlyInvitedIds);

          if (toAdd.isNotEmpty) {
            updateData['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
            for (String uid in toAdd) {
              batch.set(eventRef.collection('invitations').doc(uid), {
                'uid': uid,
                'role': 'guest',
                'status': 'pending',
                'sentAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        batch.update(eventRef, updateData);
        await batch.commit();
      } else {
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

        final batch = FirebaseFirestore.instance.batch();
        final eventRef = FirebaseFirestore.instance.collection('events').doc();

        batch.set(eventRef, {
          'title': _titleController.text.trim(),
          'location': _locController.text.trim(),
          'details': _detailsController.text.trim(),
          'time': Timestamp.fromDate(newDateTime),
          'endTime': Timestamp.fromDate(newEndTime),
          'hostId': user.uid,
          'coHostId': _selectedCoHostId,
          'coHostName': _selectedCoHostName,
          'isPast': false,
          'created_at': FieldValue.serverTimestamp(),
          'visibleTo': visibleToIds.toList(),
          'inviteAll': _inviteAll,
          'invitedCircles': _selectedCircleIds,
          'isImportantDetails': _isImportantDetails,
          'rsvpDeadline': _rsvpDeadlineOffset,
          'keepAliveDays': _keepAliveDays,
          'pointsAwarded': false,
        });

        // Add Guests
        for (var friendDoc in friendsToInvite) {
          batch.set(eventRef.collection('invitations').doc(friendDoc.id), {
            'uid': friendDoc.id,
            'role': 'guest',
            'status': 'pending',
            'sentAt': FieldValue.serverTimestamp(),
          });
        }

        // Add Host
        batch.set(eventRef.collection('invitations').doc(user.uid), {
          'uid': user.uid,
          'role': 'host',
          'status': 'going',
          'sentAt': FieldValue.serverTimestamp(),
        });

        // Squad Needs (Roles) — write local list to Firestore
        for (String roleTitle in _roles) {
          batch.set(eventRef.collection('roles').doc(), {
            'title': roleTitle,
            'addedBy': user.uid,
            'claimedByUid': null,
            'claimedByName': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();

        if (_bannerImagePath != null) {
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
            final ref = FirebaseStorage.instance.ref().child(
              'event_banners/${eventRef.id}/banner.jpg',
            );
            await ref.putData(
              compressedBytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final downloadUrl = await ref.getDownloadURL();
            await eventRef.update({'bannerUrl': downloadUrl});
          } catch (e) {
            debugPrint("Failed to upload banner: $e");
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? "Changes saved!" : "Hangout deployed!"),
            backgroundColor: Colors.green,
          ),
        );
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
  Widget _buildSquadNeedsButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return RpgGlassCard(
      title: "Squad Needs",
      icon: Icons.check_box_outlined,
      child: InkWell(
        onTap: _showLocalSquadNeedsSheet,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.pan_tool, color: primaryColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _roles.isEmpty
                      ? "Add items you need help with"
                      : "${_roles.length} item${_roles.length == 1 ? '' : 's'} added",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
            ],
          ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
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
                  onTap: _isPast ? null : () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final String appBarTitle = isEditing ? "Manage Hangout" : "Create Hangout";
    final String submitText = isEditing ? "Save Changes" : "Deploy Hangout";

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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (isEditing && _isCoHost && !_isMainHost)
                ? _buildCoHostView()
                : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: isLandscape
                        ? Column(
                            children: [
                              LockdownBanner(isPast: _isPast),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        BannerPicker(
                                          existingImageUrl: isEditing
                                              ? widget.eventData!['bannerUrl']
                                              : null,
                                          isPast: _isPast,
                                          onImageChanged: (path, removed) {
                                            setState(() {
                                              _bannerImagePath = path;
                                              _removeBanner = removed;
                                            });
                                          },
                                        ),
                                        VitalsFormCard(
                                          titleController: _titleController,
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
                                        ),
                                        CrewFormCard(
                                          isPast: _isPast,
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
                                        EditorActionButtons(
                                          isEditing: isEditing,
                                          isMainHost: _isMainHost,
                                          isPast: _isPast,
                                          isLoading: _isLoading,
                                          submitText: submitText,
                                          onSubmit: _submitEvent,
                                          onDelete: () =>
                                              EventService.deleteEventWithConfirmation(
                                                context: context,
                                                eventId: widget.eventId!,
                                                isVibeCheck: false,
                                                onLoadingChanged: (val) {
                                                  setState(() {
                                                    _isLoading = val;
                                                  });
                                                },
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        ExtrasFormCard(
                                          detailsController: _detailsController,
                                          isPast: _isPast,
                                          isImportantDetails:
                                              _isImportantDetails,
                                          rsvpDeadlineOffset:
                                              _rsvpDeadlineOffset,
                                          keepAliveDays: _keepAliveDays,
                                          onImportantChanged: (val) {
                                            setState(() {
                                              _isImportantDetails = val;
                                            });
                                          },
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
                                        ),
                                        if (isEditing)
                                          SquadNeedsFormCard(
                                            eventId: widget.eventId!,
                                            hostId: widget.eventData!['hostId'],
                                            isPast: _isPast,
                                          )
                                        else
                                          _buildSquadNeedsButton(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              LockdownBanner(isPast: _isPast),
                              BannerPicker(
                                existingImageUrl: isEditing
                                    ? widget.eventData!['bannerUrl']
                                    : null,
                                isPast: _isPast,
                                onImageChanged: (path, removed) {
                                  setState(() {
                                    _bannerImagePath = path;
                                    _removeBanner = removed;
                                  });
                                },
                              ),
                              VitalsFormCard(
                                titleController: _titleController,
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
                              ),
                              ExtrasFormCard(
                                detailsController: _detailsController,
                                isPast: _isPast,
                                isImportantDetails: _isImportantDetails,
                                rsvpDeadlineOffset: _rsvpDeadlineOffset,
                                keepAliveDays: _keepAliveDays,
                                onImportantChanged: (val) {
                                  setState(() {
                                    _isImportantDetails = val;
                                  });
                                },
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
                              ),
                              if (isEditing)
                                SquadNeedsFormCard(
                                  eventId: widget.eventId!,
                                  hostId: widget.eventData!['hostId'],
                                  isPast: _isPast,
                                )
                              else
                                _buildSquadNeedsButton(),
                              CrewFormCard(
                                isPast: _isPast,
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
                              const SizedBox(height: 12),
                              EditorActionButtons(
                                isEditing: isEditing,
                                isMainHost: _isMainHost,
                                isPast: _isPast,
                                isLoading: _isLoading,
                                submitText: submitText,
                                onSubmit: _submitEvent,
                                onDelete: () =>
                                    EventService.deleteEventWithConfirmation(
                                      context: context,
                                      eventId: widget.eventId!,
                                      isVibeCheck: false,
                                      onLoadingChanged: (val) {
                                        setState(() {
                                          _isLoading = val;
                                        });
                                      },
                                    ),
                              ),
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
