import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  String _completePhoneNumber = "";
  String _statusMessage = "";

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

      // FIX 1: Force Source.server to bypass stale cache so recently deleted friends reappear
      final friendsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .get(const GetOptions(source: Source.server));

      final myFriendUids = friendsSnap.docs.map((d) => d.id).toSet();

      // 2. Extract and normalize phones from native contacts
      List<String> allPhones = [];
      Map<String, Contact> phoneToContact = {};

      for (var c in contacts) {
        // FIX 2: Iterate through ALL phone numbers a contact might have (Mobile, Home, Work, etc.)
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

      // 3. Fast Chunked Query (Firestore allows up to 30 items in a 'whereIn' clause)
      if (allPhones.isNotEmpty) {
        for (int i = 0; i < allPhones.length; i += 30) {
          int end = (i + 30 < allPhones.length) ? i + 30 : allPhones.length;
          List<String> chunk = allPhones.sublist(i, end);

          // FIX 3: Force Source.server here as well to guarantee fresh users
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('phoneNumber', whereIn: chunk)
              .get(const GetOptions(source: Source.server));

          for (var doc in snap.docs) {
            final data = doc.data();
            final uid = doc.id;
            final phone = data['phoneNumber'] as String;

            allTftiPhones.add(phone);

            // Only queue them if it's not the user, and they aren't already friends!
            if (uid != myUid && !myFriendUids.contains(uid)) {
              data['uid'] = uid;
              onTfti.add(data);
            }
          }
        }
      }

      // 4. Sort the remaining contacts who are not on the app
      for (var phone in allPhones) {
        if (!allTftiPhones.contains(phone)) {
          notOnTfti.add(phoneToContact[phone]!);
        }
      }

      // Sort both lists alphabetically for easy browsing
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
      Navigator.pop(context); // Close loading dialog

      _showStagingSheet(onTfti, notOnTfti, myUid);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error fetching contacts: $e");
    }
  }

  // FIX: The brand new persistent staging area!
  void _showStagingSheet(
    List<Map<String, dynamic>> onTfti,
    List<Contact> notOnTfti,
    String myUid,
  ) {
    // Flatten lists for performance so ListView.builder doesn't lag on huge address books
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

        // Tracks interactions locally so the sheet doesn't have to close
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

                            // Render Headers
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

                            // Render TFTI Users
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
                                              });
                                          setStateSheet(
                                            () => addedUids.add(uid),
                                          ); // Updates button instantly without closing!
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

                            // Render Non-TFTI Contacts
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

  Future<void> _addFriend() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
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

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _statusMessage = "");
          }
        });
      }
      return;
    }

    final friendDoc = query.docs.first;
    final friendUid = friendDoc.id;

    if (friendUid == myUid) {
      setState(() => _statusMessage = "You can't add yourself!");
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
        });

    setState(() {
      _statusMessage = "Added ${PhoneFormatter.beautify(phoneToAdd)}!";
      _phoneController.clear();
      _completePhoneNumber = "";
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _statusMessage = "");
      }
    });
  }

  Future<void> _removeFriend(String friendUid, String friendName) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Friend?"),
        content: Text("Remove $friendName from your squad?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.redAccent : Colors.red,
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(friendUid)
          .delete();
    }
  }

  Future<void> _editFriendCircles(String friendUid, String friendName) async {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('circles')
        .get();

    if (circlesSnapshot.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Create some Squad Teams first!")),
        );
      }
      return;
    }

    final circles = circlesSnapshot.docs.toList();
    circles.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );

    final friendDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .doc(friendUid)
        .get();
    List<String> selectedCircleIds = List<String>.from(
      friendDoc.data()?['circles'] ?? [],
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Assign $friendName to..."),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: circles.map((circle) {
                    final isChecked = selectedCircleIds.contains(circle.id);
                    return CheckboxListTile(
                      activeColor: primaryColor,
                      title: Text(circle['name']),
                      value: isChecked,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            selectedCircleIds.add(circle.id);
                          } else {
                            selectedCircleIds.remove(circle.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('friends')
                        .doc(friendUid)
                        .update({'circles': selectedCircleIds});

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: themeProvider.onPrimaryColor,
                  ),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
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
          list.add(data);
        }
      }),
    );

    list.sort(
      (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
        (b['displayName'] ?? '').toString().toLowerCase(),
      ),
    );
    return list;
  }

  Widget _buildAddFriendSection(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24.0),
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
          const SizedBox(height: 6),
          Text(
            "Add friends by phone number, or import directly from your contacts.",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IntlPhoneField(
                  controller: _phoneController,
                  initialCountryCode: 'US',
                  dropdownIconPosition: IconPosition.trailing,
                  dropdownIcon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addFriend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: themeProvider.onPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  "Add",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),

          // FIX: Replaced dynamic Padding with fixed-height SizedBox to prevent UI shift
          SizedBox(
            height: 32,
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

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.import_contacts, color: primaryColor),
              label: Text(
                "Import from Contacts",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: _importContacts,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
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
  ) {
    final displayName = userData['displayName'] ?? "No Name";
    final rawPhone = userData['phoneNumber'] ?? "";
    final bool showPhone = userData['showPhoneNumber'] == true;
    final String statusText = userData['statusText'] ?? "";
    final displayPhone = showPhone ? PhoneFormatter.beautify(rawPhone) : "";

    final String? avatarUrl = userData['avatarUrl'];
    Color avatarColor = Colors.blue.shade100;
    if (userData['avatarColor'] is int) {
      avatarColor = Color(userData['avatarColor']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to handle scrolling properly
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: double
                  .infinity, // 👇 FIX 1: Forces the bottom sheet to always be full width
              child: SingleChildScrollView(
                // 👇 FIX 2: Prevents overflow by allowing scrolling on short screens!
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
                    const SizedBox(height: 32),

                    // --- AVATAR ---
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: avatarColor,
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 40,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- NAME ---
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // --- MOOD / STATUS PILL ---
                    if (statusText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(
                          top: 16,
                          left: 32,
                          right: 32,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            height: 1.4,
                          ),
                        ),
                      ),

                    // --- PHONE NUMBER ---
                    if (showPhone && displayPhone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_iphone,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayPhone,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
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
            final friends = friendsSnap.data!;

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
                      "Add friends by phone number or import them!",
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade500 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friendInitData = friends[index];
                final uid = friendInitData['uid'];

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, userSnap) {
                    Map<String, dynamic> userData = friendInitData;

                    if (userSnap.hasData && userSnap.data!.exists) {
                      userData = userSnap.data!.data() ?? {};
                    }

                    final displayName = userData['displayName'] ?? "No Name";
                    final rawPhone = userData['phoneNumber'] ?? "";
                    // NEW: Extract Privacy and Status variables
                    final bool showPhone = userData['showPhoneNumber'] == true;
                    final String statusText = userData['statusText'] ?? "";

                    // Respect the privacy toggle!
                    final displayPhone = showPhone
                        ? PhoneFormatter.beautify(rawPhone)
                        : ""; // show nothing if they chose to hide it

                    final String? avatarUrl = userData['avatarUrl'];

                    Color avatarColor = Colors.blue.shade100;
                    if (userData['avatarColor'] is int) {
                      avatarColor = Color(userData['avatarColor']);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        // FIX: Replaced ListTile with InkWell & Row to prevent rotation crash!
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          // If you have the profile sheet onTap, you can drop it right here:
                          onTap: () => _showFriendProfileBottomSheet(
                            context,
                            userData,
                            isDark,
                            primaryColor,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical:
                                  12, // Adjusted to match ListTile padding
                            ),
                            child: Row(
                              children: [
                                // --- LEADING: Avatar Stack ---
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: avatarColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: avatarColor,
                                    backgroundImage: avatarUrl != null
                                        ? CachedNetworkImageProvider(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : "?",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // --- TITLE & SUBTITLE ---
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (showPhone || statusText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6.0,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (showPhone) ...[
                                                Flexible(
                                                  child: Text(
                                                    displayPhone,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? Colors.grey.shade400
                                                          : Colors
                                                                .grey
                                                                .shade600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (statusText.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Text(
                                                      "•",
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors
                                                                  .grey
                                                                  .shade600
                                                            : Colors
                                                                  .grey
                                                                  .shade400,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                              if (statusText.isNotEmpty)
                                                Flexible(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .secondaryContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: primaryColor
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      statusText,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: primaryColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // --- TRAILING: 3-Dot Menu ---
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  onSelected: (value) {
                                    if (value == 'circle') {
                                      _editFriendCircles(uid, displayName);
                                    }
                                    if (value == 'remove') {
                                      _removeFriend(uid, displayName);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'circle',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Symbols.circles,
                                            color: primaryColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            "Assign to Team",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.person_remove,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            "Remove Squadmate",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
