import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tftiapp/models/place_model.dart';

class PlaceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _apiKey = String.fromEnvironment('PLACES_API_KEY');

  /// In-memory cache of fetched PlaceDetailsModel by placeId or query key
  static final Map<String, PlaceDetailsModel> _detailsCache = {};

  /// Stream of saved/favorite places for a user
  static Stream<List<SavedPlace>> placesStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .snapshots()
        .map((snapshot) {
          final places = snapshot.docs
              .map((doc) => SavedPlace.fromFirestore(doc))
              .toList();
          places.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return places;
        });
  }

  /// Save a new favorite place (stores both lat/lng and latitude/longitude for compatibility)
  static Future<String> savePlace({
    required String uid,
    required String name,
    required String address,
    String? placeId,
    double? latitude,
    double? longitude,
    String? category,
  }) async {
    final now = FieldValue.serverTimestamp();
    final trimmedPlaceId = placeId?.trim();
    final docRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .add({
      'name': name.trim(),
      'address': address.trim(),
      if (trimmedPlaceId != null && trimmedPlaceId.isNotEmpty)
        'placeId': trimmedPlaceId,
      if (latitude != null) ...{
        'lat': latitude,
        'latitude': latitude,
      },
      if (longitude != null) ...{
        'lng': longitude,
        'longitude': longitude,
      },
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      'addedAt': now,
      'createdAt': now,
    });

    return docRef.id;
  }

  /// Update an existing saved place with resolved coordinates / placeId / category
  static Future<void> enrichSavedPlace({
    required String uid,
    required String docId,
    String? placeId,
    double? latitude,
    double? longitude,
    String? category,
  }) async {
    final updates = <String, dynamic>{};
    if (placeId != null && placeId.trim().isNotEmpty) {
      updates['placeId'] = placeId.trim();
    }
    if (latitude != null) {
      updates['lat'] = latitude;
      updates['latitude'] = latitude;
    }
    if (longitude != null) {
      updates['lng'] = longitude;
      updates['longitude'] = longitude;
    }
    if (category != null && category.trim().isNotEmpty) {
      updates['category'] = category.trim();
    }
    if (updates.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .doc(docId)
        .update(updates);
  }

  /// Find a saved place ID by address or placeId if it exists
  static Future<String?> findPlaceIdByAddress({
    required String uid,
    required String address,
    String? googlePlaceId,
  }) async {
    if (googlePlaceId != null && googlePlaceId.trim().isNotEmpty) {
      final byPlaceId = await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorite_places')
          .where('placeId', isEqualTo: googlePlaceId.trim())
          .limit(1)
          .get();
      if (byPlaceId.docs.isNotEmpty) {
        return byPlaceId.docs.first.id;
      }
    }

    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_places')
        .where('address', isEqualTo: trimmed)
        .limit(1)
        .get();

    return query.docs.isNotEmpty ? query.docs.first.id : null;
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

  /// Fetch full Google Place Details via Cloud Function proxy (with in-memory caching)
  static Future<PlaceDetailsModel?> fetchPlaceDetails({
    String? placeId,
    String? queryFallback,
    String? sessionToken,
    required bool isDark,
  }) async {
    final cacheKey =
        '${placeId ?? queryFallback ?? ''}_${isDark ? 'dark' : 'light'}';
    if (cacheKey.length > 6 && _detailsCache.containsKey(cacheKey)) {
      return _detailsCache[cacheKey];
    }

    final callable = FirebaseFunctions.instance.httpsCallable('placeDetails');
    final result = await callable.call({
      if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
      if (queryFallback != null && queryFallback.isNotEmpty)
        'query': queryFallback,
      if (sessionToken != null && sessionToken.isNotEmpty)
        'sessionToken': sessionToken,
      'isDark': isDark,
      if (_apiKey.isNotEmpty) 'apiKey': _apiKey,
    });

    if (result.data is! Map) return null;
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['status'] == 'OK' && data['details'] is Map) {
      final detailsMap = Map<String, dynamic>.from(data['details'] as Map);
      final model = PlaceDetailsModel.fromMap(detailsMap);
      if (cacheKey.length > 6) {
        _detailsCache[cacheKey] = model;
      }
      return model;
    }
    return null;
  }
}
