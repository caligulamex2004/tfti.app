import 'package:cloud_firestore/cloud_firestore.dart';

class Friend {
  final String uid;
  final String phoneNumber;
  final bool isGoated;
  final List<String> circles;
  final DateTime? addedAt;

  const Friend({
    required this.uid,
    this.phoneNumber = '',
    this.isGoated = false,
    this.circles = const [],
    this.addedAt,
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Friend(
      uid: doc.id,
      phoneNumber: data['phoneNumber'] ?? data['phone'] ?? '',
      isGoated: data['isGoated'] == true,
      circles: data['circles'] is List ? List<String>.from(data['circles']) : const [],
      addedAt: (data['addedAt'] is Timestamp)
          ? (data['addedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'isGoated': isGoated,
      'circles': circles,
      if (addedAt != null) 'addedAt': Timestamp.fromDate(addedAt!),
    };
  }

  Friend copyWith({
    String? uid,
    String? phoneNumber,
    bool? isGoated,
    List<String>? circles,
    DateTime? addedAt,
  }) {
    return Friend(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isGoated: isGoated ?? this.isGoated,
      circles: circles ?? this.circles,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
