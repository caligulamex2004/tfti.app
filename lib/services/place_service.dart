import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tftiapp/models/place_model.dart';

class PlaceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of saved/favorite places for a user
  static Stream<List<SavedPlace>> placesStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedPlace.fromFirestore(doc))
            .toList());
  }

  /// Save a new favorite place
  static Future<String> savePlace({
    required String uid,
    required String name,
    required String address,
    double? latitude,
    double? longitude,
    String? category,
  }) async {
    final docRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .add({
      'name': name.trim(),
      'address': address.trim(),
      'latitude': ?latitude,
      'longitude': ?longitude,
      'category': ?category,
      'addedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Rename a saved favorite place
  static Future<void> renamePlace({
    required String uid,
    required String placeId,
    required String newName,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .doc(placeId)
        .update({'name': newName.trim()});
  }

  /// Delete a saved favorite place
  static Future<void> deletePlace({
    required String uid,
    required String placeId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .doc(placeId)
        .delete();
  }
}
