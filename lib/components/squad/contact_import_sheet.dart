import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../utils/phone_formatter.dart';
import '../../utils/event_service.dart';
import '../../services/contact_resolver.dart';
import '../../services/contact_service.dart';
import '../shared/app_avatar.dart';

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
                      final profileName = item['displayName'] ?? "Unknown";
                      final contactName = item['contactName'] as String?;
                      final bool hasContactName =
                          contactName != null && contactName.trim().isNotEmpty;
                      final miniFormat =
                          ContactResolver.instance.miniProfileFormat;
                      final primaryName = hasContactName
                          ? ContactHelper.formatName(contactName, miniFormat)
                          : ContactHelper.formatName(profileName, miniFormat);
                      final username = item['username'] as String?;
                      final phone = PhoneFormatter.beautify(
                        item['phoneNumber'] ?? "",
                      );
                      final avatarUrl = item['avatarUrl'];
                      final avatarColor =
                          item['avatarColor'] ?? Colors.blue.toARGB32();
                      final isAdded = _addedUids.contains(uid);

                      String subtitleText;
                      if (hasContactName) {
                        final String handlePart =
                            (username != null && username.isNotEmpty)
                                ? " (@$username)"
                                : "";
                        if (profileName.isNotEmpty &&
                            profileName != primaryName) {
                          subtitleText = "~ $profileName$handlePart • $phone";
                        } else if (handlePart.isNotEmpty) {
                          subtitleText = "@$username • $phone";
                        } else {
                          subtitleText = phone;
                        }
                      } else if (username != null && username.isNotEmpty) {
                        subtitleText = "@$username • $phone";
                      } else {
                        subtitleText = phone;
                      }

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
                          child: AppAvatar.fromColorValue(
                            avatarColor: avatarColor,
                            avatarUrl: avatarUrl,
                            displayName: primaryName,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                primaryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasContactName) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: "From your contacts",
                                child: Icon(
                                  Icons.contact_phone_outlined,
                                  size: 15,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          subtitleText,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

                                  EventService.syncActiveEventsForUser(
                                    widget.myUid,
                                  );

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
                      final name = item.displayName?.trim() ?? '';
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
