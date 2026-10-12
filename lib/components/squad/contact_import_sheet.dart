import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../utils/phone_formatter.dart';
import '../../services/contact_service.dart';

class ContactImportSheet extends StatefulWidget {
  final List<Map<String, dynamic>> onTfti;
  final List<Contact> notOnTfti;
  final String myUid;
  final Function(String phone) onInviteSms;
  final Function(String uid) onFriendAdded;

  const ContactImportSheet({
    super.key,
    required this.onTfti,
    required this.notOnTfti,
    required this.myUid,
    required this.onInviteSms,
    required this.onFriendAdded,
  });

  @override
  State<ContactImportSheet> createState() => _ContactImportSheetState();
}

class _ContactImportSheetState extends State<ContactImportSheet> {
  final Set<String> _addedUids = {};
  final Set<String> _invitedPhones = {};
  late List<dynamic> _listItems;

  @override
  void initState() {
    super.initState();
    _listItems = [];
    if (widget.onTfti.isNotEmpty) {
      _listItems.add("HEADER_TFTI");
      _listItems.addAll(widget.onTfti);
    }
    if (widget.notOnTfti.isNotEmpty) {
      _listItems.add("HEADER_INVITE");
      _listItems.addAll(widget.notOnTfti);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "Import Contacts",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ),
            const Divider(height: 1),
            if (_listItems.isEmpty)
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
                  itemCount: _listItems.length,
                  itemBuilder: (context, index) {
                    final item = _listItems[index];

                    if (item == "HEADER_TFTI") {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
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
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
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
                      final isAdded = _addedUids.contains(uid);

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
                                      .doc(widget.myUid)
                                      .collection('friends')
                                      .doc(uid)
                                      .set({
                                        'uid': uid,
                                        'phoneNumber': item['phoneNumber'],
                                        'addedAt': FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));

                                  if (!mounted) return;
                                  setState(() => _addedUids.add(uid));
                                  widget.onFriendAdded(uid);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  foregroundColor: primaryColor,
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Add",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                      );
                    }

                    if (item is Contact) {
                      final name = item.displayName;
                      final rawPhone = item.phones.first.number;
                      final normPhone =
                          ContactHelper.normalizePhone(rawPhone) ?? rawPhone;
                      final isInvited = _invitedPhones.contains(normPhone);

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
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
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
                                  widget.onInviteSms(normPhone);
                                  setState(() => _invitedPhones.add(normPhone));
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
  }
}
