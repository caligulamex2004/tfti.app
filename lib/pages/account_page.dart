import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../components/account/account_danger_card.dart';
import '../components/account/account_edit_card.dart';
import '../components/account/account_settings_card.dart';
import '../components/account/qr_code_sheet.dart';
import '../components/account/tip_jar_sheet.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import '../components/shared/tcg_profile_card.dart';
import '../pages/preferences_page.dart';
import '../services/user_service.dart';
import '../utils/phone_formatter.dart';

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
    setState(() {}); // Triggers live preview rebuild
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

    if (user.metadata.creationTime != null) {
      final dt = user.metadata.creationTime!;
      final List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      _originDate = "${months[dt.month - 1]} ${dt.year}";
    }

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) return;
          final data = doc.data() as Map<String, dynamic>;

          if (mounted) {
            setState(() {
              if (data.containsKey('username')) {
                _currentUsername = data['username'];
              }
              if (data.containsKey('hp')) _hp = data['hp'];
              if (data.containsKey('mana')) _mana = data['mana'];
              if (data.containsKey('avatarUrl')) _avatarUrl = data['avatarUrl'];
              if (data.containsKey('avatarColor')) {
                _selectedColorValue = data['avatarColor'];
              }

              if (data.containsKey('createdAt') && data['createdAt'] != null) {
                final Timestamp ts = data['createdAt'];
                final dt = ts.toDate();
                final List<String> months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                ];
                _originDate = "${months[dt.month - 1]} ${dt.year}";
              }

              if (data.containsKey('phoneNumber')) {
                _phoneNumber = PhoneFormatter.beautify(
                  data['phoneNumber'] ?? '',
                );
              } else if (data.containsKey('phone')) {
                _phoneNumber = PhoneFormatter.beautify(data['phone'] ?? '');
              }

              if (!_hasLoadedInitialData) {
                _nameController.text = data['displayName'] ?? '';
                _statusController.text = data['status'] ?? '';
                _showPhoneNumber = (data['isPhonePublic'] ?? data['showPhoneNumber']) ?? false;
                _hasLoadedInitialData = true;
              }
            });
          }
        });
  }

  Future<void> _autoSaveIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String name = _nameController.text.trim();
    final String status = _statusController.text.trim();

    try {
      await UserService.updateProfile(
        uid: user.uid,
        displayName: name,
        status: status,
        avatarColor: _selectedColorValue,
        isPhonePublic: _showPhoneNumber,
        isSearchableByPhone: _showPhoneNumber,
      );
    } catch (e) {
      debugPrint("Error auto-saving identity: $e");
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

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Photo',
          toolbarColor: primaryColor,
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

    if (croppedFile == null) return;

    if (!mounted) return;
    setState(() => _isUploadingAvatar = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isUploadingAvatar = false);
      return;
    }

    try {
      final downloadUrl = await UserService.uploadAvatar(
        uid: user.uid,
        imageFile: File(croppedFile.path),
      );
      if (mounted) {
        setState(() => _avatarUrl = downloadUrl);
      }
    } catch (e) {
      debugPrint("Error uploading avatar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload photo")),
        );
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
      await UserService.deleteAvatar(uid: user.uid);
      if (mounted) {
        setState(() => _avatarUrl = null);
      }
    } catch (e) {
      debugPrint("Error removing avatar: $e");
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showMyQrCode() {
    QrCodeSheet.show(
      context,
      username: _currentUsername ?? '',
      displayName: _nameController.text.isNotEmpty ? _nameController.text : 'Me',
      avatarUrl: _avatarUrl,
      avatarColor: _selectedColorValue,
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

    // Check token age for re-authentication
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
          return;
        }
      }
    } catch (e) {
      debugPrint("Error checking token age: $e");
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await UserService.deleteAccount(user);
    } catch (e) {
      debugPrint("Fatal Account Deletion Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting account: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          isGoated: false,
          onAvatarTap: _showAvatarOptions,
          isUploadingAvatar: _isUploadingAvatar,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          AccountEditCard(
                            nameController: _nameController,
                            statusController: _statusController,
                            phoneNumber: _phoneNumber,
                            showPhoneNumber: _showPhoneNumber,
                            onShowPhoneChanged: (val) {
                              setState(() => _showPhoneNumber = val);
                            },
                            selectedColorValue: _selectedColorValue,
                            colors: _colors,
                            onColorSelected: (col) {
                              setState(() => _selectedColorValue = col.toARGB32());
                            },
                            onSave: _autoSaveIdentity,
                          ),
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
                    AccountSettingsCard(
                      onPreferencesTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PreferencesPage(),
                          ),
                        );
                      },
                      onTipJarTap: () => TipJarSheet.show(context),
                    ),
                    const SizedBox(height: 24),
                    AccountDangerCard(
                      onLogout: _logout,
                      onDeleteAccount: _deleteAccount,
                    ),
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
                  AccountEditCard(
                    nameController: _nameController,
                    statusController: _statusController,
                    phoneNumber: _phoneNumber,
                    showPhoneNumber: _showPhoneNumber,
                    onShowPhoneChanged: (val) {
                      setState(() => _showPhoneNumber = val);
                    },
                    selectedColorValue: _selectedColorValue,
                    colors: _colors,
                    onColorSelected: (col) {
                      setState(() => _selectedColorValue = col.toARGB32());
                    },
                    onSave: _autoSaveIdentity,
                  ),
                  const SizedBox(height: 24),
                  AccountSettingsCard(
                    onPreferencesTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PreferencesPage(),
                        ),
                      );
                    },
                    onTipJarTap: () => TipJarSheet.show(context),
                  ),
                  const SizedBox(height: 24),
                  AccountDangerCard(
                    onLogout: _logout,
                    onDeleteAccount: _deleteAccount,
                  ),
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
