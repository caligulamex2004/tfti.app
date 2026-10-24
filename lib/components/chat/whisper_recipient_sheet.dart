import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/contact_resolver.dart';
import '../shared/app_avatar.dart';

class WhisperRecipientSheet extends StatefulWidget {
  final List<Map<String, dynamic>> eventGuests;
  final Function(Map<String, dynamic> recipient) onSelectRecipient;
  final String? currentUserId;

  const WhisperRecipientSheet({
    super.key,
    required this.eventGuests,
    required this.onSelectRecipient,
    this.currentUserId,
  });

  @override
  State<WhisperRecipientSheet> createState() => _WhisperRecipientSheetState();
}

class _WhisperRecipientSheetState extends State<WhisperRecipientSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? currentUid = widget.currentUserId;
    if (currentUid == null) {
      try {
        currentUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        currentUid = null;
      }
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final availableGuests = widget.eventGuests.where((guest) {
      if (guest['uid'] == currentUid) return false;
      if (guest['status'] == 'declined') return false;

      if (_searchQuery.isNotEmpty) {
        final displayName =
            (guest['displayName'] as String? ?? '').toLowerCase();
        final phone = (guest['phoneNumber'] ?? '').toString();
        final contactName =
            (ContactResolver.instance.resolveName(phone) ?? '').toLowerCase();
        final firstName = (ContactResolver.instance.resolveFirstName(
                  phone,
                  fallbackName: guest['displayName'],
                ) ??
                '')
            .toLowerCase();
        final tag = (guest['tag'] as String? ?? '').toLowerCase();
        return firstName.contains(_searchQuery) ||
            displayName.contains(_searchQuery) ||
            contactName.contains(_searchQuery) ||
            tag.contains(_searchQuery);
      }
      return true;
    }).toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title & Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hearing_outlined,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF334155),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Whisper Message",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Only you and this person will see the message",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search guests...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey.shade900
                      : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),
            const SizedBox(height: 8),

            // Guest List
            if (availableGuests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? "No guests match '$_searchQuery'"
                        : "No guests available to whisper to",
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableGuests.length,
                  itemBuilder: (context, index) {
                    final guest = availableGuests[index];
                    final String displayName =
                        guest['displayName'] ?? 'Unknown';
                    final String phone =
                        (guest['phoneNumber'] ?? '').toString();
                    final String? contactFullName =
                        ContactResolver.instance.resolveName(phone);
                    final bool hasContact = contactFullName != null &&
                        contactFullName.trim().isNotEmpty;
                    final String firstName =
                        ContactResolver.instance.resolveMiniProfileName(
                              phone,
                              fallbackName: displayName,
                            ) ??
                            ContactResolver.instance.formatMiniProfileFallback(
                              displayName,
                            );
                    final String tag = guest['tag'] ?? '';
                    final String? avatarUrl = guest['avatarUrl'];
                    final dynamic avatarColor = guest['avatarColor'];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: AppAvatar.fromColorValue(
                        radius: 20,
                        avatarColor: avatarColor,
                        avatarUrl: avatarUrl,
                        displayName: firstName,
                        fontSize: 14,
                      ),
                      title: Text(
                        firstName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          if (hasContact) ...[
                            Icon(
                              Icons.contact_phone_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              hasContact &&
                                      displayName.trim() != firstName.trim()
                                  ? "~ $displayName · @$tag"
                                  : (tag.isNotEmpty ? "@$tag" : displayName),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSelectRecipient(guest);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
