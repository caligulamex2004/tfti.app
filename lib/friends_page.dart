import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'contact_service.dart';
import 'theme_provider.dart';
import 'phone_formatter.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isAddingByUsername = true;
  String _completePhoneNumber = "";
  String _statusMessage = "";
  bool _sortByScore = true;

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

        // Instantly trigger the add logic!
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
    final String encodedMessage = Uri.encodeComponent(message);
    final Uri smsLaunchUri = Uri.parse('sms:$phone?body=$encodedMessage');

    try {
      if (!await launchUrl(smsLaunchUri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch SMS app.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Could not launch SMS.")));
      }
    }
  }

  // --- UPDATED: Accepts overrideUsername from the Scanner ---
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
        final primaryColor = Theme.of(context).colorScheme.primary;

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
                style: TextButton.styleFrom(foregroundColor: primaryColor),
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

      final friendDoc = query.docs.first;
      final friendUid = friendDoc.id;

      if (friendUid == myUid) {
        setState(() => _statusMessage = "You can't add yourself!");
        _clearStatusAfterDelay();
        return;
      }

      final friendData = friendDoc.data();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(friendUid)
          .set({
            'uid': friendUid,
            'phoneNumber': friendData['phoneNumber'] ?? phoneToAdd,
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

  // --- RPG LEADERBOARD SORTING ---
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
          final friendDocData = doc.data() as Map<String, dynamic>? ?? {};
          data['isGoated'] = friendDocData['isGoated'] ?? false;
          list.add(data);
        }
      }),
    );

    if (_sortByScore) {
      // Apply the RPG Weighted Algorithm: (hp * 0.6) + (mana * 0.4)
      list.sort((a, b) {
        final int hpA = a['hp'] ?? 0;
        final int manaA = a['mana'] ?? 0;
        final int hpB = b['hp'] ?? 0;
        final int manaB = b['mana'] ?? 0;

        final double scoreA = (hpA * 0.6) + (manaA * 0.4);
        final double scoreB = (hpB * 0.6) + (manaB * 0.4);

        int result = scoreB.compareTo(scoreA); // Descending (Highest First)

        // Fallback: If points are tied, sort alphabetically
        if (result == 0) {
          return (a['displayName'] ?? '').toString().toLowerCase().compareTo(
            (b['displayName'] ?? '').toString().toLowerCase(),
          );
        }
        return result;
      });
    } else {
      // Traditional A-Z Sort
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
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                          ),
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
                        dropdownIcon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "Phone Number",
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                          ),
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
                        onChanged: (phone) {
                          _completePhoneNumber = phone.completeNumber;
                        },
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

  void _showFriendProfileBottomSheet(
    BuildContext context,
    Map<String, dynamic> userData,
    bool isDark,
    Color primaryColor,
    String myUid,
    bool isBlocked,
  ) {
    final bool isGoated = userData['isGoated'] ?? false;
    final String friendUid = userData['uid'];
    final displayName = userData['displayName'] ?? "No Name";
    final username = userData['username'] ?? "";
    final rawPhone = userData['phoneNumber'] ?? "";
    final bool showPhone = userData['showPhoneNumber'] == true;
    final String statusText = userData['statusText'] ?? "";
    final displayPhone = showPhone ? PhoneFormatter.beautify(rawPhone) : "";

    final String? avatarUrl = userData['avatarUrl'];
    Color avatarColor = Colors.blue.shade100;
    if (userData['avatarColor'] is int) {
      avatarColor = Color(userData['avatarColor']);
    }

    // --- PHASE 3: Extract RPG Stats & Origin Date ---
    final int hp = userData['hp'] ?? 0;
    final int mana = userData['mana'] ?? 0;
    final Timestamp? createdAt =
        userData['createdAt'] ?? userData['created_at'];

    String originDate = "";
    if (createdAt != null) {
      final DateTime dt = createdAt.toDate();
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
      originDate = "Joined ${months[dt.month - 1]} ${dt.year}";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isLandscape =
            MediaQuery.of(ctx).orientation == Orientation.landscape;

        // --- TCG STYLE DECORATIONS ---
        // Creates the "Card Text Box" feel (semi-transparent tinted glass)
        final plateDecoration = BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        );

        // Helper widget for drawing the RPG Bars
        Widget buildStatBar(
          String label,
          int totalValue,
          Color color,
          IconData icon,
        ) {
          int level = (totalValue ~/ 100) + 1;
          int progress = totalValue % 100;
          double percentage = progress / 100.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Lvl. $level",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 10,
                  backgroundColor: isDark ? Colors.black38 : Colors.white60,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.center,
                child: Text(
                  "$progress / 100",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          );
        }

        // --- REUSABLE TCG CARD COMPONENTS ---

        // 1. The Title Plate
        Widget titleWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: plateDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      if (username.isNotEmpty)
                        TextSpan(
                          text: "@$username, ",
                          style: TextStyle(
                            fontSize: isLandscape ? 15 : 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      TextSpan(
                        text: displayName,
                        style: TextStyle(
                          fontSize: isLandscape ? 20 : 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isGoated) ...[
                const SizedBox(width: 8),
                const Text("🐐", style: TextStyle(fontSize: 22)),
              ],
            ],
          ),
        );

        // 2. The Card Art
        Widget avatarWidget = Container(
          width: isLandscape ? 120 : 160,
          height: isLandscape ? 120 : 160,
          decoration: BoxDecoration(
            color: avatarColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 3,
            ),
            image: avatarUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null
              ? Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 60,
                    ),
                  ),
                )
              : null,
        );

        // 3. The Power Level Badge (Pill)
        Widget hpManaPill = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            "🔥 $hp / $mana 💧",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900, // Extra bold for impact
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        );

        // 4. The Flavor Text Plate
        Widget statusWidget = Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            top: 24.0,
          ), // Extra top margin to clear the overlapping pill
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: plateDecoration,
          child: Text(
            '"$statusText"',
            textAlign: TextAlign.center, // Centered looks great inside a plate
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.3,
            ),
          ),
        );

        // 5. The Footer Plate
        Widget metaWidget = Row(
          children: [
            // LEFT ALIGNED: Joined Date
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: originDate.isNotEmpty
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          originDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // RIGHT ALIGNED: Phone Number
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: showPhone
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_iphone,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              displayPhone,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );

        // STACK: Combines Card Art + Overlapping Power Level Badge
        Widget metaWithBadgeStack = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            metaWidget,
            Positioned(
              bottom:
                  -46, // Pulls the pill down so it straddles the bottom border!
              child: hpManaPill,
            ),
          ],
        );

        // --- ASSEMBLE THE TCG CARD BASED ON ORIENTATION ---
        Widget tcgCard;
        if (isLandscape) {
          tcgCard = Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: avatarColor.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          avatarWidget,
                          if (statusText.isNotEmpty) statusWidget,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildStatBar(
                            "HP (Hangouts)",
                            hp,
                            Colors.redAccent,
                            Icons.whatshot,
                          ),
                          const SizedBox(height: 12),
                          buildStatBar(
                            "Mana (Invites)",
                            mana,
                            Colors.blueAccent,
                            Icons.water_drop,
                          ),
                          const SizedBox(height: 20),
                          metaWithBadgeStack,
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          tcgCard = Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: avatarColor.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                titleWidget,
                const SizedBox(height: 20),
                avatarWidget,
                if (statusText.isNotEmpty) statusWidget,
                if (statusText.isEmpty)
                  const SizedBox(height: 24), // Spacer if no status
                const SizedBox(height: 20),
                buildStatBar(
                  "HP (Hangouts)",
                  hp,
                  Colors.redAccent,
                  Icons.whatshot,
                ),
                const SizedBox(height: 12),
                buildStatBar(
                  "Mana (Invites)",
                  mana,
                  Colors.blueAccent,
                  Icons.water_drop,
                ),
                const SizedBox(height: 16),
                metaWithBadgeStack,
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
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
                    const SizedBox(height: 24),

                    // Render the dynamically built TCG Card
                    tcgCard,

                    // Goated & Block Actions
                    const SizedBox(height: 24),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),

                    ListTile(
                      leading: Icon(
                        isGoated ? Symbols.star : Symbols.star,
                        fill: isGoated ? 1.0 : 0.0,
                        color: Colors.amber,
                        size: 28,
                      ),
                      title: Text(
                        isGoated ? "Remove from Goated" : "Mark as Goated",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Show their events first on your feed",
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(myUid)
                            .collection('friends')
                            .doc(friendUid)
                            .set({
                              'isGoated': !isGoated,
                            }, SetOptions(merge: true));
                      },
                    ),

                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),

                    ListTile(
                      leading: Icon(
                        isBlocked ? Icons.notifications_active : Icons.block,
                        color: isBlocked ? Colors.green : Colors.red,
                        size: 28,
                      ),
                      title: Text(
                        isBlocked ? "Unblock User" : "Block User (Shadow Ban)",
                        style: TextStyle(
                          color: isBlocked ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        isBlocked
                            ? "You will see their invites again"
                            : "Silently hide their invites & chats",
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        HapticFeedback.heavyImpact();
                        if (isBlocked) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(myUid)
                              .update({
                                'blockedUids': FieldValue.arrayRemove([
                                  friendUid,
                                ]),
                              });
                        } else {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(myUid)
                              .update({
                                'blockedUids': FieldValue.arrayUnion([
                                  friendUid,
                                ]),
                              });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

                final List<Map<String, dynamic>> friends = friendsSnap.data!;
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
                        const SizedBox(height: 8),
                        Text(
                          "Add friends by username or phone number!",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // --- NEW: THE SORTING TOGGLE HEADER ---
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

                    // --- THE ACTUAL LIST ---
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

                          // --- PHASE 2: Determine Medal for Top 3 (ONLY if Ranked!) ---
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
                                ), // Bronze
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
                                if (snapData != null) {
                                  userData.addAll(snapData);
                                }
                              }

                              // Re-inject the states into the payload so the bottom sheet has them
                              userData['isGoated'] = isGoated;
                              userData['uid'] = uid;

                              final String displayName =
                                  userData['displayName'] ?? "No Name";
                              final String username =
                                  userData['username'] ?? "";
                              final String? avatarUrl = userData['avatarUrl'];
                              final Color avatarColor =
                                  userData['avatarColor'] is int
                                  ? Color(userData['avatarColor'])
                                  : Colors.blue.shade100;

                              // --- Extract Stats ---
                              final int hp = userData['hp'] ?? 0;
                              final int mana = userData['mana'] ?? 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
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
                                      onTap: () =>
                                          _showFriendProfileBottomSheet(
                                            context,
                                            userData,
                                            isDark,
                                            primaryColor,
                                            myUid,
                                            isBlocked,
                                          ),
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
                                                        .withValues(alpha: 0.4),
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
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                                FontWeight.w900,
                                                            fontSize: 17,
                                                            letterSpacing: -0.3,
                                                            color: isBlocked
                                                                ? Colors.grey
                                                                : (isDark
                                                                      ? Colors
                                                                            .white
                                                                      : Colors
                                                                            .black87),
                                                            decoration: null,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
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
                                                            color: Colors.amber,
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

                                            // --- TRAILING STATS OR CHEVRON ---
                                            _sortByScore
                                                ? Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
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
                                                                  ? Colors.white
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
                                                      const SizedBox(height: 4),
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
                                                                  ? Colors.white
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
                                                        : Colors.grey.shade300,
                                                  ),
                                          ],
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

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
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
