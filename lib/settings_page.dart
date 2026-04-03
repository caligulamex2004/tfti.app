import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'favorite_places_page.dart';
import 'theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Theme metadata for the new visual selector
  final List<Map<String, dynamic>> _themeOptions = [
    // --- 6 LIGHT THEMES ---
    {
      'name': 'Daylight',
      'theme': AppTheme.original,
      'color': Colors.blue,
      'isDark': false,
    },
    {
      'name': 'Royal',
      'theme': AppTheme.royalPurple,
      'color': Colors.deepPurple,
      'isDark': false,
    },
    {
      'name': 'Lip Gloss',
      'theme': AppTheme.lipGloss,
      'color': const Color(0xFFFF9A9E),
      'isDark': false,
    },
    {
      'name': 'Jade Edge',
      'theme': AppTheme.jadeEdge,
      'color': const Color(0xFF1C8D6C),
      'isDark': false,
    },
    {
      'name': 'Lavender Haze',
      'theme': AppTheme.lavenderHaze,
      'color': const Color(0xFF7B61FF),
      'isDark': false,
    },
    {
      'name': 'Golden Hour',
      'theme': AppTheme.goldenHour,
      'color': const Color(0xFFFF7E5F),
      'isDark': false,
    },

    // --- 6 DARK THEMES ---
    {
      'name': 'Vigilante',
      'theme': AppTheme.darkBlue,
      'color': Colors.blueAccent,
      'isDark': true,
    },
    {
      'name': 'Midnight Sky',
      'theme': AppTheme.dark,
      'color': const Color(0xFF7637F3),
      'isDark': true,
    },
    {
      'name': 'Electric',
      'theme': AppTheme.electricAmber,
      'color': const Color(0xFFFFAB00),
      'isDark': true,
    },
    {
      'name': 'Knight Beyond',
      'theme': AppTheme.beyondDark,
      'color': const Color(0xFFEE0909),
      'isDark': true,
    },
    {
      'name': 'CyberPunk',
      'theme': AppTheme.cyberPunk,
      'color': const Color(0xFF00E5FF),
      'isDark': true,
    },
    {
      'name': 'Velvet Dust',
      'theme': AppTheme.velvetDust,
      'color': const Color(0xFFFF2A7A),
      'isDark': true,
    },
  ];

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

  // Modern Card Wrapper
  Widget _buildSettingsCard({
    required String title,
    required Widget child,
    required bool isDark,
  }) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          child,
        ],
      ),
    );
  }

  // --- NEW: Automation Section (Calendar Auto-Export) ---
  Widget _buildAutomationSection(bool isDark, Color primaryColor, User? user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        bool autoExportCalendar = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          // Safely extracts the setting; defaults to false if it doesn't exist yet
          autoExportCalendar = data['autoExportCalendar'] ?? false;
        }

        return _buildSettingsCard(
          title: "Automation",
          isDark: isDark,
          child: Column(
            children: [
              _buildModernSwitch(
                title: "Auto-Export to Calendar",
                subtitle: "Prompt to save when you RSVP 'LET'S GO'",
                icon: Icons.calendar_month,
                iconColor:
                    primaryColor, // Matches the user's current signature theme
                value: autoExportCalendar,
                onChanged: (val) async {
                  if (user != null) {
                    try {
                      // Uses SetOptions(merge: true) to safely add this field without deleting other profile data
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .set({
                            'autoExportCalendar': val,
                          }, SetOptions(merge: true));
                    } catch (e) {
                      debugPrint("Error saving calendar setting: $e");
                    }
                  }
                },
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Modernized Notifications Section
  Widget _buildNotificationsSection(
    bool isDark,
    Color primaryColor,
    User? user,
  ) {
    return StreamBuilder<DocumentSnapshot>(
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

        return _buildSettingsCard(
          title: "Notifications",
          isDark: isDark,
          child: Column(
            children: [
              _buildModernSwitch(
                title: "Event Invites",
                subtitle: "When you get invited",
                icon: Symbols.mail,
                iconColor: Colors.blue,
                value: notifyInvites,
                onChanged: (val) => _toggleNotification('invites', val),
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              _buildDivider(isDark),
              _buildModernSwitch(
                title: "Event Updates",
                subtitle: "Time or location changes",
                icon: Icons.update,
                iconColor: Colors.orange,
                value: notifyUpdates,
                onChanged: (val) => _toggleNotification('updates', val),
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              _buildDivider(isDark),
              _buildModernSwitch(
                title: "1-Hour Reminder",
                subtitle: "Better get going! 🏃",
                icon: Icons.hourglass_bottom,
                iconColor: Colors.purple,
                value: notifyReminderHour,
                onChanged: (val) => _toggleNotification('reminder_hour', val),
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              _buildDivider(isDark),
              _buildModernSwitch(
                title: "Event Start",
                subtitle: "Happening Now! 🔥",
                icon: Icons.local_fire_department_outlined,
                iconColor: Colors.red,
                value: notifyReminderStart,
                onChanged: (val) => _toggleNotification('reminder_start', val),
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              _buildDivider(isDark),
              _buildModernSwitch(
                title: "Chat Messages",
                subtitle: "New messages in events",
                icon: Icons.chat_bubble_outline,
                iconColor: Colors.green,
                value: notifyChat,
                onChanged: (val) => _toggleNotification('chat', val),
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Function(bool) onChanged,
    required bool isDark,
    required Color primaryColor,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      value: value,
      activeThumbColor: primaryColor,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      indent: 64,
    );
  }

  // Modernized Theme Selector
  Widget _buildAppearanceSection(bool isDark, Color primaryColor) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return _buildSettingsCard(
          title: "Appearance",
          isDark: isDark,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Light Themes",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _themeOptions
                      .where((t) => !t['isDark'])
                      .map((opt) => _buildThemeChip(opt, isDark, primaryColor))
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  "Dark Themes",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _themeOptions
                      .where((t) => t['isDark'])
                      .map((opt) => _buildThemeChip(opt, isDark, primaryColor))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeChip(
    Map<String, dynamic> opt,
    bool isDark,
    Color primaryColor,
  ) {
    final bool isSelected = themeProvider.currentTheme == opt['theme'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => themeProvider.setTheme(opt['theme']),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.1)
                : (isDark ? Colors.grey.shade900 : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: opt['color'],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    width: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                opt['name'],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Location Settings Section
  Widget _buildLocationSection(bool isDark) {
    return _buildSettingsCard(
      title: "Saved Locations",
      isDark: isDark,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star, color: Colors.amber, size: 20),
        ),
        title: const Text(
          "Favorite Places",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          "Manage your saved addresses",
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FavoritePlacesPage()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = FirebaseAuth.instance.currentUser;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Preferences',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: isLandscape
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 50,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildAutomationSection(
                          isDark,
                          primaryColor,
                          user,
                        ), // <-- Added here
                        const SizedBox(height: 24),
                        _buildNotificationsSection(isDark, primaryColor, user),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                Expanded(
                  flex: 50,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildAppearanceSection(isDark, primaryColor),
                        const SizedBox(height: 24),
                        _buildLocationSection(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildAutomationSection(
                    isDark,
                    primaryColor,
                    user,
                  ), // <-- Added here
                  const SizedBox(height: 24),
                  _buildNotificationsSection(isDark, primaryColor, user),
                  const SizedBox(height: 24),
                  _buildAppearanceSection(isDark, primaryColor),
                  const SizedBox(height: 24),
                  _buildLocationSection(isDark),
                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
    );
  }
}
