import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPlace {
  final String id;
  final String name;
  final String address;
  final DateTime? createdAt;
  final String? placeId;
  final double? lat;
  final double? lng;
  final String? category;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    this.createdAt,
    this.placeId,
    this.lat,
    this.lng,
    this.category,
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
      name: (data['name'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['addedAt'] is Timestamp)
              ? (data['addedAt'] as Timestamp).toDate()
              : null,
      placeId: data['placeId']?.toString(),
      lat: parseDouble(data['lat'] ?? data['latitude']),
      lng: parseDouble(data['lng'] ?? data['longitude']),
      category: data['category']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (placeId != null) 'placeId': placeId,
      if (lat != null) ...{
        'lat': lat,
        'latitude': lat,
      },
      if (lng != null) ...{
        'lng': lng,
        'longitude': lng,
      },
      if (category != null) 'category': category,
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
    String? category,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      placeId: placeId ?? this.placeId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      category: category ?? this.category,
    );
  }
}

/// Unified model for both Google Places Autocomplete predictions and Text Search results.
class PlaceSearchResult {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final List<String> types;
  final int? distanceMeters;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final bool? openNow;
  final double? lat;
  final double? lng;
  final bool isFromTextSearch;

  const PlaceSearchResult({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.types = const [],
    this.distanceMeters,
    this.rating,
    this.userRatingsTotal,
    this.priceLevel,
    this.openNow,
    this.lat,
    this.lng,
    this.isFromTextSearch = false,
  });

  factory PlaceSearchResult.fromAutocomplete(Map<String, dynamic> map) {
    final structured = map['structured_formatting'] is Map
        ? Map<String, dynamic>.from(map['structured_formatting'] as Map)
        : <String, dynamic>{};
    final mainText = (structured['main_text'] ?? map['description'] ?? '')
        .toString()
        .trim();
    final secondaryText = (structured['secondary_text'] ?? '').toString().trim();
    final rawTypes = map['types'] is List ? map['types'] as List : const [];

    return PlaceSearchResult(
      placeId: (map['place_id'] ?? '').toString(),
      mainText: mainText,
      secondaryText: secondaryText,
      types: rawTypes.map((e) => e.toString()).toList(),
      distanceMeters: map['distance_meters'] is num
          ? (map['distance_meters'] as num).toInt()
          : null,
      isFromTextSearch: false,
    );
  }

  factory PlaceSearchResult.fromTextSearch(Map<String, dynamic> map) {
    final name = (map['name'] ?? '').toString().trim();
    final formattedAddress = (map['formatted_address'] ?? '').toString().trim();
    final rawTypes = map['types'] is List ? map['types'] as List : const [];

    return PlaceSearchResult(
      placeId: (map['place_id'] ?? '').toString(),
      mainText: name,
      secondaryText: formattedAddress,
      types: rawTypes.map((e) => e.toString()).toList(),
      distanceMeters: map['distance_meters'] is num
          ? (map['distance_meters'] as num).toInt()
          : null,
      rating: map['rating'] is num ? (map['rating'] as num).toDouble() : null,
      userRatingsTotal: map['user_ratings_total'] is num
          ? (map['user_ratings_total'] as num).toInt()
          : null,
      priceLevel: map['price_level'] is num
          ? (map['price_level'] as num).toInt()
          : null,
      openNow: map['open_now'] is bool ? map['open_now'] as bool : null,
      lat: map['lat'] is num ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] is num ? (map['lng'] as num).toDouble() : null,
      isFromTextSearch: true,
    );
  }

  String get fullSelectionString {
    if (secondaryText.isEmpty) return mainText;
    if (secondaryText.toLowerCase().startsWith(mainText.toLowerCase())) {
      return secondaryText;
    }
    return '$mainText, $secondaryText';
  }

  String? get formattedDistance {
    if (distanceMeters == null || distanceMeters! <= 0) return null;
    final miles = distanceMeters! / 1609.344;
    if (miles < 0.1) return '< 0.1 mi';
    if (miles < 10) return '${miles.toStringAsFixed(1)} mi';
    return '${miles.round()} mi';
  }

  String? get priceLevelLabel => formatPriceLevel(priceLevel);

  String? get primaryCategoryLabel => formatPrimaryCategory(types);

  static String? formatPriceLevel(int? level) {
    if (level == null || level <= 0) return null;
    return r'$' * level.clamp(1, 4);
  }

  static String? formatPrimaryCategory(List<String> types) {
    const ignored = {
      'point_of_interest',
      'establishment',
      'food',
      'store',
      'premise',
      'subpremise',
      'geocode',
      'political',
      'locality',
      'neighborhood',
    };
    const friendlyMap = {
      'restaurant': 'Restaurant',
      'cafe': 'Coffee & Cafe',
      'bakery': 'Bakery',
      'meal_takeaway': 'Takeout',
      'meal_delivery': 'Dining',
      'bar': 'Lounge & Grill',
      'night_club': 'Venue',
      'park': 'Park & Outdoors',
      'natural_feature': 'Outdoors',
      'campground': 'Campground',
      'bowling_alley': 'Bowling',
      'movie_theater': 'Movie Theater',
      'amusement_park': 'Amusement Park',
      'art_gallery': 'Art Gallery',
      'museum': 'Museum',
      'tourist_attraction': 'Attraction',
      'shopping_mall': 'Shopping',
      'book_store': 'Bookstore',
      'Clothing_store': 'Shopping',
      'gym': 'Fitness',
      'spa': 'Spa & Wellness',
      'stadium': 'Stadium & Arena',
      'Aquarium': 'Aquarium',
      'zoo': 'Zoo',
      'street_address': 'Address',
      'route': 'Street',
      'lodging': 'Hotel & Lodging',
      'university': 'Campus',
    };

    for (final raw in types) {
      final t = raw.toLowerCase();
      if (friendlyMap.containsKey(t)) return friendlyMap[t];
    }
    for (final raw in types) {
      final t = raw.toLowerCase();
      if (!ignored.contains(t)) {
        return t
            .split('_')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
      }
    }
    return null;
  }
}

/// Rich details model returned by the `placeDetails` Cloud Function.
class PlaceDetailsModel {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double? lat;
  final double? lng;
  final List<String> types;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final bool? openNow;
  final List<String> weekdayText;
  final String? editorialSummary;
  final String? website;
  final String? phoneNumber;
  final String? googleMapsUrl;
  final String? photoDataUrl;
  final String? staticMapDataUrl;

  const PlaceDetailsModel({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.lat,
    this.lng,
    this.types = const [],
    this.rating,
    this.userRatingsTotal,
    this.priceLevel,
    this.openNow,
    this.weekdayText = const [],
    this.editorialSummary,
    this.website,
    this.phoneNumber,
    this.googleMapsUrl,
    this.photoDataUrl,
    this.staticMapDataUrl,
  });

  factory PlaceDetailsModel.fromMap(Map<String, dynamic> map) {
    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int? parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    final rawTypes = map['types'] is List ? map['types'] as List : const [];
    final rawWeekday =
        map['weekdayText'] is List ? map['weekdayText'] as List : const [];

    return PlaceDetailsModel(
      placeId: (map['placeId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      formattedAddress: (map['formattedAddress'] ?? '').toString(),
      lat: parseDouble(map['lat']),
      lng: parseDouble(map['lng']),
      types: rawTypes.map((e) => e.toString()).toList(),
      rating: parseDouble(map['rating']),
      userRatingsTotal: parseInt(map['userRatingsTotal']),
      priceLevel: parseInt(map['priceLevel']),
      openNow: map['openNow'] is bool ? map['openNow'] as bool : null,
      weekdayText: rawWeekday.map((e) => e.toString()).toList(),
      editorialSummary: map['editorialSummary']?.toString(),
      website: map['website']?.toString(),
      phoneNumber: map['phoneNumber']?.toString(),
      googleMapsUrl: map['googleMapsUrl']?.toString(),
      photoDataUrl: map['photoDataUrl']?.toString(),
      staticMapDataUrl: map['staticMapDataUrl']?.toString(),
    );
  }

  String get fullSelectionString {
    if (formattedAddress.isEmpty) return name;
    if (name.isEmpty ||
        formattedAddress.toLowerCase().startsWith(name.toLowerCase())) {
      return formattedAddress;
    }
    return '$name, $formattedAddress';
  }

  String? get priceLevelLabel => PlaceSearchResult.formatPriceLevel(priceLevel);

  String? get primaryCategoryLabel =>
      PlaceSearchResult.formatPrimaryCategory(types);

  String? get todayHoursText {
    if (weekdayText.isEmpty) return null;
    // DateTime.weekday is 1 (Monday) .. 7 (Sunday)
    final todayIdx = DateTime.now().weekday - 1;
    if (todayIdx >= 0 && todayIdx < weekdayText.length) {
      final line = weekdayText[todayIdx];
      final colonIdx = line.indexOf(':');
      if (colonIdx != -1 && colonIdx + 1 < line.length) {
        return line.substring(colonIdx + 1).trim();
      }
      return line;
    }
    return weekdayText.first;
  }
}
