import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favorite_places_page.dart';
import 'theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _toggleNotification(String key, bool newValue) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'notificationSettings.$key': newValue});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error saving setting: $e")));
        }
      }
    }
  }

  // Helper method to build a theme toggle
  Widget _buildThemeToggle(String title, AppTheme targetTheme, bool isDark) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        final isActive = themeProvider.currentTheme == targetTheme;

        return Column(
          children: [
            SwitchListTile(
              title: Text(title),
              value: isActive,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool turnedOn) {
                // Only allow them to turn a theme ON (making it active).
                // If they try to turn the current one OFF, we ignore it because
                // an app must always have an active theme!
                if (turnedOn) {
                  themeProvider.setTheme(targetTheme);
                }
              },
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Theme.of(context).cardColor : Colors.grey[50];
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Preferences'),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. NOTIFICATIONS SECTION ---
            Text(
              'Notifications',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                bool notifyInvites = true;
                bool notifyUpdates = true;
                bool notifyChat = true;
                bool notifyReminderHour = true;
                bool notifyReminderStart = true;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  if (data.containsKey('notificationSettings')) {
                    final settings = data['notificationSettings'] ?? {};
                    notifyInvites = settings['invites'] ?? true;
                    notifyUpdates = settings['updates'] ?? true;
                    notifyChat = settings['chat'] ?? true;
                    notifyReminderHour = settings['reminder_hour'] ?? true;
                    notifyReminderStart = settings['reminder_start'] ?? true;
                  }
                }

                return Card(
                  elevation: isDark ? 1 : 2,
                  color: cardColor,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text("Event Invites"),
                        subtitle: const Text("When you get invited"),
                        value: notifyInvites,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) => _toggleNotification('invites', val),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                      SwitchListTile(
                        title: const Text("Event Updates"),
                        subtitle: const Text("Time or location changes"),
                        value: notifyUpdates,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) => _toggleNotification('updates', val),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),

                      // --- NEW: 1-Hour Reminder Toggle ---
                      SwitchListTile(
                        title: const Text("1-Hour Reminder"),
                        subtitle: const Text("Better get going! 🏃"),
                        value: notifyReminderHour,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) =>
                            _toggleNotification('reminder_hour', val),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),

                      // --- NEW: Event Start Reminder Toggle ---
                      SwitchListTile(
                        title: const Text("Event Start Reminder"),
                        subtitle: const Text("Happening Now! 🔥"),
                        value: notifyReminderStart,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) =>
                            _toggleNotification('reminder_start', val),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),

                      SwitchListTile(
                        title: const Text("Chat Messages"),
                        subtitle: const Text("New messages in events"),
                        value: notifyChat,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) => _toggleNotification('chat', val),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- 2. APPEARANCE SECTION ---
            Text(
              'Appearance',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: isDark ? 1 : 2,
              color: cardColor,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias, // Keeps bottom corners rounded
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _buildThemeToggle('Royal Purple', AppTheme.original, isDark),
                  _buildThemeToggle(
                    'Daylight (Blue)',
                    AppTheme.lightBlue,
                    isDark,
                  ),
                  _buildThemeToggle(
                    'Lip Gloss (Pink)',
                    AppTheme.lipGloss,
                    isDark,
                  ),
                  _buildThemeToggle(
                    'Jade Edge (Green)',
                    AppTheme.jadeEdge,
                    isDark,
                  ),
                  _buildThemeToggle(
                    'Vigilante Blue (Dark)',
                    AppTheme.darkBlue,
                    isDark,
                  ),
                  _buildThemeToggle(
                    'Midnight Sky (Dark)',
                    AppTheme.dark,
                    isDark,
                  ),
                  _buildThemeToggle(
                    'Electric Amber (Dark)',
                    AppTheme.electricAmber,
                    isDark,
                  ),
                  _buildThemeToggle(
                    'Beyond Dark (Dark)',
                    AppTheme.beyondDark,
                    isDark,
                  ),
                  _buildThemeToggle(
                    'CyberPunk (Dark)',
                    AppTheme.cyberPunk,
                    isDark,
                  ),
                ],
              ),
            ),

            // --- NEW: FAVORITE PLACES BUTTON ---
            const SizedBox(height: 30),
            Text(
              'Location Settings',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: isDark ? 1 : 2,
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text("Favorite Places"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritePlacesPage(),
                    ),
                  );
                },
              ),
            ),
            // ------------------------------------
          ],
        ),
      ),
    );
  }
}
