import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

// --- AUTH PHONE FIELD ---
class AuthPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;

  const AuthPhoneField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntlPhoneField(
      controller: controller,
      initialCountryCode: 'US',
      dropdownIconPosition: IconPosition.trailing,
      dropdownIcon: Icon(
        Icons.arrow_drop_down,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: "Phone Number",
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      onChanged: (phone) => onChanged(phone.completeNumber),
    );
  }
}

class AuthService {
  static Future<void> saveDeviceToken(User user) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("✅ FCM Token saved successfully");
      }
    } catch (e) {
      debugPrint("❌ Error saving FCM token: $e");
    }
  }

  static Future<void> ensureUserDocExists({
    required User user,
    required String enteredName,
    required String enteredUsername,
    required bool agreedToToS,
    required bool agreedToPrivacy,
  }) async {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final docSnapshot = await userDoc.get();

    String finalName = enteredName;
    if (finalName.isEmpty) {
      finalName = user.phoneNumber ?? "Unknown User";
    }

    final data = docSnapshot.data();
    final isNewUser = !docSnapshot.exists ||
        data == null ||
        !data.containsKey('username') ||
        !data.containsKey('createdAt');

    if (isNewUser) {
      // BRAND NEW USER: Run a transaction to safely claim username and create profile
      String cleanUsername = enteredUsername.trim().toLowerCase();
      if (cleanUsername.startsWith('@')) {
        cleanUsername = cleanUsername.substring(1);
      }

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final usernameRef = FirebaseFirestore.instance
              .collection('usernames')
              .doc(cleanUsername);
          final nameDoc = await transaction.get(usernameRef);

          // Failsafe: If the username was snatched between the pre-flight check and SMS entry
          if (nameDoc.exists) {
            cleanUsername =
                "${cleanUsername}_${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}";
            final fallbackRef = FirebaseFirestore.instance
                .collection('usernames')
                .doc(cleanUsername);
            transaction.set(fallbackRef, {'uid': user.uid});
          } else {
            transaction.set(usernameRef, {'uid': user.uid});
          }

          transaction.set(userDoc, {
            'uid': user.uid,
            'phoneNumber': user.phoneNumber,
            'displayName': finalName,
            'username': cleanUsername,
            'avatarColor': Colors.blue.toARGB32(),
            'createdAt': FieldValue.serverTimestamp(),
            'agreedToToS': agreedToToS,
            'agreedToPrivacy': agreedToPrivacy,
          }, SetOptions(merge: true));
        });

        await user.updateDisplayName(finalName);
      } catch (e) {
        debugPrint("Error creating user and claiming username: $e");
      }
    } else {
      // EXISTING USER LOGGING IN: Just ensure phone number is patched
      if (!data.containsKey('phone') && !data.containsKey('phoneNumber')) {
        await userDoc.set({
          'phoneNumber': user.phoneNumber,
        }, SetOptions(merge: true));
      }
    }
  }

  static Future<bool> checkPhoneExists(String phoneNumber) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  static Future<bool> checkUsernameExists(String username) async {
    String cleanName = username.trim().toLowerCase();
    if (cleanName.startsWith('@')) {
      cleanName = cleanName.substring(1);
    }

    final usernameDoc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(cleanName)
        .get();

    return usernameDoc.exists;
  }
}
