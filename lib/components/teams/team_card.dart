import 'package:flutter/material.dart';
import '../../models/team_model.dart';
import 'team_avatar_stack.dart';

/// Card widget displaying a team circle with members facepile and actions.
class TeamCard extends StatelessWidget {
  final TeamCircle team;
  final String myUid;
  final bool isSelected;
  final bool isLandscape;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const TeamCard({
    super.key,
    required this.team,
    required this.myUid,
    required this.isSelected,
    required this.isLandscape,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  void _showTeamOptionsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
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
              Text(
                team.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text(
                  "Rename Team",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onRename();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Delete Team",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text("Delete Team?"),
                      content: Text(
                        "Are you sure you want to delete '${team.name}'? Your friends will not be deleted from your account.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: Text(
                            "Delete",
                            style: TextStyle(
                              color: isDark ? Colors.redAccent : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    onDelete();
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 12.0 : 16.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isDark && !isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            TeamAvatarStack(myUid: myUid, circleId: team.id),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
              onPressed: () => _showTeamOptionsSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}
