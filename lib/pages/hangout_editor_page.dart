import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/theme_provider.dart';
import '../components/shared/rpg_glass_card.dart';
import '../components/shared/banner_picker.dart';
import '../components/forms/custom_input_field.dart';
import '../components/forms/tactile_chip_row.dart';
import '../components/forms/date_time_row.dart';
import '../components/forms/team_selection_field.dart';
import 'places_search_page.dart';

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

  // Form Controllers
  final _titleController = TextEditingController();
  final _locController = TextEditingController();
  final _detailsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _rsvpDeadlineOffset = 0;

  bool _inviteAll = false;
  List<String> _selectedCircleIds = [];

  String? _bannerImagePath;
  bool _removeBanner = false;

  // --- RESTORED LOGIC STATE ---
  String? _selectedCoHostId;
  String? _selectedCoHostName;
  bool _isLocFavorite = false;
  String? _favoriteDocId;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  void _initForm() {
    if (isEditing) {
      final data = widget.eventData!;
      final user = FirebaseAuth.instance.currentUser;

      _titleController.text = data['title'] ?? '';
      _locController.text = data['location'] ?? '';
      _detailsController.text = data['details'] ?? '';

      final Timestamp? ts = data['time'];
      if (ts != null) {
        final dt = ts.toDate();
        _selectedDate = dt;
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }

      _inviteAll = data['inviteAll'] == true;
      _selectedCircleIds = List<String>.from(data['invitedCircles'] ?? []);

      _isMainHost = data['hostId'] == user?.uid;
      _isPast = data['isPast'] == true;

      _selectedCoHostId = data['coHostId'];
      _selectedCoHostName = data['coHostName'];

      _checkFavoriteStatus();
    } else {
      _isMainHost = true;
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

  // --- RESTORED LOCATION LOGIC ---
  Future<void> _checkFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _locController.text.isEmpty) return;

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorite_places')
        .where('address', isEqualTo: _locController.text)
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        _isLocFavorite = query.docs.isNotEmpty;
        _favoriteDocId = query.docs.isNotEmpty ? query.docs.first.id : null;
      });
    }
  }

  Future<void> _toggleFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _locController.text.isEmpty) return;

    HapticFeedback.lightImpact();

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removed from Goated Places")),
        );
      }
    } else {
      // --- Pop up the naming dialog before saving! ---
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final defaultName = _locController.text.split(',').first;
      final nameController = TextEditingController(text: defaultName);

      final confirmedName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Save Goated Place"),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: "Give this spot a name...",
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                "Save",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      // If the user taps Cancel or leaves it completely blank, abort the save.
      if (confirmedName == null || confirmedName.isEmpty) return;

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorite_places')
          .add({
            'name': confirmedName,
            'address': _locController.text,
            'createdAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _isLocFavorite = true;
        _favoriteDocId = docRef.id;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Added to Goated Places! 🐐")),
        );
      }
    }
  }

  Future<void> _selectLocation() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlacesSearchPage(showFavorites: true),
      ),
    );
    if (selectedAddress != null && mounted) {
      setState(() => _locController.text = selectedAddress);
      _checkFavoriteStatus();
    }
  }

  // --- RESTORED CO-HOST LOGIC ---
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
            "Select \"Who's getting the i?\" first to pick a co-captain!",
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

  // --- RESTORED SQUAD NEEDS LOGIC ---
  void _showSquadNeedsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUser = FirebaseAuth.instance.currentUser!;
    final roleController = TextEditingController();
    final bool canEdit = !_isPast;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
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
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_box_outlined,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Squad Needs",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Flexible(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('events')
                          .doc(widget.eventId)
                          .collection('roles')
                          .orderBy('createdAt')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final roles = snapshot.data!.docs;

                        if (roles.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volunteer_activism,
                                  size: 48,
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  canEdit
                                      ? "Add items you need help with!"
                                      : "No squad needs were added.",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: roles.length,
                          itemBuilder: (context, index) {
                            final roleDoc = roles[index];
                            final roleData =
                                roleDoc.data() as Map<String, dynamic>;
                            final title = roleData['title'] ?? 'Item';
                            final assigneeId = roleData['claimedByUid'];
                            final assigneeName = roleData['claimedByName'];
                            final addedBy = roleData['addedBy'];

                            final isClaimed = assigneeId != null;
                            final isMe = assigneeId == currentUser.uid;
                            final isItemCreator = addedBy == currentUser.uid;
                            final canManageItem = _isMainHost || isItemCreator;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isClaimed
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : (isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade100),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isClaimed
                                      ? Icons.check
                                      : Icons.pan_tool_outlined,
                                  color: isClaimed
                                      ? Colors.green
                                      : (isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isClaimed
                                      ? Colors.grey.shade500
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                              ),
                              subtitle: isClaimed
                                  ? Text(
                                      isMe
                                          ? "Claimed by you"
                                          : "Claimed by $assigneeName",
                                      style: TextStyle(
                                        color: isMe
                                            ? primaryColor
                                            : (isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600),
                                        fontWeight: isMe
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isClaimed && canEdit)
                                    ElevatedButton(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        final userDoc = await FirebaseFirestore
                                            .instance
                                            .collection('users')
                                            .doc(currentUser.uid)
                                            .get();
                                        final myName =
                                            userDoc.data()?['displayName'] ??
                                            "Someone";
                                        await roleDoc.reference.update({
                                          'claimedByUid': currentUser.uid,
                                          'claimedByName': myName,
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text(
                                        "Claim",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if ((isMe || canManageItem) && canEdit)
                                    OutlinedButton(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        await roleDoc.reference.update({
                                          'claimedByUid': FieldValue.delete(),
                                          'claimedByName': FieldValue.delete(),
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        isMe ? "Unclaim" : "Unassign",
                                      ),
                                    ),
                                  if (canManageItem && canEdit)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        HapticFeedback.heavyImpact();
                                        await roleDoc.reference.delete();
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (canEdit)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: roleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: "e.g. Bring cups...",
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final text = roleController.text.trim();
                              if (text.isEmpty) return;
                              roleController.clear();
                              FocusScope.of(context).unfocus();
                              await FirebaseFirestore.instance
                                  .collection('events')
                                  .doc(widget.eventId)
                                  .collection('roles')
                                  .add({
                                    'title': text,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'addedBy': currentUser.uid,
                                  });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(14),
                            ),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- RESTORED DANGER ZONE LOGIC ---
  Future<void> _deleteEvent() async {
    if (_isPast) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String? seasonId = widget.eventData?['seasonId'];
    String deleteScope = 'single';

    // 1. Determine Scope for Recurring Events
    if (seasonId != null) {
      final scope = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delete Hangout",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  "This hangout is part of a recurring Season. Do you want to cancel just this one, or the entire remaining season?",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.event_busy),
                  title: const Text(
                    "Cancel just this hangout",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.pop(ctx, 'single'),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_delete, color: Colors.red),
                  title: const Text(
                    "Cancel this and all future hangouts",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, 'future'),
                ),
              ],
            ),
          ),
        ),
      );

      if (scope == null) return;
      deleteScope = scope;
    } else {
      // Standard confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Hangout?'),
          content: const Text(
            'This will permanently delete the hangout, the squad list, and the chat history.',
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
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    // 2. Execute Deep Cascade Deletion
    try {
      final firestore = FirebaseFirestore.instance;

      if (deleteScope == 'single') {
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

        try {
          await FirebaseStorage.instance
              .ref()
              .child('event_banners/${widget.eventId}/banner.jpg')
              .delete();
        } catch (_) {}

        await eventRef.delete();
      } else if (deleteScope == 'future' && seasonId != null) {
        final currentEventTime = widget.eventData!['time'] as Timestamp;
        final futureEvents = await firestore
            .collection('events')
            .where('seasonId', isEqualTo: seasonId)
            .where('time', isGreaterThanOrEqualTo: currentEventTime)
            .get();

        WriteBatch batch = firestore.batch();
        int opCount = 0;

        Future<void> commitIfNeeded() async {
          if (opCount > 450) {
            await batch.commit();
            batch = firestore.batch();
            opCount = 0;
          }
        }

        for (var doc in futureEvents.docs) {
          final eventRef = doc.reference;
          final invites = await eventRef.collection('invitations').get();
          for (var inv in invites.docs) {
            batch.delete(inv.reference);
            opCount++;
            await commitIfNeeded();
          }
          final msgs = await eventRef.collection('messages').get();
          for (var msg in msgs.docs) {
            batch.delete(msg.reference);
            opCount++;
            await commitIfNeeded();
          }
          final roles = await eventRef.collection('roles').get();
          for (var role in roles.docs) {
            batch.delete(role.reference);
            opCount++;
            await commitIfNeeded();
          }
          batch.delete(eventRef);
          opCount++;
          await commitIfNeeded();
        }

        if (opCount > 0) await batch.commit();
        await firestore.collection('seasons').doc(seasonId).delete();

        try {
          await FirebaseStorage.instance
              .ref()
              .child('event_banners/$seasonId/banner.jpg')
              .delete();
        } catch (_) {}
      }

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // --- BATCH SUBMIT/UPDATE LOGIC ---
  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_inviteAll && _selectedCircleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who to invite.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      String? finalBannerUrl;
      if (!isEditing) {
        finalBannerUrl = null;
      } else {
        finalBannerUrl = _removeBanner ? null : widget.eventData!['bannerUrl'];
      }

      final eventRef = isEditing
          ? FirebaseFirestore.instance.collection('events').doc(widget.eventId)
          : FirebaseFirestore.instance.collection('events').doc();

      if (_bannerImagePath != null) {
        final File imageFile = File(_bannerImagePath!);
        final bytes = await imageFile.readAsBytes();
        final compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 800,
          minHeight: 600,
          quality: 85,
        );

        final ref = FirebaseStorage.instance.ref().child(
          'event_banners/${eventRef.id}/banner.jpg',
        );
        await ref.putData(
          compressedBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        finalBannerUrl = await ref.getDownloadURL();
      }

      final batch = FirebaseFirestore.instance.batch();

      if (isEditing) {
        // ==========================================
        //         EDIT MODE (UPDATE HANGOUT)
        // ==========================================
        final int keepAliveDays = widget.eventData!['keepAliveDays'] ?? 0;
        final int durationMinutes = keepAliveDays > 0
            ? (keepAliveDays * 24 * 60)
            : 240;
        final newEndTime = combinedDateTime.add(
          Duration(minutes: durationMinutes),
        );

        final eventPayload = {
          'title': _titleController.text.trim(),
          'location': _locController.text.trim(),
          'details': _detailsController.text.trim(),
          'time': Timestamp.fromDate(combinedDateTime),
          'endTime': Timestamp.fromDate(newEndTime),
          'type': 'event',
          'inviteAll': _inviteAll,
          'invitedCircles': _selectedCircleIds,
          'rsvpDeadline': _rsvpDeadlineOffset,
          'bannerUrl': finalBannerUrl,
          'coHostId': _selectedCoHostId,
          'coHostName': _selectedCoHostName,
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

        final currentInvitesSnap = await eventRef
            .collection('invitations')
            .get();
        final Set<String> currentlyInvitedIds = currentInvitesSnap.docs
            .map((d) => d.id)
            .toSet();

        Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
        Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);

        toRemove.remove(widget.eventData!['hostId']);
        if (_selectedCoHostId != null) toRemove.remove(_selectedCoHostId);

        if (toAdd.isNotEmpty) {
          eventPayload['visibleTo'] = FieldValue.arrayUnion(toAdd.toList());
          for (String uid in toAdd) {
            if (!currentlyInvitedIds.contains(uid)) {
              batch.set(eventRef.collection('invitations').doc(uid), {
                'uid': uid,
                'role': uid == _selectedCoHostId ? 'co-host' : 'guest',
                'status': 'pending',
                'sentAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        if (toRemove.isNotEmpty) {
          eventPayload['visibleTo'] = FieldValue.arrayRemove(toRemove.toList());
          for (String uid in toRemove) {
            batch.delete(eventRef.collection('invitations').doc(uid));
          }
        }

        // Update co-host roles
        String? oldCoHostId = widget.eventData!['coHostId'];
        if (oldCoHostId != _selectedCoHostId) {
          if (oldCoHostId != null && !toRemove.contains(oldCoHostId)) {
            batch.update(eventRef.collection('invitations').doc(oldCoHostId), {
              'role': 'guest',
            });
          }
          if (_selectedCoHostId != null) {
            batch.set(
              eventRef.collection('invitations').doc(_selectedCoHostId),
              {'role': 'co-host'},
              SetOptions(merge: true),
            );
          }
        }

        batch.update(eventRef, eventPayload);
        batch.set(
          eventRef.collection('invitations').doc(user.uid),
          {'lastViewedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      } else {
        // ==========================================
        //        CREATE MODE (NEW HANGOUT)
        // ==========================================
        final defaultEndTime = combinedDateTime.add(const Duration(hours: 4));

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

        final eventPayload = {
          'type': 'event',
          'title': _titleController.text.trim(),
          'location': _locController.text.trim(),
          'details': _detailsController.text.trim(),
          'time': Timestamp.fromDate(combinedDateTime),
          'endTime': Timestamp.fromDate(defaultEndTime),
          'keepAliveDays': 0, // Fallback
          'hostId': user.uid,
          'coHostId': _selectedCoHostId,
          'coHostName': _selectedCoHostName,
          'isPast': false,
          'created_at': FieldValue.serverTimestamp(),
          'visibleTo': visibleToIds.toList(),
          'inviteAll': _inviteAll,
          'invitedCircles': _selectedCircleIds,
          'rsvpDeadline': _rsvpDeadlineOffset,
          'bannerUrl': finalBannerUrl,
        };

        batch.set(eventRef, eventPayload);

        for (var friendDoc in friendsToInvite) {
          bool isCoHost = friendDoc.id == _selectedCoHostId;
          batch.set(eventRef.collection('invitations').doc(friendDoc.id), {
            'uid': friendDoc.id,
            'role': isCoHost ? 'co-host' : 'guest',
            'status': 'pending',
            'sentAt': FieldValue.serverTimestamp(),
          });
        }

        // Host is automatically "going"
        batch.set(eventRef.collection('invitations').doc(user.uid), {
          'uid': user.uid,
          'role': 'host',
          'status': 'going',
          'sentAt': FieldValue.serverTimestamp(),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? "Changes saved!" : "Hangout created! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving hangout: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI BUILDING BLOCKS ---
  Widget _buildVitalsCard(bool isDark, Color primaryColor) {
    return RpgGlassCard(
      title: "The Vitals",
      icon: Icons.info_outline,
      child: Column(
        children: [
          CustomInputField(
            controller: _titleController,
            label: "What's the move?",
            hint: "e.g. Bonfire & Chill",
            prefixIcon: Symbols.celebration,
            prefixIconColor: primaryColor,
          ),
          const SizedBox(height: 16),
          DateTimeRow(
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            onDateChanged: (date) {
              setState(() => _selectedDate = date);
            },
            onTimeChanged: (time) {
              setState(() => _selectedTime = time);
            },
          ),
          const SizedBox(height: 16),
          CustomInputField(
            controller: _locController,
            label: "Where we dropping?",
            hint: "Search or type address...",
            prefixIcon: Icons.location_on,
            prefixIconColor: primaryColor,
            readOnly: true,
            onTap: _selectLocation,
            suffixIcon: IconButton(
              icon: Icon(
                _isLocFavorite ? Icons.star : Icons.star_border,
                color: _isLocFavorite
                    ? Colors.amber
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              onPressed: _toggleFavoriteStatus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewCard() {
    return RpgGlassCard(
      title: "The Crew",
      icon: Icons.group,
      child: Column(
        children: [
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showCoHostDialog,
                  icon: const Icon(Symbols.military_tech),
                  label: Text(
                    _selectedCoHostName != null
                        ? "Co: ${_selectedCoHostName!.split(' ').first}"
                        : "Co-Captain",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSquadNeedsSheet,
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text("Squad Needs"),
                  ),
                ),
              ],
            ],
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
            label: "RSVP Deadline",
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

  Widget _buildDangerCard() {
    if (!isEditing || !_isMainHost || _isPast) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: RpgGlassCard(
        title: "Danger Zone",
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red,
        titleColor: Colors.red,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deleteEvent,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              "Delete Hangout",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor, String submitText) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading || _isPast ? null : _submitEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
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
    final String submitText = isEditing ? "Save Changes" : "Send i's";

    Widget lockdownBanner = _isPast
        ? Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "This hangout has already passed. It can no longer be edited.",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Hangout" : "Create Hangout",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: SafeArea(
        child: _isLoading && !isEditing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 32.0 : 20.0,
                    vertical: 24.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: isLandscape
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    lockdownBanner,
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
                                    _buildVitalsCard(isDark, primaryColor),
                                    _buildCrewCard(),
                                    _buildDangerCard(),
                                    const SizedBox(height: 12),
                                    _buildSubmitButton(
                                      primaryColor,
                                      submitText,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildExtrasCard(isDark, primaryColor),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              lockdownBanner,
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
                              _buildVitalsCard(isDark, primaryColor),
                              _buildExtrasCard(isDark, primaryColor),
                              _buildCrewCard(),
                              _buildDangerCard(),
                              const SizedBox(height: 12),
                              _buildSubmitButton(primaryColor, submitText),
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
