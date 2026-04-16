import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

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

  bool _inviteAll = false;
  List<String> _selectedCircleIds = [];

  int _rsvpDeadlineOffset = 0;
  int _keepAliveDays = 0;
  bool _isImportantDetails = false;

  String? _bannerImagePath;
  bool _removeBanner = false;

  // --- RESTORED LOGIC STATE ---
  String? _selectedCoHostId;
  String? _selectedCoHostName;
  String? _selectedCoHostUsername;
  String? _selectedCoHostAvatarUrl;
  int? _selectedCoHostAvatarColor;

  bool _isLocFavorite = false;
  String? _favoriteDocId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (isEditing) {
      // --- EDIT MODE INITIALIZATION ---
      final data = widget.eventData!;
      _isMainHost = data['hostId'] == user?.uid;

      _titleController.text = data['title'] ?? '';
      _locController.text = data['location'] ?? '';
      _detailsController.text = data['details'] ?? data['description'] ?? '';

      if (data['time'] != null) {
        final dt = (data['time'] as Timestamp).toDate();
        _selectedDate = dt;
        _selectedTime = TimeOfDay.fromDateTime(dt);
      }

      _inviteAll = data['inviteAll'] ?? true;
      _selectedCircleIds = List<String>.from(data['invitedCircles'] ?? []);
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

      if (_locController.text.isNotEmpty) {
        _checkFavoriteStatus();
      }
    } else {
      // --- CREATE MODE INITIALIZATION ---
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
    if (user == null || _locController.text.isEmpty) {
      return;
    }

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
    if (user == null || _locController.text.isEmpty) {
      return;
    }

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

      if (confirmedName == null || confirmedName.isEmpty) {
        return;
      }

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

  // --- RESTORED CO-CAPTAIN LOGIC ---
  Future<void> _selectCoCaptain() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return FractionallySizedBox(
          heightFactor: 0.7,
          child: SafeArea(
            child: Column(
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
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Assign Co-Captain",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person_off, color: Colors.white),
                  ),
                  title: const Text(
                    "None",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedCoHostId = null;
                      _selectedCoHostName = null;
                      _selectedCoHostUsername = null;
                      _selectedCoHostAvatarUrl = null;
                      _selectedCoHostAvatarColor = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('friends')
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allFriends = snapshot.data!.docs;
                      final friends = allFriends.where((doc) {
                        if (_inviteAll) {
                          return true;
                        }
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final friendCircles = List<String>.from(
                          data['circles'] ?? [],
                        );
                        for (String circleId in _selectedCircleIds) {
                          if (friendCircles.contains(circleId)) {
                            return true;
                          }
                        }
                        return false;
                      }).toList();

                      if (friends.isEmpty) {
                        return const Center(
                          child: Text(
                            "No eligible friends found in the selected teams.",
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friendId = friends[index].id;
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(friendId)
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData || !userSnap.data!.exists) {
                                return const SizedBox.shrink();
                              }
                              final data =
                                  userSnap.data!.data() as Map<String, dynamic>;
                              final name = data['displayName'] ?? 'Unknown';
                              final username = data['username'] ?? '';
                              final avatarUrl = data['avatarUrl'];
                              final avatarColorVal = data['avatarColor'] is int
                                  ? data['avatarColor']
                                  : Colors.blue.toARGB32();
                              final avatarColor = Color(avatarColorVal);

                              return ListTile(
                                leading: CircleAvatar(
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
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: username.isNotEmpty
                                    ? Text(
                                        "@$username",
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCoHostId = friendId;
                                    _selectedCoHostName = name;
                                    _selectedCoHostUsername = username;
                                    _selectedCoHostAvatarUrl = avatarUrl;
                                    _selectedCoHostAvatarColor = avatarColorVal;
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- RESTORED DELETE LOGIC ---
  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Hangout?"),
        content: const Text(
          "Are you sure you want to permanently delete this hangout? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId);

        final batch = FirebaseFirestore.instance.batch();

        // Subcollection 1: Invitations
        final invitesSnap = await eventRef.collection('invitations').get();
        for (var doc in invitesSnap.docs) {
          batch.delete(doc.reference);
        }

        // Subcollection 2: Messages
        final messagesSnap = await eventRef.collection('messages').get();
        for (var doc in messagesSnap.docs) {
          batch.delete(doc.reference);
        }

        // Subcollection 3: Roles
        final rolesSnap = await eventRef.collection('roles').get();
        for (var doc in rolesSnap.docs) {
          batch.delete(doc.reference);
        }

        // Finally: Delete the main event document
        batch.delete(eventRef);

        await batch.commit();

        // Remove banner image if it exists to save storage space
        try {
          await FirebaseStorage.instance
              .ref()
              .child('event_banners/${widget.eventId}/banner.jpg')
              .delete();
        } catch (_) {}

        // Cleanup all chat images in the chat_images folder
        try {
          final chatImagesRef = FirebaseStorage.instance.ref().child(
            'chat_images/${widget.eventId}',
          );
          final listResult = await chatImagesRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
        } catch (_) {}

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Hangout deleted permanently."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locController.dispose();
    _detailsController.dispose();
    super.dispose();
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

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
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

        if (_isMainHost) {
          updateData['title'] = _titleController.text.trim();
          updateData['location'] = _locController.text.trim();
          updateData['details'] = _detailsController.text.trim();
          updateData['time'] = Timestamp.fromDate(newDateTime);
          updateData['endTime'] = Timestamp.fromDate(newEndTime);
          updateData['isImportantDetails'] = _isImportantDetails;
          updateData['rsvpDeadline'] = _rsvpDeadlineOffset;
          updateData['keepAliveDays'] = _keepAliveDays;
          updateData['inviteAll'] = _inviteAll;
          updateData['invitedCircles'] = _selectedCircleIds;
          updateData['coHostId'] = _selectedCoHostId;
          updateData['coHostName'] = _selectedCoHostName;

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
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI HELPER METHODS ---

  Widget _buildVitalsCard(bool isDark, Color primaryColor) {
    return RpgGlassCard(
      title: "The Vitals",
      icon: Icons.push_pin,
      child: Column(
        children: [
          CustomInputField(
            controller: _titleController,
            label: "Hangout Title",
            hint: "e.g. Bonfire & Chill",
            prefixIcon: Symbols.campaign,
            enabled: !_isPast,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          // RESTORED LOCATION FAVORITE BUTTON
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _locController,
                  label: "Location",
                  hint: "Tap to search address...",
                  prefixIcon: Icons.location_on,
                  prefixIconColor: isDark ? Colors.redAccent : Colors.red,
                  readOnly: true,
                  enabled: !_isPast,
                  onTap: _isPast ? null : _selectLocation,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
              ),
              if (_locController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: Icon(
                      _isLocFavorite ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: _isPast ? null : _toggleFavoriteStatus,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DateTimeRow(
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            enabled: !_isPast,
            onDateChanged: (d) => setState(() => _selectedDate = d),
            onTimeChanged: (t) => setState(() => _selectedTime = t),
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
          CustomInputField(
            controller: _detailsController,
            label: "Details / Description",
            prefixIcon: Icons.notes,
            prefixIconColor: isDark ? Colors.grey.shade400 : Colors.grey,
            maxLines: 3,
            enabled: !_isPast,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _isPast
                ? null
                : () => setState(
                    () => _isImportantDetails = !_isImportantDetails,
                  ),
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
                  Text(
                    "Important Details",
                    style: TextStyle(
                      fontWeight: _isImportantDetails
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _isImportantDetails
                          ? Colors.red
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
            ],
            selectedValue: _rsvpDeadlineOffset,
            onSelected: _isPast
                ? (v) {}
                : (v) => setState(() => _rsvpDeadlineOffset = v),
          ),
          const SizedBox(height: 24),
          TactileChipRow<int>(
            label: "Active for...",
            icon: Icons.timelapse,
            options: const [
              {'label': 'A few hours', 'value': 0},
              {'label': '1 Day', 'value': 1},
              {'label': '2 Days', 'value': 2},
              {'label': '3 Days', 'value': 3},
              {'label': '4 Days', 'value': 4},
              {'label': '5 Days', 'value': 5},
              {'label': '1 Week', 'value': 7},
              {'label': '10 Days', 'value': 10},
              {'label': '2 Weeks', 'value': 14},
            ],
            selectedValue: _keepAliveDays,
            onSelected: _isPast
                ? (v) {}
                : (v) => setState(() => _keepAliveDays = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewCard(bool isDark, Color primaryColor) {
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

                // Clear Co-Captain if they deselect all teams
                if (!_inviteAll && _selectedCircleIds.isEmpty) {
                  _selectedCoHostId = null;
                  _selectedCoHostName = null;
                  _selectedCoHostUsername = null;
                  _selectedCoHostAvatarUrl = null;
                  _selectedCoHostAvatarColor = null;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          // RESTORED CO-CAPTAIN SELECTOR WITH AVATAR & USERNAME & LOCK
          Opacity(
            opacity: (_inviteAll || _selectedCircleIds.isNotEmpty) ? 1.0 : 0.5,
            child: InkWell(
              onTap: _isPast
                  ? null
                  : () {
                      if (!_inviteAll && _selectedCircleIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Please select a Team or Entire Squad first.",
                            ),
                          ),
                        );
                        return;
                      }
                      _selectCoCaptain();
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    if (_selectedCoHostId == null)
                      Icon(Symbols.shield_person, color: primaryColor, size: 40)
                    else
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(
                          _selectedCoHostAvatarColor ?? Colors.blue.toARGB32(),
                        ),
                        backgroundImage: _selectedCoHostAvatarUrl != null
                            ? CachedNetworkImageProvider(
                                _selectedCoHostAvatarUrl!,
                              )
                            : null,
                        child: _selectedCoHostAvatarUrl == null
                            ? Text(
                                (_selectedCoHostName ?? "?")[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Co-Captain",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _selectedCoHostName ?? "None Assigned",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (_selectedCoHostUsername != null &&
                              _selectedCoHostUsername!.isNotEmpty)
                            Text(
                              "@$_selectedCoHostUsername",
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor, String submitText) {
    return Column(
      children: [
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
            child: Text(
              submitText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        // RESTORED DELETE EVENT BUTTON
        if (isEditing && _isMainHost) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _isPast || _isLoading ? null : _deleteEvent,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              "Delete Hangout",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final String appBarTitle = isEditing ? "Manage Hangout" : "Create Hangout";
    final String submitText = isEditing ? "Save Changes" : "Deploy Hangout";

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
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: isLandscape
                        // --- LANDSCAPE LAYOUT ---
                        ? Column(
                            children: [
                              if (_isPast) lockdownBanner,
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
                                        _buildVitalsCard(isDark, primaryColor),
                                        _buildCrewCard(isDark, primaryColor),
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
                              ),
                            ],
                          )
                        // --- PORTRAIT LAYOUT ---
                        : Column(
                            children: [
                              if (_isPast) lockdownBanner,
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
                              _buildCrewCard(isDark, primaryColor),
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
