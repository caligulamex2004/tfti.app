import 'package:flutter/material.dart';

/// Card dedicated to the session logout action.
class AccountLogoutCard extends StatelessWidget {
  final VoidCallback onLogout;

  const AccountLogoutCard({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout, color: Colors.orange, size: 20),
          ),
          title: const Text(
            "Log Out",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            "Sign out of your account on this device",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          onTap: onLogout,
        ),
      ),
    );
  }
}

/// Danger Zone card explicitly isolating destructive actions like Delete Account.
class AccountDangerCard extends StatelessWidget {
  final VoidCallback? onLogout;
  final VoidCallback onDeleteAccount;

  const AccountDangerCard({
    super.key,
    this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dangerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: isDark ? Colors.red.shade400 : Colors.red.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                "DANGER ZONE",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.red.shade400 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.red.withValues(alpha: 0.06)
                : Colors.red.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.red.shade900.withValues(alpha: 0.5)
                  : Colors.red.shade200,
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 6,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              title: const Text(
                "Delete Account",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                "Permanently wipe your account and all data",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                ),
              ),
              onTap: onDeleteAccount,
            ),
          ),
        ),
      ],
    );

    if (onLogout != null) {
      return Column(
        children: [
          AccountLogoutCard(onLogout: onLogout!),
          const SizedBox(height: 36),
          dangerContent,
        ],
      );
    }

    return dangerContent;
  }
}
