import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// --- COMPONENTS & UTILITIES ---
import 'qr_scanner_page.dart';
import '../components/squad/add_friend_section.dart';
import '../components/squad/friend_list_feed.dart';
import '../components/squad/contact_import_sheet.dart';
import '../services/contact_service.dart';
import '../utils/phone_formatter.dart';
import '../utils/theme_provider.dart';

class SquadPage extends StatefulWidget {
  const SquadPage({super.key});

  @override
  State<SquadPage> createState() => _SquadPageState();
}

class _SquadPageState extends State<SquadPage> {
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isAddingByUsername = true;
  String _completePhoneNumber = "";
  String _statusMessage = "";
  bool _sortByScore = true;

  final Set<String> _removedFriendUids = {};

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _clearStatusAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _statusMessage = "");
      }
    });
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );
    if (result != null && result is String && mounted) {
      if (result.startsWith('tfti://add/@')) {
        final scannedUsername = result.replaceFirst('tfti://add/@', '');
        setState(() {
          _isAddingByUsername = true;
          _usernameController.text = scannedUsername;
        });
        _addFriend(overrideUsername: scannedUsername);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid or unrecognized QR Code.")),
        );
      }
    }
  }

  Future<void> _importContacts() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final contacts = await ContactHelper.getContacts();
      if (contacts == null) {
        if (!mounted) {
          return;
        }
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permission denied for contacts.")),
        );
        return;
      }

      final myUid = FirebaseAuth.instance.currentUser!.uid;
      final friendsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .get(const GetOptions(source: Source.server));
      final myFriendUids = friendsSnap.docs.map((d) => d.id).toSet();

      List<String> allPhones = [];
      Map<String, Contact> phoneToContact = {};

      for (var c in contacts) {
        for (var p in c.phones) {
          final raw = p.number;
          final norm = ContactHelper.normalizePhone(raw);
          if (norm != null && !allPhones.contains(norm)) {
            allPhones.add(norm);
            phoneToContact[norm] = c;
          }
        }
      }

      List<Map<String, dynamic>> onTfti = [];
      List<Contact> notOnTfti = [];
      Set<String> allTftiPhones = {};

      if (allPhones.isNotEmpty) {
        for (int i = 0; i < allPhones.length; i += 30) {
          int end = (i + 30 < allPhones.length) ? i + 30 : allPhones.length;
          List<String> chunk = allPhones.sublist(i, end);

          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('phoneNumber', whereIn: chunk)
              .get(const GetOptions(source: Source.server));
          for (var doc in snap.docs) {
            final data = doc.data();
            final uid = doc.id;
            final phone = data['phoneNumber'] as String;
            allTftiPhones.add(phone);
            if (uid != myUid && !myFriendUids.contains(uid)) {
              data['uid'] = uid;
              onTfti.add(data);
            }
          }
        }
      }

      for (var phone in allPhones) {
        if (!allTftiPhones.contains(phone)) {
          notOnTfti.add(phoneToContact[phone]!);
        }
      }

      onTfti.sort(
        (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
          (b['displayName'] ?? '').toString().toLowerCase(),
        ),
      );
      notOnTfti.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      if (!mounted) {
        return;
      }
      Navigator.pop(context);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => ContactImportSheet(
          onTfti: onTfti,
          notOnTfti: notOnTfti,
          myUid: myUid,
          onInviteSms: _inviteViaSms,
          onFriendAdded: (uid) {
            setState(() {
              _removedFriendUids.remove(uid);
            });
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      debugPrint("Error fetching contacts: $e");
    }
  }

  Future<void> _inviteViaSms(String phone) async {
    const String kAppUrl = "https://tftiapp.com";
    final String message =
        "Hey! Join me on tfti.app so I can invite you to events! Check it out: $kAppUrl";
    final Uri smsLaunchUri = Uri.parse(
      'sms:$phone?body=${Uri.encodeComponent(message)}',
    );
    try {
      if (!await launchUrl(smsLaunchUri) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch SMS app.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Could not launch SMS.")));
      }
    }
  }

  Future<void> _addFriend({String? overrideUsername}) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isAddingByUsername || overrideUsername != null) {
      String input =
          overrideUsername ?? _usernameController.text.trim().toLowerCase();
      if (input.startsWith('@')) {
        input = input.substring(1);
      }
      if (input.isEmpty) {
        return;
      }

      final usernameDoc = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(input)
          .get();
      if (!usernameDoc.exists) {
        setState(() => _statusMessage = "Username @$input not found.");
        _clearStatusAfterDelay();
        return;
      }

      final targetUid = usernameDoc.data()?['uid'];
      if (targetUid == myUid) {
        setState(() => _statusMessage = "You can't add yourself!");
        _clearStatusAfterDelay();
        return;
      }

      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();
      final targetPhone = targetUserDoc.exists
          ? (targetUserDoc.data()?['phoneNumber'] ??
                targetUserDoc.data()?['phone'] ??
                '')
          : '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(targetUid)
          .set({
            'uid': targetUid,
            'phoneNumber': targetPhone,
            'addedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      setState(() {
        _removedFriendUids.remove(targetUid);
        _statusMessage = "Added @$input to the squad!";
        _usernameController.clear();
      });
      _clearStatusAfterDelay();
    } else {
      String phoneToAdd = _completePhoneNumber;
      if (phoneToAdd.isEmpty) {
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneToAdd)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _statusMessage = "User not found on tfti.app.");
        if (!mounted) {
          return;
        }

        final invite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Not on tfti.app Yet"),
            content: Text(
              "Would you like to invite ${PhoneFormatter.beautify(phoneToAdd)} to join tfti.app via SMS?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Send Invite",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (invite == true && mounted) {
          await _inviteViaSms(phoneToAdd);
          setState(() {
            _statusMessage = "Invite text prepared!";
            _phoneController.clear();
            _completePhoneNumber = "";
          });
          _clearStatusAfterDelay();
        }
        return;
      }

      final friendUid = query.docs.first.id;
      if (friendUid == myUid) {
        setState(() => _statusMessage = "You can't add yourself!");
        _clearStatusAfterDelay();
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(friendUid)
          .set({
            'uid': friendUid,
            'phoneNumber': query.docs.first.data()['phoneNumber'] ?? phoneToAdd,
            'addedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      setState(() {
        _removedFriendUids.remove(friendUid);
        _statusMessage = "Added ${PhoneFormatter.beautify(phoneToAdd)}!";
        _phoneController.clear();
        _completePhoneNumber = "";
      });
      _clearStatusAfterDelay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "The Squad",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Scan QR",
            onPressed: _openScanner,
          ),
          IconButton(
            icon: const Icon(Icons.import_contacts),
            tooltip: "Import Contacts",
            onPressed: _importContacts,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 40,
                  child: SingleChildScrollView(
                    child: AddFriendSection(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      isAddingByUsername: _isAddingByUsername,
                      usernameController: _usernameController,
                      phoneController: _phoneController,
                      statusMessage: _statusMessage,
                      onToggleInputType: (val) =>
                          setState(() => _isAddingByUsername = val),
                      onPhoneChanged: (val) => _completePhoneNumber = val,
                      onSubmit: _addFriend,
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                Expanded(
                  flex: 60,
                  child: FriendListFeed(
                    myUid: myUid,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    sortByScore: _sortByScore,
                    removedFriendUids: _removedFriendUids,
                    onToggleSort: () {
                      HapticFeedback.lightImpact();
                      setState(() => _sortByScore = !_sortByScore);
                    },
                    onFriendRemoved: (uid) {
                      setState(() => _removedFriendUids.add(uid));
                    },
                  ),
                ),
              ],
            )
          : Column(
              children: [
                AddFriendSection(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  isAddingByUsername: _isAddingByUsername,
                  usernameController: _usernameController,
                  phoneController: _phoneController,
                  statusMessage: _statusMessage,
                  onToggleInputType: (val) =>
                      setState(() => _isAddingByUsername = val),
                  onPhoneChanged: (val) => _completePhoneNumber = val,
                  onSubmit: _addFriend,
                ),
                Expanded(
                  child: FriendListFeed(
                    myUid: myUid,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    sortByScore: _sortByScore,
                    removedFriendUids: _removedFriendUids,
                    onToggleSort: () {
                      HapticFeedback.lightImpact();
                      setState(() => _sortByScore = !_sortByScore);
                    },
                    onFriendRemoved: (uid) {
                      setState(() => _removedFriendUids.add(uid));
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
