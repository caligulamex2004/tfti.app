import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String username;
  final String phoneNumber;
  final String? avatarUrl;
  final int? avatarColor;
  final String? statusText;
  final int hp;
  final int mana;
  final bool showPhoneNumber;
  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final List<String> blockedUids;
  final bool autoExportCalendar;
  final Map<String, bool> notificationSettings;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.username,
    this.phoneNumber = '',
    this.avatarUrl,
    this.avatarColor,
    this.statusText,
    this.hp = 0,
    this.mana = 0,
    this.showPhoneNumber = false,
    this.fcmToken,
    this.createdAt,
    this.lastActive,
    this.blockedUids = const [],
    this.autoExportCalendar = false,
    this.notificationSettings = const {},
  });

  /// Computed TCG Power Score
  double get tcgScore => (hp * 0.6) + (mana * 0.4);

  /// Handle with '@' prefix
  String get handle => username.startsWith('@') ? username : '@$username';

  /// User Initials for Avatar Fallback
  String get initials {
    if (displayName.trim().isEmpty) return '?';
    final parts = displayName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Resolved Color for Avatar Background
  Color get resolvedColor => Color(avatarColor ?? Colors.blue.toARGB32());

  /// Formatted Join Date
  String get joinedDateFormatted {
    if (createdAt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Joined ${months[createdAt!.month - 1]} ${createdAt!.year}';
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile.fromMap(data, uid: doc.id);
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, {String? uid}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawNotifications = data['notificationSettings'];
    final Map<String, bool> parsedNotifications = {};
    if (rawNotifications is Map) {
      rawNotifications.forEach((k, v) {
        parsedNotifications[k.toString()] = v == true;
      });
    }

    return UserProfile(
      uid: uid ?? data['uid'] ?? '',
      displayName: data['displayName'] ?? '',
      username: data['username'] ?? '',
      phoneNumber: data['phoneNumber'] ?? data['phone'] ?? '',
      avatarUrl: data['avatarUrl'],
      avatarColor: data['avatarColor'] is int ? data['avatarColor'] : null,
      statusText: data['statusText'],
      hp: (data['hp'] is num) ? (data['hp'] as num).toInt() : 0,
      mana: (data['mana'] is num) ? (data['mana'] as num).toInt() : 0,
      showPhoneNumber: data['showPhoneNumber'] == true,
      fcmToken: data['fcmToken'],
      createdAt: parseDate(data['createdAt'] ?? data['created_at']),
      lastActive: parseDate(data['lastActive'] ?? data['lastLogin']),
      blockedUids: data['blockedUids'] is List
          ? List<String>.from(data['blockedUids'])
          : const [],
      autoExportCalendar: data['autoExportCalendar'] == true,
      notificationSettings: parsedNotifications,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'username': username,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'statusText': statusText,
      'hp': hp,
      'mana': mana,
      'showPhoneNumber': showPhoneNumber,
      'fcmToken': fcmToken,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (lastActive != null) 'lastActive': Timestamp.fromDate(lastActive!),
      'blockedUids': blockedUids,
      'autoExportCalendar': autoExportCalendar,
      'notificationSettings': notificationSettings,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? phoneNumber,
    String? avatarUrl,
    int? avatarColor,
    String? statusText,
    int? hp,
    int? mana,
    bool? showPhoneNumber,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? lastActive,
    List<String>? blockedUids,
    bool? autoExportCalendar,
    Map<String, bool>? notificationSettings,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarColor: avatarColor ?? this.avatarColor,
      statusText: statusText ?? this.statusText,
      hp: hp ?? this.hp,
      mana: mana ?? this.mana,
      showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      blockedUids: blockedUids ?? this.blockedUids,
      autoExportCalendar: autoExportCalendar ?? this.autoExportCalendar,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }
}
