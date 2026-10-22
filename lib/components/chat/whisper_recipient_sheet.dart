import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/app_avatar.dart';

class WhisperRecipientSheet extends StatefulWidget {
  final List<Map<String, dynamic>> eventGuests;
  final Function(Map<String, dynamic> recipient) onSelectRecipient;

  const WhisperRecipientSheet({
    super.key,
    required this.eventGuests,
    required this.onSelectRecipient,
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final availableGuests = widget.eventGuests.where((guest) {
      if (guest['uid'] == currentUid) return false;
      if (guest['status'] == 'declined') return false;

      if (_searchQuery.isNotEmpty) {
        final name = (guest['displayName'] as String? ?? '').toLowerCase();
        final tag = (guest['tag'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery) || tag.contains(_searchQuery);
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
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: primaryColor,
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
                    final String name = guest['displayName'] ?? 'Unknown';
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
                        displayName: name,
                        fontSize: 14,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: tag.isNotEmpty
                          ? Text(
                              "@$tag",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            )
                          : null,
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
