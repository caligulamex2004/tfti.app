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

import 'phone_formatter.dart';
import 'settings_page.dart';
import 'theme_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  final _usernameController = TextEditingController(); // NEW: Username

  String _phoneNumber = '';
  String? _currentUsername; // Tracks the currently saved username

  String _usernameFeedback = '';
  Color _usernameFeedbackColor = Colors.grey;
  bool _isCheckingUsername = false;

  int _selectedColorValue = Colors.blue.toARGB32();
  bool _isLoading = false;
  bool _showPhoneNumber = false;

  String? _avatarUrl;
  bool _isUploadingAvatar = false;

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
    _listenToUserData();
  }

  @override
  void dispose() {
    _autoSaveIdentity();
    _userSub?.cancel();
    _nameController.dispose();
    _statusController.dispose();
    _usernameController.dispose(); // Dispose new controller
    super.dispose();
  }

  void _listenToUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';

      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (doc) {
              if (doc.exists && doc.data() != null && mounted) {
                final data = doc.data()!;

                setState(() {
                  if (!_hasLoadedInitialData) {
                    if (data.containsKey('displayName')) {
                      _nameController.text = data['displayName'] ?? '';
                    }
                    if (data.containsKey('statusText')) {
                      _statusController.text = data['statusText'] ?? '';
                    }
                    if (data.containsKey('username')) {
                      _currentUsername = data['username'];
                      _usernameController.text = _currentUsername ?? '';
                    }
                    _hasLoadedInitialData = true;
                  }

                  if (data.containsKey('phoneNumber')) {
                    _phoneNumber = PhoneFormatter.beautify(
                      data['phoneNumber'] ?? '',
                    );
                  } else if (data.containsKey('phone')) {
                    _phoneNumber = PhoneFormatter.beautify(data['phone'] ?? '');
                  } else {
                    _phoneNumber = PhoneFormatter.beautify(
                      user.phoneNumber ?? '',
                    );
                  }

                  if (data.containsKey('avatarColor')) {
                    _selectedColorValue = data['avatarColor'];
                  }

                  if (data.containsKey('avatarUrl')) {
                    _avatarUrl = data['avatarUrl'];
                  } else {
                    _avatarUrl = null;
                  }

                  if (data.containsKey('showPhoneNumber')) {
                    _showPhoneNumber = data['showPhoneNumber'] ?? false;
                  }
                });
              }
            },
            onError: (e) {
              debugPrint("Notice: Could not load user profile data: $e");
            },
          );
    }
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

  // --- NEW: Username Transaction Logic ---
  Future<void> _updateUsername() async {
    final desiredName = _usernameController.text.trim().toLowerCase();
    if (desiredName == _currentUsername) {
      setState(() => _usernameFeedback = ''); // No change made
      return;
    }

    String cleanName = desiredName;
    if (cleanName.startsWith('@')) {
      cleanName = cleanName.substring(1);
    }

    // 1. EMPTY CHECK WITH AUTO-REVERT
    if (cleanName.isEmpty) {
      setState(() {
        _usernameFeedback = "Username cannot be empty.";
        _usernameFeedbackColor = Colors.red;
        _usernameController.text =
            _currentUsername ?? ''; // Snap back to safe name
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _usernameFeedback = '');
      });
      return;
    }

    // 2. REGEX CHECK WITH AUTO-REVERT
    final regex = RegExp(r'^[a-z0-9.\-_]{3,20}$');
    if (!regex.hasMatch(cleanName)) {
      setState(() {
        _usernameFeedback =
            "3-20 chars: letters, numbers, periods, dashes, or underscores.";
        _usernameFeedbackColor = Colors.red;
        _usernameController.text =
            _currentUsername ?? ''; // Snap back to safe name
      });

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _usernameFeedback = '');
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = "Checking availability...";
      _usernameFeedbackColor = Colors.orange;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final newNameRef = FirebaseFirestore.instance
            .collection('usernames')
            .doc(cleanName);
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        // Read desired username
        final newNameDoc = await transaction.get(newNameRef);
        if (newNameDoc.exists) {
          throw Exception("Username is already taken.");
        }

        // Claim new username
        transaction.set(newNameRef, {'uid': user.uid});
        // Update profile
        transaction.update(userRef, {'username': cleanName});

        // Release old username if they had one
        if (_currentUsername != null && _currentUsername!.isNotEmpty) {
          final oldNameRef = FirebaseFirestore.instance
              .collection('usernames')
              .doc(_currentUsername);
          transaction.delete(oldNameRef);
        }
      });

      setState(() {
        _currentUsername = cleanName;
        _usernameController.text =
            cleanName; // Cleans up the @ if they typed it
        _usernameFeedback = "Username updated!";
        _usernameFeedbackColor = Colors.green;
      });

      // Clear success message after a few seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _usernameFeedback = '');
      });
    } catch (e) {
      setState(() {
        _usernameFeedback = e.toString().replaceAll("Exception: ", "");
        _usernameFeedbackColor = Colors.red;
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingUsername = false);
      }
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() => _isUploadingAvatar = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final File file = File(pickedFile.path);
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
                                        color: themeProvider.onPrimaryColor,
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
        debugPrint("Notice: No profile image found to delete, or error: $e");
      }

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      // 2. Fetch current username before wiping user doc
      final userDoc = await userDocRef.get();
      final String? usernameToFree = userDoc.data()?['username'];

      // 3. Clear subcollections
      final friendsSnap = await userDocRef.collection('friends').get();
      for (var doc in friendsSnap.docs) {
        await doc.reference.delete();
      }

      final circlesSnap = await userDocRef.collection('circles').get();
      for (var doc in circlesSnap.docs) {
        await doc.reference.delete();
      }

      final placesSnap = await userDocRef.collection('favorite_places').get();
      for (var doc in placesSnap.docs) {
        await doc.reference.delete();
      }

      // 4. Free up the username in the registry
      if (usernameToFree != null && usernameToFree.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(usernameToFree)
            .delete();
      }

      // 5. Delete User Doc & Firebase Auth Account
      await userDocRef.delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Security: Please Log Out and Log In again to delete account.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UPDATED PROFILE IDENTITY UI ---
  Widget _buildProfileIdentityCard(bool isDark, Color primaryColor) {
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
        children: [
          // 1. AVATAR
          GestureDetector(
            onTap: _showAvatarOptions,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(
                          _selectedColorValue,
                        ).withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Color(_selectedColorValue),
                    backgroundImage: _avatarUrl != null
                        ? CachedNetworkImageProvider(_avatarUrl!)
                        : null,
                    child: _isUploadingAvatar
                        ? const CircularProgressIndicator(color: Colors.white)
                        : (_avatarUrl == null
                              ? Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text[0].toUpperCase()
                                      : "?",
                                  style: TextStyle(
                                    fontSize: 44,
                                    color:
                                        _selectedColorValue ==
                                            Colors.white.toARGB32()
                                        ? Colors.grey.shade800
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: themeProvider.onPrimaryColor,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 2. DISPLAY NAME
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

          // 3. USERNAME
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                maxLength: 20,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: "Username",
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  prefixIcon: Icon(Icons.alternate_email, color: primaryColor),
                  suffixIcon: _isCheckingUsername
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey.shade900
                      : Colors.grey.shade50,
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
                  _updateUsername();
                },
                onEditingComplete: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _updateUsername();
                },
              ),
              if (_usernameFeedback.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 16),
                  child: Text(
                    _usernameFeedback,
                    style: TextStyle(
                      color: _usernameFeedbackColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. MOOD / STATUS
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

          // 5. PHONE NUMBER & PRIVACY TOGGLE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_iphone, size: 20, color: primaryColor),
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

          // 6. SIGNATURE COLOR
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Signature Color",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
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
                MaterialPageRoute(builder: (context) => const SettingsPage()),
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Account",
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
          : isLandscape
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 50,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildProfileIdentityCard(isDark, primaryColor),
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
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildProfileIdentityCard(isDark, primaryColor),
                  const SizedBox(height: 24),
                  _buildSettingsCard(isDark),
                  const SizedBox(height: 24),
                  _buildDangerCard(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
