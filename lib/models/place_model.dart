import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPlace {
  final String id;
  final String name;
  final String address;
  final DateTime? createdAt;
  final String? placeId;
  final double? lat;
  final double? lng;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    this.createdAt,
    this.placeId,
    this.lat,
    this.lng,
  });

  factory SavedPlace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SavedPlace.fromMap(data, id: doc.id);
  }

  factory SavedPlace.fromMap(Map<String, dynamic> data, {String? id}) {
    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return SavedPlace(
      id: id ?? data['id'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      placeId: data['placeId'],
      lat: parseDouble(data['lat']),
      lng: parseDouble(data['lng']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (placeId != null) 'placeId': placeId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }

  SavedPlace copyWith({
    String? id,
    String? name,
    String? address,
    DateTime? createdAt,
    String? placeId,
    double? lat,
    double? lng,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      placeId: placeId ?? this.placeId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}
