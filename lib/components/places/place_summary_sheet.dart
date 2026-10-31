import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/place_model.dart';
import '../../services/place_service.dart';
import '../../utils/theme_provider.dart';

/// Shared helper to map Google Place `types` or category strings to crisp Material icons & colors.
class PlaceCategoryVisuals {
  final IconData icon;
  final Color color;
  final String label;

  const PlaceCategoryVisuals({
    required this.icon,
    required this.color,
    required this.label,
  });

  static PlaceCategoryVisuals fromTypes(
    List<String> types, {
    String? fallbackCategory,
    required bool isDark,
  }) {
    final normalized = <String>[
      ...types.map((e) => e.toLowerCase()),
      if (fallbackCategory != null && fallbackCategory.isNotEmpty)
        fallbackCategory.toLowerCase(),
    ];

    bool matchesAny(List<String> keys) {
      for (final t in normalized) {
        for (final k in keys) {
          if (t.contains(k)) return true;
        }
      }
      return false;
    }

    if (matchesAny(['cafe', 'coffee', 'tea'])) {
      return const PlaceCategoryVisuals(
        icon: Icons.local_cafe_rounded,
        color: Color(0xFFD97706),
        label: 'Coffee & Tea',
      );
    }
    if (matchesAny(['bakery', 'ice_cream', 'sweet', 'dessert'])) {
      return const PlaceCategoryVisuals(
        icon: Icons.icecream_rounded,
        color: Color(0xFFEC4899),
        label: 'Sweet Treats',
      );
    }
    if (matchesAny(['restaurant', 'food', 'meal', 'dining', 'bar'])) {
      return const PlaceCategoryVisuals(
        icon: Icons.restaurant_rounded,
        color: Color(0xFFEA580C),
        label: 'Food & Dining',
      );
    }
    if (matchesAny([
      'bowling',
      'movie',
      'amusement',
      'arcade',
      'museum',
      'art_gallery',
      'stadium',
      'tourist_attraction',
      'aquarium',
      'zoo',
    ])) {
      return const PlaceCategoryVisuals(
        icon: Icons.attractions_rounded,
        color: Color(0xFF8B5CF6),
        label: 'Activity & Venue',
      );
    }
    if (matchesAny(['park', 'natural_feature', 'campground', 'beach', 'trail'])) {
      return const PlaceCategoryVisuals(
        icon: Icons.park_rounded,
        color: Color(0xFF10B981),
        label: 'Outdoors & Park',
      );
    }
    if (matchesAny(['shopping', 'book_store', 'clothing', 'mall'])) {
      return const PlaceCategoryVisuals(
        icon: Icons.shopping_bag_rounded,
        color: Color(0xFF3B82F6),
        label: 'Shopping',
      );
    }
    if (matchesAny(['gym', 'spa', 'health', 'fitness'])) {
      return const PlaceCategoryVisuals(
        icon: Icons.fitness_center_rounded,
        color: Color(0xFF14B8A6),
        label: 'Wellness & Fitness',
      );
    }
    if (matchesAny(['lodging', 'hotel'])) {
      return const PlaceCategoryVisuals(
        icon: Icons.hotel_rounded,
        color: Color(0xFF6366F1),
        label: 'Hotel & Stay',
      );
    }

    return PlaceCategoryVisuals(
      icon: Icons.location_on_rounded,
      color: isDark ? Colors.redAccent : const Color(0xFFE11D48),
      label: PlaceSearchResult.formatPrimaryCategory(types) ??
          fallbackCategory ??
          'Location',
    );
  }
}

class PlaceSummaryResult {
  final String selectionString;
  final String name;
  final String address;
  final String? placeId;
  final double? lat;
  final double? lng;
  final String? category;
  final bool isVip;

  const PlaceSummaryResult({
    required this.selectionString,
    required this.name,
    required this.address,
    this.placeId,
    this.lat,
    this.lng,
    this.category,
    this.isVip = false,
  });
}

class PlaceSummarySheet extends StatefulWidget {
  final String? placeId;
  final String initialName;
  final String initialAddress;
  final List<String> initialTypes;
  final double? initialRating;
  final int? initialUserRatingsTotal;
  final int? initialPriceLevel;
  final bool? initialOpenNow;
  final double? initialLat;
  final double? initialLng;
  final String? sessionToken;
  final String? primaryActionLabel;
  final IconData primaryActionIcon;
  final String? existingSavedDocId;

  const PlaceSummarySheet({
    super.key,
    this.placeId,
    required this.initialName,
    required this.initialAddress,
    this.initialTypes = const [],
    this.initialRating,
    this.initialUserRatingsTotal,
    this.initialPriceLevel,
    this.initialOpenNow,
    this.initialLat,
    this.initialLng,
    this.sessionToken,
    this.primaryActionLabel,
    this.primaryActionIcon = Icons.check_circle_rounded,
    this.existingSavedDocId,
  });

  static Future<PlaceSummaryResult?> show(
    BuildContext context, {
    String? placeId,
    required String initialName,
    required String initialAddress,
    List<String> initialTypes = const [],
    double? initialRating,
    int? initialUserRatingsTotal,
    int? initialPriceLevel,
    bool? initialOpenNow,
    double? initialLat,
    double? initialLng,
    String? sessionToken,
    String? primaryActionLabel = 'Select This Spot',
    IconData primaryActionIcon = Icons.check_circle_rounded,
    String? existingSavedDocId,
  }) {
    return showModalBottomSheet<PlaceSummaryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PlaceSummarySheet(
        placeId: placeId,
        initialName: initialName,
        initialAddress: initialAddress,
        initialTypes: initialTypes,
        initialRating: initialRating,
        initialUserRatingsTotal: initialUserRatingsTotal,
        initialPriceLevel: initialPriceLevel,
        initialOpenNow: initialOpenNow,
        initialLat: initialLat,
        initialLng: initialLng,
        sessionToken: sessionToken,
        primaryActionLabel: primaryActionLabel,
        primaryActionIcon: primaryActionIcon,
        existingSavedDocId: existingSavedDocId,
      ),
    );
  }

  @override
  State<PlaceSummarySheet> createState() => _PlaceSummarySheetState();
}

class _PlaceSummarySheetState extends State<PlaceSummarySheet> {
  PlaceDetailsModel? _details;
  bool _isLoadingDetails = true;
  bool _hoursExpanded = false;

  bool _isSavedVip = false;
  String? _savedDocId;
  bool _isSavingVip = false;

  Uint8List? _decodedPhotoBytes;
  Uint8List? _decodedMapBytes;

  @override
  void initState() {
    super.initState();
    _savedDocId = widget.existingSavedDocId;
    _isSavedVip = widget.existingSavedDocId != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetailsAndFavoriteState();
    });
  }

  Uint8List? _decodeDataUrl(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:')) return null;
    final commaIdx = dataUrl.indexOf(',');
    if (commaIdx == -1 || commaIdx + 1 >= dataUrl.length) return null;
    try {
      return base64Decode(dataUrl.substring(commaIdx + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadDetailsAndFavoriteState() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    // 1. Check VIP saved state in parallel if not already known
    final favFuture = (user != null && _savedDocId == null)
        ? PlaceService.findPlaceIdByAddress(
            uid: user.uid,
            address: _currentSelectionString,
            googlePlaceId: widget.placeId,
          )
        : Future<String?>.value(_savedDocId);

    // 2. Fetch Google Place Details via Cloud Function
    final queryFallback =
        '${widget.initialName} ${widget.initialAddress}'.trim();
    final detailsFuture = PlaceService.fetchPlaceDetails(
      placeId: widget.placeId,
      queryFallback: queryFallback,
      sessionToken: widget.sessionToken,
      isDark: isDark,
    ).catchError((_) => null);

    final results = await Future.wait([favFuture, detailsFuture]);
    if (!mounted) return;

    final resolvedDocId = results[0] as String?;
    final loadedDetails = results[1] as PlaceDetailsModel?;

    final photoBytes = _decodeDataUrl(loadedDetails?.photoDataUrl);
    final mapBytes = _decodeDataUrl(loadedDetails?.staticMapDataUrl);

    setState(() {
      _savedDocId = resolvedDocId ?? _savedDocId;
      _isSavedVip = _savedDocId != null;
      _details = loadedDetails;
      _decodedPhotoBytes = photoBytes;
      _decodedMapBytes = mapBytes;
      _isLoadingDetails = false;
    });

    // If this place is already in the user's VIP Places, backfill its lat/lng/placeId
    // so future searches use it as an accurate geo anchor!
    if (user != null && _savedDocId != null && loadedDetails != null) {
      PlaceService.enrichSavedPlace(
        uid: user.uid,
        docId: _savedDocId!,
        placeId: loadedDetails.placeId,
        latitude: loadedDetails.lat,
        longitude: loadedDetails.lng,
        category: loadedDetails.primaryCategoryLabel,
      ).catchError((_) {});
    }
  }

  String get _currentName =>
      (_details?.name.isNotEmpty ?? false) ? _details!.name : widget.initialName;

  String get _currentAddress => (_details?.formattedAddress.isNotEmpty ?? false)
      ? _details!.formattedAddress
      : widget.initialAddress;

  String get _currentSelectionString {
    if (_details != null) return _details!.fullSelectionString;
    if (widget.initialAddress.isEmpty) return widget.initialName;
    if (widget.initialName.isEmpty ||
        widget.initialAddress
            .toLowerCase()
            .startsWith(widget.initialName.toLowerCase())) {
      return widget.initialAddress;
    }
    return '${widget.initialName}, ${widget.initialAddress}';
  }

  double? get _currentLat => _details?.lat ?? widget.initialLat;
  double? get _currentLng => _details?.lng ?? widget.initialLng;

  List<String> get _currentTypes =>
      (_details?.types.isNotEmpty ?? false) ? _details!.types : widget.initialTypes;

  double? get _currentRating => _details?.rating ?? widget.initialRating;
  int? get _currentRatingsTotal =>
      _details?.userRatingsTotal ?? widget.initialUserRatingsTotal;
  int? get _currentPriceLevel => _details?.priceLevel ?? widget.initialPriceLevel;
  bool? get _currentOpenNow => _details?.openNow ?? widget.initialOpenNow;

  Future<void> _openExternalMaps() async {
    HapticFeedback.lightImpact();
    final googleUrl = _details?.googleMapsUrl;
    final query = Uri.encodeComponent(_currentSelectionString);

    Uri targetUri;
    if (!kIsWeb &&
        Theme.of(context).platform == TargetPlatform.iOS &&
        _currentLat != null &&
        _currentLng != null) {
      targetUri = Uri.parse(
        'https://maps.apple.com/?q=$query&ll=${_currentLat!},${_currentLng!}',
      );
    } else if (googleUrl != null && googleUrl.isNotEmpty) {
      targetUri = Uri.parse(googleUrl);
    } else {
      targetUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }

    try {
      if (!await launchUrl(targetUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(targetUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps application.')),
        );
      }
    }
  }

  Future<void> _launchExternalUri(String rawUrl) async {
    HapticFeedback.lightImpact();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _toggleVipStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSavingVip) return;

    HapticFeedback.lightImpact();
    setState(() => _isSavingVip = true);

    try {
      if (_isSavedVip && _savedDocId != null) {
        await PlaceService.deletePlace(uid: user.uid, placeId: _savedDocId!);
        if (!mounted) return;
        setState(() {
          _isSavedVip = false;
          _savedDocId = null;
          _isSavingVip = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from VIP Places')),
        );
      } else {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final categoryVisuals = PlaceCategoryVisuals.fromTypes(
          _currentTypes,
          isDark: isDark,
        );
        final docId = await PlaceService.savePlace(
          uid: user.uid,
          name: _currentName.isNotEmpty
              ? _currentName
              : _currentSelectionString.split(',').first,
          address: _currentSelectionString,
          placeId: _details?.placeId ?? widget.placeId,
          latitude: _currentLat,
          longitude: _currentLng,
          category: categoryVisuals.label,
        );
        if (!mounted) return;
        setState(() {
          _isSavedVip = true;
          _savedDocId = docId;
          _isSavingVip = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Added to VIP Places',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingVip = false);
      }
    }
  }

  void _confirmSelection() {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryVisuals = PlaceCategoryVisuals.fromTypes(
      _currentTypes,
      isDark: isDark,
    );
    Navigator.pop(
      context,
      PlaceSummaryResult(
        selectionString: _currentSelectionString,
        name: _currentName,
        address: _currentAddress,
        placeId: _details?.placeId ?? widget.placeId,
        lat: _currentLat,
        lng: _currentLng,
        category: categoryVisuals.label,
        isVip: _isSavedVip,
      ),
    );
  }

  Widget _buildVisualHeader(bool isDark, Color primaryColor) {
    if (_isLoadingDetails) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        highlightColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                height: 148,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Container(
                height: 148,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasPhoto = _decodedPhotoBytes != null;

    if (hasPhoto) {
      return SizedBox(
        height: 152,
        child: Row(
          children: [
            // Place Photo
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      _decodedPhotoBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_camera_outlined,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Static Map Pin Thumbnail
            Expanded(
              flex: 4,
              child: _buildMapThumbnailCard(isDark, primaryColor),
            ),
          ],
        ),
      );
    }

    // Fallback when no Place Photo exists: Full-width Map Preview Banner
    return SizedBox(
      height: 144,
      width: double.infinity,
      child: _buildMapThumbnailCard(isDark, primaryColor),
    );
  }

  Widget _buildMapThumbnailCard(bool isDark, Color primaryColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openExternalMaps,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_decodedMapBytes != null)
                  Image.memory(
                    _decodedMapBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                else
                  _StylizedMapPreview(
                    isDark: isDark,
                    primaryColor: primaryColor,
                    subtitle: _currentAddress,
                  ),
                // Subtle bottom gradient for badge legibility
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Open Maps',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 10,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? activeColor,
    bool isActive = false,
  }) {
    final borderColor = isActive && activeColor != null
        ? activeColor.withValues(alpha: 0.5)
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final bgColor = isActive && activeColor != null
        ? activeColor.withValues(alpha: 0.14)
        : (isDark ? Colors.grey.shade900 : Colors.white);
    final fgColor = isActive && activeColor != null
        ? activeColor
        : (isDark ? Colors.white : Colors.black87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final categoryVisuals = PlaceCategoryVisuals.fromTypes(
      _currentTypes,
      isDark: isDark,
    );

    final rating = _currentRating;
    final ratingsCount = _currentRatingsTotal;
    final priceLabel = PlaceSearchResult.formatPriceLevel(_currentPriceLevel);
    final openNow = _currentOpenNow;
    final editorial = _details?.editorialSummary;
    final todayHours = _details?.todayHoursText;
    final weekdayList = _details?.weekdayText ?? const [];

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Title Row + VIP Star Toggle
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: categoryVisuals.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            categoryVisuals.icon,
                            color: categoryVisuals.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentName.isNotEmpty
                                    ? _currentName
                                    : _currentAddress,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Summary Badges Row (Rating, Price, Category, Open Now)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (rating != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.amber.shade300
                                                  : Colors.amber.shade900,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                          if (ratingsCount != null) ...[
                                            const SizedBox(width: 3),
                                            Text(
                                              '($ratingsCount)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  if (priceLabel != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        priceLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: categoryVisuals.color.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      categoryVisuals.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: categoryVisuals.color,
                                      ),
                                    ),
                                  ),
                                  if (openNow != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (openNow
                                                ? Colors.green
                                                : Colors.redAccent)
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        openNow ? 'Open Now' : 'Closed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: openNow
                                              ? (isDark
                                                    ? Colors.greenAccent.shade400
                                                    : Colors.green.shade700)
                                              : (isDark
                                                    ? Colors.redAccent.shade100
                                                    : Colors.red.shade700),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _isSavedVip
                              ? 'Remove from VIP Places'
                              : 'Save to VIP Places',
                          onPressed: _toggleVipStatus,
                          icon: Icon(
                            Symbols.star,
                            fill: _isSavedVip ? 1.0 : 0.0,
                            color: _isSavedVip
                                ? Colors.amber
                                : (isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400),
                            size: 28,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 2. Visual Header (Place Photo + Static Map Pin Thumbnail)
                    _buildVisualHeader(isDark, primaryColor),

                    // 3. Editorial Summary (Google Maps vibe blurb)
                    if (editorial != null && editorial.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(
                            alpha: isDark ? 0.12 : 0.07,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          editorial.trim(),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: isDark
                                ? Colors.grey.shade200
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // 4. Info Card (Address + Hours)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Address row
                          InkWell(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                              bottom: Radius.circular(16),
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(
                                ClipboardData(text: _currentSelectionString),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Address copied to clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _currentAddress.isNotEmpty
                                          ? _currentAddress
                                          : _currentSelectionString,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Hours row (if available)
                          if (todayHours != null) ...[
                            Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                            InkWell(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(16),
                              ),
                              onTap: weekdayList.length > 1
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setState(
                                        () => _hoursExpanded = !_hoursExpanded,
                                      );
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 18,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Today: $todayHours',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.grey.shade200
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                        if (weekdayList.length > 1)
                                          Icon(
                                            _hoursExpanded
                                                ? Icons.expand_less_rounded
                                                : Icons.expand_more_rounded,
                                            size: 18,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                      ],
                                    ),
                                    if (_hoursExpanded &&
                                        weekdayList.length > 1) ...[
                                      const SizedBox(height: 8),
                                      ...weekdayList.map(
                                        (line) => Padding(
                                          padding: const EdgeInsets.only(
                                            left: 28,
                                            top: 3,
                                          ),
                                          child: Text(
                                            line,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 5. Quick Actions Scroll Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickActionPill(
                            icon: _isSavedVip
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            label: _isSavedVip ? 'VIP Saved' : 'Save VIP',
                            onTap: _toggleVipStatus,
                            isDark: isDark,
                            activeColor: Colors.amber,
                            isActive: _isSavedVip,
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionPill(
                            icon: Icons.directions_outlined,
                            label: 'Open in Maps',
                            onTap: _openExternalMaps,
                            isDark: isDark,
                          ),
                          if (_details?.website != null &&
                              _details!.website!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildQuickActionPill(
                              icon: Icons.language_rounded,
                              label: 'Website',
                              onTap: () =>
                                  _launchExternalUri(_details!.website!),
                              isDark: isDark,
                            ),
                          ],
                          if (_details?.phoneNumber != null &&
                              _details!.phoneNumber!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildQuickActionPill(
                              icon: Icons.call_outlined,
                              label: _details!.phoneNumber!,
                              onTap: () => _launchExternalUri(
                                'tel:${_details!.phoneNumber!}',
                              ),
                              isDark: isDark,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 6. Primary CTA Button (Select This Spot / Add to VIP Places)
                    if (widget.primaryActionLabel != null) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _confirmSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.pillBackgroundColor,
                            foregroundColor: themeProvider.pillTextColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(widget.primaryActionIcon, size: 20),
                          label: Text(
                            widget.primaryActionLabel!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stylized Google-Maps-inspired vector road & pin preview used when Static Maps API
/// image bytes aren't returned (or while offline), ensuring the Map Thumbnail always looks crisp.
class _StylizedMapPreview extends StatelessWidget {
  final bool isDark;
  final Color primaryColor;
  final String subtitle;

  const _StylizedMapPreview({
    required this.isDark,
    required this.primaryColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapGridPainter(isDark: isDark, primaryColor: primaryColor),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool isDark;
  final Color primaryColor;

  const _MapGridPainter({
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF172234) : const Color(0xFFEBF1F5);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Park / greenery accent block
    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF1A332A) : const Color(0xFFD6ECD9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.12, size.width * 0.28, size.height * 0.42),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Minor roads
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF283952) : Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.32),
      Offset(size.width, size.height * 0.26),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.72),
      Offset(size.width, size.height * 0.68),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.36, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, 0),
      Offset(size.width * 0.66, size.height),
      roadPaint,
    );

    // Arterial road
    final mainRoadPaint = Paint()
      ..color = isDark
          ? primaryColor.withValues(alpha: 0.35)
          : const Color(0xFFFDE68A)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.52),
      Offset(size.width, size.height * 0.46),
      mainRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.primaryColor != primaryColor;
  }
}
