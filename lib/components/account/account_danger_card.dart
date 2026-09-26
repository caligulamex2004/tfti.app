import 'package:flutter/material.dart';

class AccountDangerCard extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const AccountDangerCard({
    super.key,
    required this.onLogout,
    required this.onDeleteAccount,
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
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text(
              "Log Out",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            onTap: onLogout,
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}
