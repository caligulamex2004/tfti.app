import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'friend_circles_page.dart';
import 'location_search_page.dart';
import 'theme_provider.dart';

String? _localBannerPath;
bool _removeBanner = false;

class EditEventPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EditEventPage({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _detailsController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _inviteAll = false;
  List<String> _selectedCircleIds = [];
  bool _isLoading = false;

  bool _isImportantDetails = false;

  // Tactile Chip State
  int _rsvpDeadlineOffset = 0;
  int _keepAliveDays = 0;

  bool _isLocFavorite = false;
  String? _favoriteDocId;

  late bool _isMainHost;
  late bool _isCoHost;

  String? _selectedCoHostId;
  String? _selectedCoHostName;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    _isMainHost = widget.eventData['hostId'] == user?.uid;
    _isCoHost = widget.eventData['coHostId'] == user?.uid;

    _titleController = TextEditingController(text: widget.eventData['title']);
    _locationController = TextEditingController(
      text: widget.eventData['location'],
    );

    String currentDetails =
        widget.eventData['details'] ?? widget.eventData['description'] ?? '';
    _detailsController = TextEditingController(text: currentDetails);

    if (widget.eventData['time'] != null) {
      Timestamp ts = widget.eventData['time'];
      DateTime dt = ts.toDate();
      _selectedDate = dt;
      _selectedTime = TimeOfDay.fromDateTime(dt);
    }

    _isImportantDetails = widget.eventData['isImportantDetails'] ?? false;
    _rsvpDeadlineOffset = widget.eventData['rsvpDeadline'] ?? 0;
    _keepAliveDays = widget.eventData['keepAliveDays'] ?? 0;

    if (_isCoHost && !_isMainHost) {
      _inviteAll = widget.eventData['coHostInviteAll'] ?? false;
      _selectedCircleIds = List<String>.from(
        widget.eventData['coHostInvitedCircles'] ?? [],
      );
    } else {
      _inviteAll = widget.eventData['inviteAll'] ?? true;
      _selectedCircleIds = List<String>.from(
        widget.eventData['invitedCircles'] ?? [],
      );

      _selectedCoHostId = widget.eventData['coHostId'];
      if (_selectedCoHostId != null) {
        _loadCoHostName(_selectedCoHostId!);
      }
    }

    _checkFavoriteStatus(_locationController.text);
  }

  Future<void> _loadCoHostName(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _selectedCoHostName = doc.data()?['displayName'] ?? "Unknown";
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
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
    if (user == null || _locationController.text.isEmpty) return;

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
              'address': _locationController.text.trim(),
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
        _locationController.text = selectedAddress;
      });
      _checkFavoriteStatus(selectedAddress);
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
                if (_isMainHost) {
                  _selectedCoHostId = null;
                  _selectedCoHostName = null;
                }
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
              title: const Text("Update The Crew"),
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
                          if (_isMainHost) {
                            _selectedCoHostId = null;
                            _selectedCoHostName = null;
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
                            if (_isMainHost) {
                              _selectedCoHostId = null;
                              _selectedCoHostName = null;
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

  Future<void> _deleteEvent() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String? seasonId = widget.eventData['seasonId'];
    String deleteScope = 'single';

    // 1. Determine Scope
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

      if (scope == null) return; // User swiped down
      deleteScope = scope;
    } else {
      // Standard confirmation for regular events
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

    // 2. Execute Deletion
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
        // --- FIX: Deep Cascading Batch Delete ---
        final currentEventTime = widget.eventData['time'] as Timestamp;
        final futureEvents = await firestore
            .collection('events')
            .where('seasonId', isEqualTo: seasonId)
            .where('time', isGreaterThanOrEqualTo: currentEventTime)
            .get();

        WriteBatch batch = firestore.batch();
        int opCount = 0;

        // Helper to commit batches so we don't crash Firebase's 500 limit
        Future<void> commitIfNeeded() async {
          if (opCount > 450) {
            await batch.commit();
            batch = firestore.batch();
            opCount = 0;
          }
        }

        for (var doc in futureEvents.docs) {
          final eventRef = doc.reference;

          // 1. Delete all invitations for this specific event
          final invites = await eventRef.collection('invitations').get();
          for (var inv in invites.docs) {
            batch.delete(inv.reference);
            opCount++;
            await commitIfNeeded();
          }

          // 2. Delete all messages for this specific event
          final msgs = await eventRef.collection('messages').get();
          for (var msg in msgs.docs) {
            batch.delete(msg.reference);
            opCount++;
            await commitIfNeeded();
          }

          // 3. Delete all squad needs/roles for this specific event
          final roles = await eventRef.collection('roles').get();
          for (var role in roles.docs) {
            batch.delete(role.reference);
            opCount++;
            await commitIfNeeded();
          }

          // 4. Finally, delete the event document itself
          batch.delete(eventRef);
          opCount++;
          await commitIfNeeded();
        }

        if (opCount > 0) await batch.commit();

        // Also delete the Parent Season document so it doesn't linger
        await firestore.collection('seasons').doc(seasonId).delete();

        // Also delete the shared Season banner image!
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

  Future<void> _updateEvent() async {
    if (_isMainHost && !(_formKey.currentState?.validate() ?? false)) return;

    final String? seasonId = widget.eventData['seasonId'];
    String updateScope = 'single';

    // 1. Intercept with Scope Prompt if it's a Season
    if (_isMainHost && seasonId != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  "Update Season",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  "Do you want to apply these changes to just this hangout, or to this and all future hangouts in the Season?",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text(
                    "This hangout only",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.pop(ctx, 'single'),
                ),
                ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text(
                    "This and all future hangouts",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.pop(ctx, 'future'),
                ),
              ],
            ),
          ),
        ),
      );

      if (scope == null) return;
      updateScope = scope;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final Map<String, dynamic> updateData = {
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };

      String? oldCoHostId = widget.eventData['coHostId'];

      if (_isMainHost) {
        final newDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        final newLocation = _locationController.text.trim();
        final oldTimestamp = widget.eventData['time'] as Timestamp;
        final oldDateTime = oldTimestamp.toDate();
        final oldLocation = (widget.eventData['location'] ?? '')
            .toString()
            .trim();
        final int oldKeepAliveDays = widget.eventData['keepAliveDays'] ?? 0;

        if (newLocation != oldLocation) {
          updateData['latestCriticalChange'] = {
            'field': 'Location',
            'original': oldLocation.isEmpty ? 'TBD' : oldLocation,
            'new': newLocation.isEmpty ? 'TBD' : newLocation,
            'timestamp': FieldValue.serverTimestamp(),
          };
        } else if (newDateTime != oldDateTime) {
          final oldDateStr =
              "${oldDateTime.month}/${oldDateTime.day}/${oldDateTime.year} @ ${TimeOfDay.fromDateTime(oldDateTime).format(context)}";
          final newDateStr =
              "${newDateTime.month}/${newDateTime.day}/${newDateTime.year} @ ${_selectedTime!.format(context)}";
          updateData['latestCriticalChange'] = {
            'field': 'Time/Date',
            'original': oldDateStr,
            'new': newDateStr,
            'timestamp': FieldValue.serverTimestamp(),
          };
        } else if (_keepAliveDays != oldKeepAliveDays) {
          String formatDuration(int val) {
            if (val == 0) return 'A few hours';
            if (val == 1) return '1 Day';
            if (val == 7) return '1 Week';
            return '$val Days';
          }

          updateData['latestCriticalChange'] = {
            'field': 'Duration',
            'original': formatDuration(oldKeepAliveDays),
            'new': formatDuration(_keepAliveDays),
            'timestamp': FieldValue.serverTimestamp(),
          };
        }

        updateData['title'] = _titleController.text.trim();
        updateData['location'] = newLocation;
        updateData['details'] = _detailsController.text.trim();
        updateData['time'] = Timestamp.fromDate(newDateTime);
        updateData['isImportantDetails'] = _isImportantDetails;
        updateData['rsvpDeadline'] = _rsvpDeadlineOffset;
        updateData['keepAliveDays'] = _keepAliveDays;
        updateData['inviteAll'] = _inviteAll;
        updateData['invitedCircles'] = _selectedCircleIds;
        updateData['coHostId'] = _selectedCoHostId;
      } else if (_isCoHost) {
        updateData['coHostInviteAll'] = _inviteAll;
        updateData['coHostInvitedCircles'] = _selectedCircleIds;
      }

      // --- Handle Image Upload First so the URL is ready for the batch ---
      if (_isMainHost) {
        if (_removeBanner) {
          updateData['bannerUrl'] = FieldValue.delete();
          try {
            await FirebaseStorage.instance
                .ref()
                .child('event_banners/${widget.eventId}/banner.jpg')
                .delete();
          } catch (_) {}
        } else if (_localBannerPath != null) {
          try {
            final File file = File(_localBannerPath!);
            final Uint8List bytes = await file.readAsBytes();
            final Uint8List compressedBytes =
                await FlutterImageCompress.compressWithList(
                  bytes,
                  minWidth: 1280,
                  minHeight: 720,
                  quality: 75,
                );

            // If it's a season, upload under the seasonId to share the URL!
            final storageFolder = seasonId ?? widget.eventId;
            final ref = FirebaseStorage.instance.ref().child(
              'event_banners/$storageFolder/banner.jpg',
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
      }

      // --- APPLY THE SCOPED BATCH UPDATE ---
      final batch = FirebaseFirestore.instance.batch();

      if (updateScope == 'single') {
        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId);
        batch.update(eventRef, updateData);

        // Handle Invites for Single Event
        final friendsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .get();
        Set<String> newIntendedIds = {};
        Set<String> oldIntendedIds = {};
        final bool oldInviteAll = _isCoHost
            ? (widget.eventData['coHostInviteAll'] ?? false)
            : (widget.eventData['inviteAll'] ?? true);
        final List<String> oldCircles = List<String>.from(
          _isCoHost
              ? (widget.eventData['coHostInvitedCircles'] ?? [])
              : (widget.eventData['invitedCircles'] ?? []),
        );

        for (var friendDoc in friendsSnapshot.docs) {
          final friendCircles = List<String>.from(
            friendDoc.data()['circles'] ?? [],
          );
          if (_inviteAll ||
              _selectedCircleIds.any((id) => friendCircles.contains(id)))
            newIntendedIds.add(friendDoc.id);
          if (oldInviteAll ||
              oldCircles.any((id) => friendCircles.contains(id)))
            oldIntendedIds.add(friendDoc.id);
        }

        final currentInvitesSnap = await eventRef
            .collection('invitations')
            .get();
        final Set<String> currentlyInvitedIds = currentInvitesSnap.docs
            .map((d) => d.id)
            .toSet();

        Set<String> toAdd = newIntendedIds.difference(currentlyInvitedIds);
        Set<String> toRemove = oldIntendedIds.difference(newIntendedIds);

        toRemove.remove(widget.eventData['hostId']);
        if (widget.eventData['coHostId'] != null)
          toRemove.remove(widget.eventData['coHostId']);

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
          updateData['visibleTo'] = FieldValue.arrayRemove(toRemove.toList());
          for (String uid in toRemove) {
            batch.delete(eventRef.collection('invitations').doc(uid));
          }
        }

        if (_isMainHost && oldCoHostId != _selectedCoHostId) {
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

        batch.set(
          eventRef.collection('invitations').doc(user.uid),
          {'lastViewedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      } else if (updateScope == 'future' && seasonId != null) {
        // --- CASCADING BATCH FUTURE UPDATE ---
        final currentEventTime = widget.eventData['time'] as Timestamp;
        final futureEvents = await FirebaseFirestore.instance
            .collection('events')
            .where('seasonId', isEqualTo: seasonId)
            .where('time', isGreaterThanOrEqualTo: currentEventTime)
            .get();

        // Calculate time shift delta for future events
        final oldDateTime = currentEventTime.toDate();
        final newDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        final timeDifference = newDateTime.difference(oldDateTime);

        int opCount = 0;

        // Strip out 'latestCriticalChange' from the blanket update so it doesn't duplicate the string
        Map<String, dynamic> cascadingData = Map.from(updateData);
        cascadingData.remove('latestCriticalChange');

        for (var doc in futureEvents.docs) {
          final futureEventTime = (doc.data()['time'] as Timestamp).toDate();
          final shiftedTime = futureEventTime.add(timeDifference);

          cascadingData['time'] = Timestamp.fromDate(shiftedTime);

          // We also preserve the specific event ID critical change for just the edited one
          if (doc.id == widget.eventId &&
              updateData.containsKey('latestCriticalChange')) {
            cascadingData['latestCriticalChange'] =
                updateData['latestCriticalChange'];
          }

          batch.update(doc.reference, cascadingData);
          opCount++;

          if (opCount > 450) {
            await batch.commit();
            opCount = 0;
          }
        }

        // Update parent season document
        await FirebaseFirestore.instance
            .collection('seasons')
            .doc(seasonId)
            .update({
              'title': cascadingData['title'],
              'location': cascadingData['location'],
              'details': cascadingData['details'],
            });
      }

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

  void _showSquadNeedsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUser = FirebaseAuth.instance.currentUser!;
    final roleController = TextEditingController();
    const bool canEdit = true; // Always true on the Edit Page

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
                                      // ignore: dead_code
                                      : "No squad needs right now.",
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

                            final isClaimed = assigneeId != null;
                            final isMe = assigneeId == currentUser.uid;

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
                                  decoration: null,
                                  color: isClaimed
                                      ? (isDark
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade500)
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
                                  if (!isClaimed)
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
                                  else if (isMe || canEdit)
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
                                  if (canEdit)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        roleDoc.reference.delete();
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

                  if (canEdit) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: roleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: "Add a new need (e.g. Bring Ice)",
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (val) async {
                                if (val.trim().isEmpty) return;
                                await FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(widget.eventId)
                                    .collection('roles')
                                    .add({
                                      'title': val.trim(),
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                roleController.clear();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () async {
                                if (roleController.text.trim().isEmpty) return;
                                await FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(widget.eventId)
                                    .collection('roles')
                                    .add({
                                      'title': roleController.text.trim(),
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                roleController.clear();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _buildCoHostView(bool isDark, Color primaryColor, User user) {
    final circlesField = StreamBuilder<QuerySnapshot>(
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
                (c) => (c.data() as Map<String, dynamic>)['name'] ?? 'Unnamed',
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
              label: "Update Crew List",
              prefixIcon: Icon(
                Icons.people,
                color: isDark ? Colors.tealAccent : Colors.teal,
              ),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              targetPreviewText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildFormCard(
            title: "Co-Captain Dashboard",
            icon: Symbols.military_tech,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                circlesField,
                const SizedBox(height: 16),
                InkWell(
                  onTap: _showSquadNeedsSheet,
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _updateEvent,
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBannerOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasExistingUrl =
        widget.eventData['bannerUrl'] != null && !_removeBanner;

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
            if (_localBannerPath != null || hasExistingUrl) ...[
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
                  setState(() {
                    _localBannerPath = null;
                    _removeBanner = true;
                  });
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
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
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
      setState(() {
        _localBannerPath = croppedFile.path;
        _removeBanner = false;
      });
    }
  }

  Widget _buildBannerPicker(bool isDark, Color primaryColor) {
    final hasExistingUrl =
        widget.eventData['bannerUrl'] != null && !_removeBanner;
    final hasLocalImage = _localBannerPath != null;
    final hasImage = hasExistingUrl || hasLocalImage;

    DecorationImage? imageDecoration;
    if (hasLocalImage) {
      imageDecoration = DecorationImage(
        image: FileImage(File(_localBannerPath!)),
        fit: BoxFit.cover,
      );
    } else if (hasExistingUrl) {
      imageDecoration = DecorationImage(
        image: CachedNetworkImageProvider(widget.eventData['bannerUrl']),
        fit: BoxFit.cover,
      );
    }

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
              image: imageDecoration,
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

    final titleField = TextFormField(
      controller: _titleController,
      maxLength: 50,
      decoration: _buildInputDecoration(
        label: 'Hangout Title',
        prefixIcon: Icon(Symbols.campaign, color: primaryColor),
      ).copyWith(counterText: ""),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );

    final locationField = TextFormField(
      controller: _locationController,
      readOnly: true,
      onTap: _selectLocation,
      maxLength: 100,
      decoration: _buildInputDecoration(
        label: 'Location',
        hint: "Tap to search address...",
        prefixIcon: Icon(
          Icons.location_on,
          color: isDark ? Colors.redAccent : Colors.red,
        ),
        suffixIcon: _locationController.text.isNotEmpty
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
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
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
              child: Text(
                _selectedDate == null
                    ? 'Select Date'
                    : "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}",
                style: const TextStyle(fontSize: 16),
              ),
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
              child: Text(
                _selectedTime == null
                    ? 'Select Time'
                    : _selectedTime!.format(context),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );

    final detailsField = TextFormField(
      controller: _detailsController,
      maxLength: 500,
      decoration: _buildInputDecoration(
        label: 'Details / Description',
        prefixIcon: Icon(
          Icons.notes,
          color: isDark ? Colors.grey.shade400 : Colors.grey,
        ),
      ).copyWith(alignLabelWithHint: true, counterText: ""),
      maxLines: 3,
    );

    final togglesRow = Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _showSquadNeedsSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_box_outlined, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Squad Needs",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
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

    // --- CARDS ---

    final vitalsCard = _buildFormCard(
      title: "The Vitals",
      icon: Icons.push_pin,
      child: Column(
        children: [
          _buildResponsiveRow(isLandscape, titleField, locationField),
          dateTimeRow,
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
          const SizedBox(height: 16),
          togglesRow,
          const SizedBox(height: 24),

          _buildChipRow(
            label: "RSVP Deadline",
            icon: Icons.timer_off_outlined,
            selectedValue: _rsvpDeadlineOffset,
            onSelected: (val) => setState(() => _rsvpDeadlineOffset = val),
            options: [
              {'label': 'At start time', 'value': 0},
              {'label': '30 mins before', 'value': -30},
              {'label': '1 hr before', 'value': -60},
              {'label': '2 hrs before', 'value': -120},
              {'label': '4 hrs before', 'value': -240},
              {'label': '24 hrs before', 'value': -1440},
              {'label': '1 hr after', 'value': 60},
            ],
          ),

          const SizedBox(height: 24),

          _buildChipRow(
            label: "Active for...",
            icon: Icons.timelapse,
            selectedValue: _keepAliveDays,
            onSelected: (val) => setState(() => _keepAliveDays = val),
            options: [
              {'label': 'Standard (A few hours)', 'value': 0},
              {'label': '1 Day', 'value': 1},
              {'label': '2 Days', 'value': 2},
              {'label': '3 Days', 'value': 3},
              {'label': '4 Days', 'value': 4},
              {'label': '5 Days', 'value': 5},
              {'label': '1 Week', 'value': 7},
              {'label': '10 Days', 'value': 10},
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

                String targetPreviewText = "Select Squads...";
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

                final coHostField = InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _showCoHostDialog,
                  child: InputDecorator(
                    decoration: _buildInputDecoration(
                      label: "Change Co-Captain (optional)",
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

                return _buildResponsiveRow(
                  isLandscape,
                  circlesField,
                  coHostField,
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
            onPressed: _updateEvent,
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
            onPressed: _deleteEvent,
            icon: Icon(
              Icons.delete,
              color: isDark ? Colors.redAccent : Colors.red,
            ),
            label: Text(
              "Delete Hangout",
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
        title: Text(
          _isMainHost ? "Change of Plans" : "Manage Hangout",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_isCoHost && !_isMainHost)
          ? _buildCoHostView(isDark, primaryColor, user!)
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
                                  bannerPicker,
                                  vitalsCard,
                                  crewCard,
                                  actionButtons,
                                ],
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
