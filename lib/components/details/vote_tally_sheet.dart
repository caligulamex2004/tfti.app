import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VoteTallySheet extends StatelessWidget {
  final List<dynamic> options;
  final List<Map<String, dynamic>> guests;

  const VoteTallySheet({
    super.key,
    required this.options,
    required this.guests,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.how_to_vote, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  "Vote Breakdown",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: options.map((opt) {
                    final optId = opt['id'];
                    final title = opt['title'];
                    final location = opt['location'];

                    final voters = guests.where((g) {
                      if (g['status'] == 'declined') return false;
                      final vList = List<String>.from(g['votes'] ?? []);
                      return vList.contains(optId);
                    }).toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (location != null && location != 'TBD')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          location,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${voters.length} Vote${voters.length == 1 ? '' : 's'}",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (voters.isEmpty)
                            Text(
                              "No votes yet.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: voters.map((v) {
                                final avatarColor = Color(
                                  v['avatarColor'] ?? Colors.blue.toARGB32(),
                                );
                                final avatarUrl = v['avatarUrl'];
                                final name = v['displayName'];

                                return Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: avatarColor,
                                    backgroundImage: avatarUrl != null
                                        ? CachedNetworkImageProvider(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            name[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  label: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey.shade200
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                  backgroundColor: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade100,
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade200,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
