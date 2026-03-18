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
      if (!mounted) return;
      Navigator.pop(context);

      if (contacts == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permission denied for contacts.")),
        );
        return;
      }

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No contacts found (or bypassed for iOS Simulator)."),
          ),
        );
        return;
      }
      _showContactsSheet(contacts);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error fetching contacts: $e");
    }
  }

  void _showContactsSheet(List<Contact> contacts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Import from Contacts",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      // V2 API relies on displayName and phones properties
                      final name = contact.displayName;
                      final rawPhone = contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : "No Number";

                      if (rawPhone == "No Number") {
                        return const SizedBox.shrink();
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Text(
                            name.isNotEmpty ? name[0] : "?",
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(PhoneFormatter.beautify(rawPhone)),
                        trailing: ElevatedButton(
                          onPressed: () => _handleImportContact(name, rawPhone),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            foregroundColor: primaryColor,
                            elevation: 0,
                          ),
                          child: const Text("Add / Invite"),
                        ),
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
  }

  Future<void> _handleImportContact(String name, String rawPhone) async {
    final normalized = ContactHelper.normalizePhone(rawPhone);

    if (normalized == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid phone number format.")),
        );
      }
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      _completePhoneNumber = normalized;
      await _addFriend();
      if (mounted) Navigator.pop(context);
    } else {
      if (!mounted) return;
      _inviteViaSms(normalized);
    }
  }

  Future<void> _inviteViaSms(String phone) async {
    const String kAppUrl = "https://tftiapp.com";
    final String message =
        "Hey! Join me on TFTI so I can invite you to events! Check it out: $kAppUrl";
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
      setState(() => _statusMessage = "User not found on TFTI.");

      if (!mounted) return;
      final primaryColor = Theme.of(context).colorScheme.primary;

      final invite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Not on TFTI Yet"),
          content: Text(
            "Would you like to invite ${PhoneFormatter.beautify(phoneToAdd)} to join TFTI via SMS?",
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
          const SnackBar(content: Text("Create some circles first!")),
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

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("The Whole Squad"),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_contacts),
            tooltip: "Import from Phone",
            onPressed: _importContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                if (!isDark)
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Grow your squad",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
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
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (phone) {
                          _completePhoneNumber = phone.completeNumber;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _addFriend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: themeProvider.onPrimaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 15,
                        ),
                      ),
                      child: const Text("Add"),
                    ),
                  ],
                ),
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
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
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add friends by phone number above!",
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

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friendInitData = friends[index];
                        final uid = friendInitData['uid'];

                        return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, userSnap) {
                            Map<String, dynamic> userData = friendInitData;

                            if (userSnap.hasData && userSnap.data!.exists) {
                              userData = userSnap.data!.data() ?? {};
                            }

                            final displayName =
                                userData['displayName'] ?? "No Name";

                            final rawPhone = userData['phoneNumber'] ?? "";
                            final displayPhone = PhoneFormatter.beautify(
                              rawPhone,
                            );

                            final String? avatarUrl = userData['avatarUrl'];

                            Color avatarColor = Colors.blue.shade100;
                            if (userData['avatarColor'] is int) {
                              avatarColor = Color(userData['avatarColor']);
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              elevation: isDark ? 1 : 2,
                              color: Theme.of(context).cardColor,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isDark
                                    ? BorderSide(color: Colors.grey.shade800)
                                    : BorderSide.none,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
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
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  displayPhone,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Symbols.circles,
                                        color: primaryColor,
                                      ),
                                      tooltip: "Assign to Circle",
                                      onPressed: () =>
                                          _editFriendCircles(uid, displayName),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        color: isDark
                                            ? Colors.redAccent
                                            : Colors.red,
                                      ),
                                      tooltip: "Remove Friend",
                                      onPressed: () =>
                                          _removeFriend(uid, displayName),
                                    ),
                                  ],
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
            ),
          ),
        ],
      ),
    );
  }
}
