import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tftiapp/models/squad_request_model.dart';

class SquadRequestsSection extends StatelessWidget {
  final List<SquadRequest> requests;
  final Function(SquadRequest) onSquadUp;
  final Function(SquadRequest) onPass;
  final Function(SquadRequest) onBlock;

  const SquadRequestsSection({
    super.key,
    required this.requests,
    required this.onSquadUp,
    required this.onPass,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_fire_department, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  "Squad Requests (${requests.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final req = requests[index];
              final avatarColor = req.avatarColor != null
                  ? Color(req.avatarColor!)
                  : Colors.blue;
              final name = req.displayName.isNotEmpty ? req.displayName : "Unknown";
              final handle = req.username.isNotEmpty
                  ? (req.username.startsWith('@') ? req.username : '@${req.username}')
                  : '';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: avatarColor,
                          backgroundImage: req.avatarUrl != null && req.avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(req.avatarUrl!)
                              : null,
                          child: req.avatarUrl == null || req.avatarUrl!.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (handle.isNotEmpty)
                                Text(
                                  handle,
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            key: ValueKey('squad_up_button_${req.fromUid}'),
                            onPressed: () => onSquadUp(req),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Squad Up 🔥",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            key: ValueKey('pass_button_${req.fromUid}'),
                            onPressed: () => onPass(req),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: BorderSide(
                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Pass ✌️",
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: ValueKey('block_button_${req.fromUid}'),
                          tooltip: "Block",
                          icon: Icon(
                            Icons.block,
                            size: 20,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                          onPressed: () => onBlock(req),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
