import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_cropper/image_cropper.dart';

import '../components/shared/tcg_profile_card.dart';
import '../utils/phone_formatter.dart';
import 'preferences_page.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();

  String _phoneNumber = '';
  String? _currentUsername;

  int _selectedColorValue = Colors.blue.toARGB32();
  bool _isLoading = false;
  bool _showPhoneNumber = false;

  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  int _hp = 0;
  int _mana = 0;
  String _originDate = "";

  StreamSubscription<DocumentSnapshot>? _userSub;
  bool _hasLoadedInitialData = false;

  final List<Color> _colors = [
    Colors.blue,
    const Color(0xFFEE0909), // Beyond Dark
    const Color(0xFF1C8D6C), // Jade Edge
    const Color(0xFFFFAB00), // Electric Amber
    Colors.deepPurple, // Royal Purple
    const Color(0xFF00E5FF), // Cyber Punk
    const Color(0xFFFF9A9E), // Lip Gloss
    Colors.black,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _statusController.addListener(_onFormChanged);
    _listenToUserData();
  }

  void _onFormChanged() {
    setState(() {}); // Triggers a live UI rebuild
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _statusController.removeListener(_onFormChanged);
    _autoSaveIdentity();
    _userSub?.cancel();
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _listenToUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // --- GUARANTEED FALLBACK: Pull from Firebase Auth Metadata! ---
    if (user.metadata.creationTime != null) {
      final dt = user.metadata.creationTime!;
      final List<String> months = [
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
      _originDate = "Joined ${months[dt.month - 1]} ${dt.year}";
    }

    setState(() => _isLoading = true);

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
          if (snap.exists) {
            final data = snap.data() as Map<String, dynamic>;

            // --- REAL-TIME SYNCED VARIABLES ---
            // These live OUTSIDE the flag so they update instantly!
            if (data.containsKey('hp')) _hp = data['hp'] ?? 0;
            if (data.containsKey('mana')) _mana = data['mana'] ?? 0;
            if (data.containsKey('avatarUrl')) _avatarUrl = data['avatarUrl'];
            if (data.containsKey('avatarColor')) {
              _selectedColorValue = data['avatarColor'];
            }
            if (data.containsKey('showPhoneNumber')) {
              _showPhoneNumber = data['showPhoneNumber'] ?? false;
            }

            // --- ONE-TIME INITIALIZATION ---
            // Text fields stay inside to prevent the stream from interrupting your typing!
            if (!_hasLoadedInitialData) {
              if (data.containsKey('displayName')) {
                _nameController.text = data['displayName'];
              }
              if (data.containsKey('statusText')) {
                _statusController.text = data['statusText'];
              }
              if (data.containsKey('phoneNumber')) {
                _phoneNumber = PhoneFormatter.beautify(data['phoneNumber']);
              } else if (data.containsKey('phone')) {
                _phoneNumber = PhoneFormatter.beautify(data['phone']);
              }
              if (data.containsKey('username')) {
                _currentUsername = data['username'];
              }

              if (data.containsKey('createdAt') ||
                  data.containsKey('created_at')) {
                final Timestamp? ts = data['createdAt'] ?? data['created_at'];
                if (ts != null) {
                  final dt = ts.toDate();
                  final List<String> months = [
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
                  _originDate = "Joined ${months[dt.month - 1]} ${dt.year}";
                }
              }

              _hasLoadedInitialData = true;
            }
          }

          if (mounted) {
            setState(() => _isLoading = false);
          }
        });
  }

  void _autoSaveIdentity() {
    final newName = _nameController.text.trim();
    final newStatus = _statusController.text.trim();
    if (newName.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != newName) {
        user.updateDisplayName(newName);
      }

      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'displayName': newName,
            'statusText': newStatus,
            'avatarColor': _selectedColorValue,
            'showPhoneNumber': _showPhoneNumber,
          })
          .catchError((e) => debugPrint("Auto-save error: $e"));
    }
  }

  void _showAvatarOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              title: const Text(
                "Choose from Gallery",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _uploadAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(
                "Take a Photo",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _uploadAvatar(ImageSource.camera);
              },
            ),
            if (_avatarUrl != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Remove Photo",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAvatar(ImageSource source) async {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    // Now safely launch the cropper
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(
        ratioX: 1,
        ratioY: 1,
      ), // Force square proportions
      compressQuality:
          100, // Keep quality high here, our custom compressor handles it next
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Photo',
          toolbarColor:
              primaryColor, // Uses the color we safely grabbed earlier
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Adjust Profile Photo',
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Save',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    // If they cancel out of the cropper, gracefully back out
    if (croppedFile == null) return;

    if (!mounted) return;
    setState(() => _isUploadingAvatar = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isUploadingAvatar = false);
      return;
    }

    try {
      final File file = File(croppedFile.path);
      final Uint8List bytes = await file.readAsBytes();

      final Uint8List compressedBytes =
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 512,
            minHeight: 512,
            quality: 75,
          );

      final Reference ref = FirebaseStorage.instance.ref().child(
        'profile_images/${user.uid}/avatar.jpg',
      );

      final UploadTask uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'avatarUrl': downloadUrl},
      );

      await user.updatePhotoURL(downloadUrl);
    } catch (e) {
      debugPrint("Error uploading avatar: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to upload photo")));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final Reference ref = FirebaseStorage.instance.ref().child(
        'profile_images/${user.uid}/avatar.jpg',
      );
      await ref.delete();
    } catch (e) {
      debugPrint("Storage file might not exist: $e");
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'avatarUrl': FieldValue.delete()},
      );

      await user.updatePhotoURL(null);
    } catch (e) {
      debugPrint("Error removing avatar from DB: $e");
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _launchLegalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Could not launch link")));
      }
    }
  }

  Future<void> _showTipJar() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Buy the Dev a Coffee ☕",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "tfti.app is free to use, but server costs add up! If you love the app, consider dropping a tip to keep the servers running.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 30),

                FutureBuilder<Offerings>(
                  future: Purchases.getOfferings(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.current == null) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "Store not available right now. Please try again later!",
                        ),
                      );
                    }

                    final packages = snapshot.data!.current!.availablePackages;

                    if (packages.isEmpty) {
                      return const Text("No tip tiers available.");
                    }

                    return Column(
                      children: packages.map((package) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                foregroundColor: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await Purchases.purchase(
                                    PurchaseParams.package(package),
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Thank you so much for the support! 🚀",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } on PlatformException catch (e) {
                                  var errorCode =
                                      PurchasesErrorHelper.getErrorCode(e);
                                  if (errorCode !=
                                      PurchasesErrorCode
                                          .purchaseCancelledError) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Purchase failed: ${e.message}",
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    package.storeProduct.title
                                        .replaceAll('(TFTI)', '')
                                        .trim(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      package.storeProduct.priceString,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              "Log Out",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': FieldValue.delete()});
        } catch (e) {
          debugPrint("Failed to remove FCM token on logout: $e");
        }
      }

      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This action is permanent. All your data, friends, and event history will be wiped. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // --- NEW: PRE-EMPTIVE SESSION CHECK ---
    // Prevents "Zombie Accounts" by ensuring the session is fresh BEFORE wiping data.
    try {
      final idTokenResult = await user.getIdTokenResult();
      final authTime = idTokenResult.authTime;
      if (authTime != null) {
        final diff = DateTime.now().difference(authTime);
        if (diff.inMinutes > 5) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Session Expired"),
                content: const Text(
                  "For your security, Firebase requires a recent login to delete an account. Please log out, log back in, and try again.",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _logout();
                    },
                    child: const Text("Log Out Now"),
                  ),
                ],
              ),
            );
          }
          return; // HALT: Do not touch the database!
        }
      }
    } catch (e) {
      debugPrint("Error checking token age: $e");
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Delete avatar from Storage
      try {
        final Reference ref = FirebaseStorage.instance.ref().child(
          'profile_images/${user.uid}/avatar.jpg',
        );
        await ref.delete();
        debugPrint("✅ Profile image deleted from Storage.");
      } catch (e) {
        debugPrint("Notice: No profile image found to delete: $e");
      }

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await userDocRef.get();
      final String? usernameToFree = userDoc.data()?['username'];

      // 2. Clear subcollections (Friends, Circles, Places)
      try {
        final friendsSnap = await userDocRef.collection('friends').get();
        for (var doc in friendsSnap.docs) {
          await doc.reference.delete();
          debugPrint("✅ Friends subcollection cleaned up.");
        }
      } catch (e) {
        debugPrint("Cleanup Error (friends): $e");
      }

      try {
        final circlesSnap = await userDocRef.collection('circles').get();
        for (var doc in circlesSnap.docs) {
          await doc.reference.delete();
          debugPrint("✅ Circles subcollection cleaned up.");
        }
      } catch (e) {
        debugPrint("Cleanup Error (circles): $e");
      }

      try {
        final placesSnap = await userDocRef.collection('favorite_places').get();
        for (var doc in placesSnap.docs) {
          await doc.reference.delete();
          debugPrint("✅ Favorite places subcollection cleaned up.");
        }
      } catch (e) {
        debugPrint("Cleanup Error (places): $e");
      }

      // 3. Free up the username in the registry
      try {
        if (usernameToFree != null && usernameToFree.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usernames')
              .doc(usernameToFree)
              .delete();
        }
        debugPrint("✅ Username freed up.");
      } catch (e) {
        debugPrint("Cleanup Error (username): $e");
      }

      // --- THE NO-INDEX BYPASS FOR SQUAD NEEDS ---
      List<String> userEventIds = [];

      // 4. Delete global invites AND collect the Event IDs
      try {
        final invitesSnap = await FirebaseFirestore.instance
            .collectionGroup('invitations')
            .where('uid', isEqualTo: user.uid)
            .get();

        for (var doc in invitesSnap.docs) {
          final parentEventId = doc.reference.parent.parent?.id;
          if (parentEventId != null && !userEventIds.contains(parentEventId)) {
            userEventIds.add(parentEventId);
          }
          await doc.reference.delete();
          debugPrint("✅ Global invite deleted.");
        }
      } catch (e) {
        debugPrint("Cleanup Error (global invites): $e");
      }

      // 5. Also grab any events they hosted directly
      try {
        final hostedEventsSnap = await FirebaseFirestore.instance
            .collection('events')
            .where('hostId', isEqualTo: user.uid)
            .get();
        for (var doc in hostedEventsSnap.docs) {
          if (!userEventIds.contains(doc.id)) userEventIds.add(doc.id);
        }
      } catch (e) {
        debugPrint("Cleanup Error (fetching hosted events): $e");
      }

      // 6. Un-claim Squad Needs (Roles) using collected Event IDs (NO INDEX REQUIRED!)
      try {
        for (String eventId in userEventIds) {
          final rolesSnap = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('roles')
              .where('claimedByUid', isEqualTo: user.uid)
              .get();

          for (var doc in rolesSnap.docs) {
            await doc.reference.update({
              'claimedByUid': FieldValue.delete(),
              'claimedByName': FieldValue.delete(),
            });
            debugPrint("✅ Released Squad Need: ${doc.id}");
          }
        }
      } catch (e) {
        debugPrint("Cleanup Error (roles): $e");
      }

      // 7. Delete from everyone's friends list
      try {
        final friendsGlobalSnap = await FirebaseFirestore.instance
            .collectionGroup('friends')
            .where('uid', isEqualTo: user.uid)
            .get();
        for (var doc in friendsGlobalSnap.docs) {
          await doc.reference.delete();
          debugPrint("✅ Removed from a friend's list: ${doc.id}");
        }
      } catch (e) {
        debugPrint("Cleanup Error (global friends): $e");
      }

      // 8. Delete User Doc
      try {
        await userDocRef.delete();
        debugPrint("✅ User document deleted.");
      } catch (e) {
        debugPrint("Cleanup Error (user doc): $e");
      }

      // 9. Delete Firebase Auth Account
      await user.delete();
      debugPrint("✅ Firebase Auth account deleted.");
    } catch (e) {
      debugPrint("❌ Fatal Account Deletion Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMyQrCode() {
    if (_currentUsername == null || _currentUsername!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please set a username first to generate a QR code!"),
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // We use a custom scheme that will also work for Deep Linking later!
    final qrData = "tfti://add/@$_currentUsername";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(height: 32),

                  // Avatar at the top
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(
                            _selectedColorValue,
                          ).withValues(alpha: 0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(_selectedColorValue),
                      backgroundImage: _avatarUrl != null
                          ? CachedNetworkImageProvider(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null
                          ? Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : "Me",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    "@$_currentUsername",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // The QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 220.0,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: primaryColor,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: isDark ? Colors.grey.shade900 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Have your friend scan this to squad up!",
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- UPDATED PROFILE IDENTITY UI ---
  Widget _buildTcgPreviewCard(bool isDark, Color primaryColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              "Public Profile Preview",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TcgProfileCard(
          displayName: _nameController.text.trim().isNotEmpty
              ? _nameController.text
              : "No Name",
          username: _currentUsername ?? "",
          statusText: _statusController.text.trim(),
          hp: _hp,
          mana: _mana,
          originDate: _originDate,
          showPhone: _showPhoneNumber,
          displayPhone: _showPhoneNumber && _phoneNumber.isNotEmpty
              ? _phoneNumber
              : "Hidden",
          avatarUrl: _avatarUrl,
          avatarColor: Color(_selectedColorValue),
          isGoated: false, // You can't goat yourself!
          onAvatarTap:
              _showAvatarOptions, // Automatically triggers the camera overlay!
          isUploadingAvatar: _isUploadingAvatar,
        ),
      ],
    );
  }

  Widget _buildEditControls(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Edit Profile",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 24),

          // DISPLAY NAME
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: "Display Name",
              labelStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(Icons.person, color: primaryColor),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              counterText: "",
            ),
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              _autoSaveIdentity();
            },
            onEditingComplete: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _autoSaveIdentity();
            },
          ),
          const SizedBox(height: 16),

          // MOOD / STATUS
          TextField(
            controller: _statusController,
            textInputAction: TextInputAction.done,
            maxLength: 35,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: "I'm feeling like...",
              labelStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(Symbols.mood, color: primaryColor),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              counterText: "",
            ),
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              _autoSaveIdentity();
            },
            onEditingComplete: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _autoSaveIdentity();
            },
          ),
          const SizedBox(height: 16),

          // PHONE NUMBER & PRIVACY TOGGLE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_android, size: 20, color: primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _phoneNumber.isNotEmpty
                            ? _phoneNumber
                            : "No phone number",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Show to Squad",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _showPhoneNumber,
                  activeThumbColor: primaryColor,
                  onChanged: (val) {
                    setState(() => _showPhoneNumber = val);
                    _autoSaveIdentity();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // SIGNATURE COLOR
          Text(
            "Signature Color",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: _colors.map((color) {
              final isSelected = _selectedColorValue == color.toARGB32();
              final isWhite = color == Colors.white;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedColorValue = color.toARGB32());
                  _autoSaveIdentity();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 48 : 42,
                  height: isSelected ? 48 : 42,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (isWhite && !isDark
                                ? Colors.grey.shade400
                                : Colors.white)
                          : (isWhite && !isDark
                                ? Colors.grey.shade300
                                : Colors.transparent),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: isWhite ? Colors.grey.shade800 : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.settings),
            ),
            title: const Text(
              "Preferences",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Notifications & Appearance"),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreferencesPage(),
                ),
              );
            },
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            indent: 60,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined, color: Colors.blue),
            ),
            title: const Text(
              "Terms of Service",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () => _launchLegalUrl("https://tftiapp.com/terms"),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            indent: 60,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.privacy_tip_outlined, color: Colors.teal),
            ),
            title: const Text(
              "Privacy Policy",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () => _launchLegalUrl("https://tftiapp.com/privacy"),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            indent: 60,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.coffee, color: Colors.amber),
            ),
            title: const Text(
              "Support the Developer",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Help keep the servers running"),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: _showTipJar,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text(
              "Log Out",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            onTap: _logout,
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final qrAction = Padding(
      padding: EdgeInsets.only(right: isLandscape ? 4.0 : 16.0),
      child: Center(
        child: InkWell(
          onTap: _showMyQrCode,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code, color: primaryColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  "QR",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isLandscape) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 50,
              child: CustomScrollView(
                slivers: [
                  SharedSliverAppBar(
                    title: "Account",
                    collapsedTitle: "Account",
                    expandedHeight: 56.0,
                    hasBackButton: ModalRoute.of(context)?.canPop ?? false,
                    actions: [qrAction],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildTcgPreviewCard(isDark, primaryColor),
                          const SizedBox(height: 24),
                          _buildEditControls(isDark, primaryColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
            Expanded(
              flex: 50,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildSettingsCard(isDark),
                    const SizedBox(height: 24),
                    _buildDangerCard(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SharedSliverAppBar(
            title: "Account",
            collapsedTitle: "Account",
            expandedHeight: 140.0,
            hasBackButton: ModalRoute.of(context)?.canPop ?? false,
            actions: [qrAction],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildTcgPreviewCard(isDark, primaryColor),
                  const SizedBox(height: 24),
                  _buildEditControls(isDark, primaryColor),
                  const SizedBox(height: 24),
                  _buildSettingsCard(isDark),
                  const SizedBox(height: 24),
                  _buildDangerCard(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
