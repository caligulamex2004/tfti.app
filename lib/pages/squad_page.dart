import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/shared/user_profile_sheet.dart';
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
      if (mounted) setState(() => _statusMessage = "");
    });
  }

  // --- QR SCANNER LOGIC ---
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
        if (!mounted) return;
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

      if (!mounted) return;
      Navigator.pop(context);
      _showStagingSheet(onTfti, notOnTfti, myUid);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error fetching contacts: $e");
    }
  }

  void _showStagingSheet(
    List<Map<String, dynamic>> onTfti,
    List<Contact> notOnTfti,
    String myUid,
  ) {
    List<dynamic> listItems = [];
    if (onTfti.isNotEmpty) {
      listItems.add("HEADER_TFTI");
      listItems.addAll(onTfti);
    }
    if (notOnTfti.isNotEmpty) {
      listItems.add("HEADER_INVITE");
      listItems.addAll(notOnTfti);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Set<String> addedUids = {};
        Set<String> invitedPhones = {};

        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
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
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "Import Contacts",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    if (listItems.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.contact_phone_outlined,
                                size: 64,
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No new contacts found.",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: listItems.length,
                          itemBuilder: (context, index) {
                            final item = listItems[index];

                            if (item == "HEADER_TFTI") {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  24,
                                  20,
                                  12,
                                ),
                                child: Text(
                                  "Ready to squad up!",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              );
                            }
                            if (item == "HEADER_INVITE") {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  24,
                                  20,
                                  12,
                                ),
                                child: Text(
                                  "Invite to squad via SMS",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              );
                            }

                            if (item is Map<String, dynamic>) {
                              final uid = item['uid'];
                              final name = item['displayName'] ?? "Unknown";
                              final phone = PhoneFormatter.beautify(
                                item['phoneNumber'] ?? "",
                              );
                              final avatarUrl = item['avatarUrl'];
                              final avatarColor =
                                  item['avatarColor'] ?? Colors.blue.toARGB32();
                              final isAdded = addedUids.contains(uid);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 6,
                                ),
                                leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          avatarColor,
                                        ).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: Color(avatarColor),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  phone,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: isAdded
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 32,
                                      )
                                    : ElevatedButton(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(myUid)
                                              .collection('friends')
                                              .doc(uid)
                                              .set({
                                                'uid': uid,
                                                'phoneNumber':
                                                    item['phoneNumber'],
                                                'addedAt':
                                                    FieldValue.serverTimestamp(),
                                              }, SetOptions(merge: true));
                                          setStateSheet(
                                            () => addedUids.add(uid),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor
                                              .withValues(alpha: 0.1),
                                          foregroundColor: primaryColor,
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          "Add",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              );
                            }

                            if (item is Contact) {
                              final name = item.displayName;
                              final rawPhone = item.phones.first.number;
                              final normPhone =
                                  ContactHelper.normalizePhone(rawPhone) ??
                                  rawPhone;
                              final isInvited = invitedPhones.contains(
                                normPhone,
                              );

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  PhoneFormatter.beautify(normPhone),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: isInvited
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 32,
                                      )
                                    : OutlinedButton(
                                        onPressed: () {
                                          _inviteViaSms(normPhone);
                                          setStateSheet(
                                            () => invitedPhones.add(normPhone),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.grey.shade700
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          "Invite",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
      if (input.startsWith('@')) input = input.substring(1);
      if (input.isEmpty) return;

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
        _statusMessage = "Added @$input to the squad!";
        _usernameController.clear();
      });
      _clearStatusAfterDelay();
    } else {
      String phoneToAdd = _completePhoneNumber;
      if (phoneToAdd.isEmpty) return;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneToAdd)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _statusMessage = "User not found on tfti.app.");
        if (!mounted) return;

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
        _statusMessage = "Added ${PhoneFormatter.beautify(phoneToAdd)}!";
        _phoneController.clear();
        _completePhoneNumber = "";
      });
      _clearStatusAfterDelay();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndSortFriends(
    List<DocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> list = [];
    await Future.wait(
      docs.map((doc) async {
        final uid = doc.id;
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userSnap.exists) {
          final data = userSnap.data() as Map<String, dynamic>;
          data['uid'] = uid;
          data['isGoated'] =
              (doc.data() as Map<String, dynamic>? ?? {})['isGoated'] ?? false;
          list.add(data);
        }
      }),
    );

    if (_sortByScore) {
      list.sort((a, b) {
        final double scoreA = ((a['hp'] ?? 0) * 0.6) + ((a['mana'] ?? 0) * 0.4);
        final double scoreB = ((b['hp'] ?? 0) * 0.6) + ((b['mana'] ?? 0) * 0.4);
        int result = scoreB.compareTo(scoreA);
        if (result == 0) {
          return (a['displayName'] ?? '').toString().toLowerCase().compareTo(
            (b['displayName'] ?? '').toString().toLowerCase(),
          );
        }
        return result;
      });
    } else {
      list.sort(
        (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
          (b['displayName'] ?? '').toString().toLowerCase(),
        ),
      );
    }
    return list;
  }

  Widget _buildAddFriendSection(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.only(
        left: 20.0,
        top: 20.0,
        right: 20.0,
        bottom: 4.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Grow the Squad",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text(
                    "Username",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(
                    "Phone Number",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              selected: {_isAddingByUsername},
              onSelectionChanged: (newSelection) {
                HapticFeedback.selectionClick();
                setState(() => _isAddingByUsername = newSelection.first);
              },
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                selectedBackgroundColor: primaryColor.withValues(alpha: 0.15),
                selectedForegroundColor: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _isAddingByUsername
                    ? TextField(
                        controller: _usernameController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "username",
                          prefixText: "@ ",
                          prefixStyle: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        onSubmitted: (_) => _addFriend(),
                      )
                    : IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'US',
                        dropdownIconPosition: IconPosition.trailing,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "Phone Number",
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (phone) =>
                            _completePhoneNumber = phone.completeNumber,
                        onSubmitted: (_) => _addFriend(),
                      ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _addFriend(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: themeProvider.onPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    elevation: 2,
                  ),
                  child: const Text(
                    "Add",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 28,
            child: _statusMessage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color:
                            _statusMessage.contains("Added") ||
                                _statusMessage.contains("prepared")
                            ? (isDark ? Colors.greenAccent : Colors.green)
                            : (isDark ? Colors.redAccent : Colors.red),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFriendListSection(
    bool isDark,
    Color primaryColor,
    String myUid,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .snapshots(),
      builder: (context, myUserSnap) {
        List<String> blockedUids = [];
        if (myUserSnap.hasData && myUserSnap.data!.exists) {
          final data = myUserSnap.data!.data() as Map<String, dynamic>?;
          if (data != null && data['blockedUids'] != null) {
            blockedUids = List<String>.from(data['blockedUids']);
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(myUid)
              .collection('friends')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchAndSortFriends(snapshot.data!.docs),
              builder: (context, friendsSnap) {
                if (!friendsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter out optimistically removed friends immediately
                final List<Map<String, dynamic>> friends = friendsSnap.data!
                    .where(
                      (friend) => !_removedFriendUids.contains(friend['uid']),
                    )
                    .toList();

                if (friends.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 60,
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Your squad is empty.",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Squad List (${friends.length})",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _sortByScore = !_sortByScore);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _sortByScore
                                        ? Icons.leaderboard
                                        : Icons.sort_by_alpha,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _sortByScore ? "Ranked" : "A-Z",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final Map<String, dynamic> friendInitData =
                              friends[index];
                          final String uid = friendInitData['uid'] as String;
                          final bool isGoated =
                              friendInitData['isGoated'] == true;
                          final bool isBlocked = blockedUids.contains(uid);

                          Widget? rankIcon;
                          if (_sortByScore) {
                            if (index == 0) {
                              rankIcon = const Padding(
                                padding: EdgeInsets.only(right: 6.0),
                                child: Icon(
                                  Icons.workspace_premium,
                                  color: Colors.amber,
                                  size: 22,
                                ),
                              );
                            } else if (index == 1) {
                              rankIcon = Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Icon(
                                  Icons.workspace_premium,
                                  color: Colors.grey.shade400,
                                  size: 22,
                                ),
                              );
                            } else if (index == 2) {
                              rankIcon = const Padding(
                                padding: EdgeInsets.only(right: 6.0),
                                child: Icon(
                                  Icons.workspace_premium,
                                  color: Color(0xFFCD7F32),
                                  size: 22,
                                ),
                              );
                            }
                          }

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .snapshots(),
                            builder: (context, userSnap) {
                              Map<String, dynamic> userData = Map.from(
                                friendInitData,
                              );
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final snapData =
                                    userSnap.data!.data()
                                        as Map<String, dynamic>?;
                                if (snapData != null) userData.addAll(snapData);
                              }

                              final String displayName =
                                  userData['displayName'] ?? "No Name";
                              final String username =
                                  userData['username'] ?? "";
                              final String? avatarUrl = userData['avatarUrl'];
                              final Color avatarColor =
                                  userData['avatarColor'] is int
                                  ? Color(userData['avatarColor'])
                                  : Colors.blue.shade100;
                              final int hp = userData['hp'] ?? 0;
                              final int mana = userData['mana'] ?? 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Dismissible(
                                  key: ValueKey(uid),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_remove,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Remove",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    HapticFeedback.mediumImpact();
                                    return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Remove Squad Mate?"),
                                        content: Text(
                                          "Are you sure you want to remove $displayName from your squad?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            child: const Text(
                                              "Remove",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) {
                                    // Instantly hide the friend from the UI locally
                                    setState(() {
                                      _removedFriendUids.add(uid);
                                    });

                                    // Capture the ScaffoldMessenger before the async gap
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );

                                    // Run the database delete in the background
                                    FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(myUid)
                                        .collection('friends')
                                        .doc(uid)
                                        .delete()
                                        .then((_) {
                                          // Safely use the captured messenger without needing context
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "$displayName was removed from your squad.",
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        })
                                        .catchError((e) {
                                          debugPrint(
                                            "Error removing friend: $e",
                                          );
                                          // Optional fallback: put them back if it fails
                                          if (mounted) {
                                            setState(() {
                                              _removedFriendUids.remove(uid);
                                            });
                                          }
                                        });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade200,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        if (!isDark)
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(24),
                                                  ),
                                            ),
                                            builder: (ctx) => UserProfileSheet(
                                              userData: userData,
                                              currentUserId: myUid,
                                              isGoated: isGoated,
                                              isBlocked: isBlocked,
                                              onToggleGoated:
                                                  (currentGoated) async {
                                                    Navigator.pop(ctx);
                                                    HapticFeedback.mediumImpact();
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(myUid)
                                                        .collection('friends')
                                                        .doc(uid)
                                                        .set(
                                                          {
                                                            'isGoated':
                                                                !currentGoated,
                                                          },
                                                          SetOptions(
                                                            merge: true,
                                                          ),
                                                        );
                                                  },
                                              onToggleBlocked: (currentBlocked) async {
                                                Navigator.pop(ctx);
                                                HapticFeedback.heavyImpact();
                                                if (currentBlocked) {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(myUid)
                                                      .update({
                                                        'blockedUids':
                                                            FieldValue.arrayRemove(
                                                              [uid],
                                                            ),
                                                      });
                                                } else {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(myUid)
                                                      .update({
                                                        'blockedUids':
                                                            FieldValue.arrayUnion(
                                                              [uid],
                                                            ),
                                                      });
                                                }
                                              },
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: avatarColor
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                      blurRadius: 12,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: CircleAvatar(
                                                  radius: 26,
                                                  backgroundColor: avatarColor,
                                                  backgroundImage:
                                                      avatarUrl != null
                                                      ? CachedNetworkImageProvider(
                                                          avatarUrl,
                                                        )
                                                      : null,
                                                  child: avatarUrl == null
                                                      ? Text(
                                                          displayName.isNotEmpty
                                                              ? displayName[0]
                                                                    .toUpperCase()
                                                              : "?",
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 20,
                                                              ),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        ?rankIcon,
                                                        Flexible(
                                                          child: Text(
                                                            displayName,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize: 17,
                                                              letterSpacing:
                                                                  -0.3,
                                                              color: isBlocked
                                                                  ? Colors.grey
                                                                  : (isDark
                                                                        ? Colors
                                                                              .white
                                                                        : Colors
                                                                              .black87),
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (isGoated &&
                                                            !isBlocked)
                                                          const Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                  left: 6.0,
                                                                ),
                                                            child: Icon(
                                                              Symbols.star,
                                                              fill: 1.0,
                                                              color:
                                                                  Colors.amber,
                                                              size: 18,
                                                            ),
                                                          ),
                                                        if (isBlocked)
                                                          const Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                  left: 6.0,
                                                                ),
                                                            child: Icon(
                                                              Icons.block,
                                                              color: Colors.red,
                                                              size: 16,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    if (username.isNotEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 4.0,
                                                            ),
                                                        child: Text(
                                                          "@$username",
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isBlocked
                                                                ? Colors.grey
                                                                : primaryColor,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              _sortByScore
                                                  ? Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              '$hp',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                                color: isDark
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .black87,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            const Icon(
                                                              Icons.whatshot,
                                                              color: Colors
                                                                  .redAccent,
                                                              size: 14,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              '$mana',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                                color: isDark
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .black87,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            const Icon(
                                                              Icons.water_drop,
                                                              color: Colors
                                                                  .blueAccent,
                                                              size: 14,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    )
                                                  : Icon(
                                                      Icons.chevron_right,
                                                      color: isDark
                                                          ? Colors.grey.shade700
                                                          : Colors
                                                                .grey
                                                                .shade300,
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
                    child: _buildAddFriendSection(isDark, primaryColor),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                Expanded(
                  flex: 60,
                  child: _buildFriendListSection(isDark, primaryColor, myUid),
                ),
              ],
            )
          : Column(
              children: [
                _buildAddFriendSection(isDark, primaryColor),
                Expanded(
                  child: _buildFriendListSection(isDark, primaryColor, myUid),
                ),
              ],
            ),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scan to Add",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (BarcodeCapture capture) {
              if (_hasScanned) return;
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  _hasScanned = true;
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    spreadRadius: 50,
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Text(
              "Center the QR code in the box",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
