import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeamCircle {
  final String id;
  final String name;
  final DateTime? createdAt;
  final int memberCount;

  const TeamCircle({
    required this.id,
    required this.name,
    this.createdAt,
    this.memberCount = 0,
  });

  factory TeamCircle.fromFirestore(DocumentSnapshot doc, {int memberCount = 0}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TeamCircle(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Team',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      memberCount: memberCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  TeamCircle copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? memberCount,
  }) {
    return TeamCircle(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}

class TeamMember {
  final String uid;
  final String displayName;
  final String username;
  final String phoneNumber;
  final String? avatarUrl;
  final int? avatarColor;
  final int hp;
  final int mana;
  final bool isGoated;
  final List<String> circles;

  const TeamMember({
    required this.uid,
    required this.displayName,
    this.username = '',
    this.phoneNumber = '',
    this.avatarUrl,
    this.avatarColor,
    this.hp = 0,
    this.mana = 0,
    this.isGoated = false,
    this.circles = const [],
  });

  double get score => (hp * 0.6) + (mana * 0.4);

  Color get resolvedColor => Color(avatarColor ?? Colors.grey.toARGB32());

  factory TeamMember.fromFirestore(
    DocumentSnapshot friendDoc,
    Map<String, dynamic>? userDocData,
  ) {
    final friendData = friendDoc.data() as Map<String, dynamic>? ?? {};
    final userData = userDocData ?? {};

    return TeamMember(
      uid: friendDoc.id,
      displayName: userData['displayName'] ?? 'Unknown',
      username: userData['username'] ?? '',
      phoneNumber: userData['phoneNumber'] ?? friendData['phoneNumber'] ?? '',
      avatarUrl: userData['avatarUrl'],
      avatarColor: userData['avatarColor'] is int ? userData['avatarColor'] : null,
      hp: (userData['hp'] is num) ? (userData['hp'] as num).toInt() : 0,
      mana: (userData['mana'] is num) ? (userData['mana'] as num).toInt() : 0,
      isGoated: friendData['isGoated'] == true,
      circles: friendData['circles'] is List
          ? List<String>.from(friendData['circles'])
          : const [],
    );
  }
}
