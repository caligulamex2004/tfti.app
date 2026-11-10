import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shimmer/shimmer.dart';

import '../components/places/place_summary_sheet.dart';
export '../components/places/place_summary_sheet.dart' show PlaceSummaryResult;
import '../models/place_model.dart';
import '../services/place_service.dart';
import '../utils/responsive_layout.dart';
import '../utils/theme_provider.dart';

class _VibePreset {
  final String id;
  final String label;
  final String query;

  const _VibePreset({
    required this.id,
    required this.label,
    required this.query,
  });
}

class PlacesSearchPage extends StatefulWidget {
  final bool showFavorites;
  final Map<String, dynamic>? fallbackLocation;
  final ValueChanged<PlaceSummaryResult>? onPlaceSelected;

  // Defaults to true so it doesn't break the Hangout Editor Page!
  const PlacesSearchPage({
    super.key,
    this.showFavorites = true,
    this.fallbackLocation,
    this.onPlaceSelected,
  });

  @override
  State<PlacesSearchPage> createState() => _PlacesSearchPageState();
}

class _PlacesSearchPageState extends State<PlacesSearchPage> {
  static const List<_VibePreset> _vibePresets = [
    _VibePreset(
      id: 'date_night',
      label: 'Date Night',
      query: 'date night restaurants and cozy spots',
    ),
    _VibePreset(
      id: 'food',
      label: 'Food',
      query: 'popular restaurants and casual dining',
    ),
    _VibePreset(
      id: 'coffee',
      label: 'Coffee & Tea',
      query: 'coffee shops cafes and tea',
    ),
    _VibePreset(
      id: 'activities',
      label: 'Activities',
      query: 'fun group activities bowling mini golf entertainment',
    ),
    _VibePreset(
      id: 'sweet_treats',
      label: 'Sweet Treats',
      query: 'dessert ice cream bakery sweet treats',
    ),
    _VibePreset(
      id: 'outdoors',
      label: 'Outdoors',
      query: 'scenic parks trails and outdoor spots',
    ),
  ];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _uuid = const Uuid();

  List<PlaceSearchResult> _searchResults = [];
  String? _sessionToken;
  Map<String, dynamic>? _fallbackLocation;
  Future<void>? _fallbackInitFuture;
  String? _selectedChipId;
  String? _lastTextSearchQuery;
  bool _isTextSearchMode = false;

  Timer? _debounce;
  bool _isLoading = false;
  String? _error;

  static const String _apiKey = String.fromEnvironment('PLACES_API_KEY');

  @override
  void initState() {
    super.initState();
    _sessionToken = _uuid.v4();
    _fallbackLocation = widget.fallbackLocation;
    _selectedChipId = widget.showFavorites ? 'vip' : null;
    _controller.addListener(_onSearchChanged);
    _fallbackInitFuture = _initFallbackLocationFromSavedPlaces();
  }

  Future<void> _initFallbackLocationFromSavedPlaces() async {
    if (_fallbackLocation != null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final places = await PlaceService.placesStream(user.uid).first;
      for (final place in places) {
        if (place.lat != null && place.lng != null) {
          if (mounted) {
            setState(() {
              _fallbackLocation = {
                'lat': place.lat,
                'lng': place.lng,
              };
            });
          }
          break;
        }
      }
    } catch (_) {
      // Ignored: fallback is optional and used when available
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    final trimmed = _controller.text.trim();

    if (trimmed.isEmpty) {
      setState(() {
        if (_selectedChipId == null && widget.showFavorites) {
          _selectedChipId = 'vip';
        }
        if (_selectedChipId == 'vip' || _selectedChipId == null) {
          _searchResults = [];
          _isLoading = false;
          _error = null;
          _isTextSearchMode = false;
        }
      });
      return;
    }

    // Typing custom text deselects preset chips
    if (_selectedChipId != null) {
      _selectedChipId = null;
    }

    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (_sessionToken == null) {
        setState(() => _sessionToken = _uuid.v4());
      }
      _fetchAutocompleteSuggestions(_controller.text);
    });
    setState(() {});
  }

  bool _looksLikeVibeQuery(String input) {
    final lower = input.toLowerCase().trim();
    const vibeKeywords = [
      'date',
      'spot',
      'best',
      'good',
      'cozy',
      'food',
      'dinner',
      'lunch',
      'brunch',
      'breakfast',
      'coffee',
      'cafe',
      'boba',
      'tea',
      'dessert',
      'ice cream',
      'bakery',
      'park',
      'activity',
      'activities',
      'fun',
      'bowling',
      'arcade',
      'late night',
      'outdoor',
      'patio',
      'tacos',
      'sushi',
      'pizza',
      'ramen',
    ];
    for (final kw in vibeKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  bool _isTransientFunctionError(FirebaseFunctionsException fe) {
    final code = fe.code.toLowerCase();
    return code == 'internal' ||
        code == 'unavailable' ||
        code == 'deadline-exceeded';
  }

  String _friendlyErrorMessage(FirebaseFunctionsException fe) {
    final msg = (fe.message ?? '').trim();
    if (msg.isEmpty ||
        msg.toLowerCase() == 'internal' ||
        fe.code.toLowerCase() == 'internal') {
      return 'Places service is warming up or temporarily busy. Please try again.';
    }
    return msg;
  }

  Future<HttpsCallableResult<dynamic>> _callFunctionWithRetry(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(functionName);
    try {
      return await callable.call(payload);
    } on FirebaseFunctionsException catch (fe) {
      if (_isTransientFunctionError(fe)) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        return await callable.call(payload);
      }
      rethrow;
    }
  }

  Future<void> _fetchAutocompleteSuggestions(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isTextSearchMode = false;
    });

    try {
      if (_fallbackLocation == null && _fallbackInitFuture != null) {
        await _fallbackInitFuture!.timeout(
          const Duration(milliseconds: 450),
          onTimeout: () {},
        );
      }

      final result = await _callFunctionWithRetry('placesAutocomplete', {
        'input': trimmed,
        'sessionToken': _sessionToken ?? '',
        if (_apiKey.isNotEmpty) 'apiKey': _apiKey,
        if (_fallbackLocation != null) 'fallbackLocation': _fallbackLocation,
      });

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      final String status = data['status']?.toString() ?? 'OK';

      // Cache resolved server anchor if we didn't have one yet
      if (_fallbackLocation == null && data['anchor'] is Map) {
        _fallbackLocation = Map<String, dynamic>.from(data['anchor'] as Map);
      }

      if (status == 'OK') {
        final List<dynamic> rawList = data['predictions'] is List
            ? data['predictions'] as List<dynamic>
            : [];
        final parsed = rawList
            .whereType<Map>()
            .map(
              (m) => PlaceSearchResult.fromAutocomplete(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList();

        // If the query reads like a discovery/vibe search and Autocomplete returned very few
        // literal prefix matches, automatically upgrade to Text Search so the user gets rated spots!
        if (parsed.length < 2 &&
            trimmed.length >= 3 &&
            _looksLikeVibeQuery(trimmed)) {
          await _executeTextSearch(trimmed, keepSearchText: true);
          return;
        }

        setState(() {
          _searchResults = parsed;
          _isLoading = false;
        });
      } else if (status == 'ZERO_RESULTS') {
        if (trimmed.length >= 3) {
          await _executeTextSearch(trimmed, keepSearchText: true);
          return;
        }
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error: $status';
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (fe) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyErrorMessage(fe);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _executeTextSearch(
    String query, {
    bool keepSearchText = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _debounce?.cancel();
    _lastTextSearchQuery = trimmed;
    setState(() {
      _isLoading = true;
      _error = null;
      _isTextSearchMode = true;
    });

    try {
      if (_fallbackLocation == null && _fallbackInitFuture != null) {
        await _fallbackInitFuture!.timeout(
          const Duration(milliseconds: 450),
          onTimeout: () {},
        );
      }

      final result = await _callFunctionWithRetry('placesTextSearch', {
        'query': trimmed,
        if (_apiKey.isNotEmpty) 'apiKey': _apiKey,
        if (_fallbackLocation != null) 'fallbackLocation': _fallbackLocation,
      });

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      final String status = data['status']?.toString() ?? 'OK';

      if (_fallbackLocation == null && data['anchor'] is Map) {
        _fallbackLocation = Map<String, dynamic>.from(data['anchor'] as Map);
      }

      if (status == 'OK' || status == 'ZERO_RESULTS') {
        final List<dynamic> rawList = data['results'] is List
            ? data['results'] as List<dynamic>
            : [];
        final parsed = rawList
            .whereType<Map>()
            .map(
              (m) => PlaceSearchResult.fromTextSearch(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList();

        setState(() {
          _searchResults = parsed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error: $status';
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (fe) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyErrorMessage(fe);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _retryLastSearch() {
    HapticFeedback.lightImpact();
    if (_isTextSearchMode &&
        _lastTextSearchQuery != null &&
        _lastTextSearchQuery!.isNotEmpty) {
      _executeTextSearch(_lastTextSearchQuery!, keepSearchText: true);
    } else if (_controller.text.trim().isNotEmpty) {
      _fetchAutocompleteSuggestions(_controller.text);
    } else if (_selectedChipId != null && _selectedChipId != 'vip') {
      for (final preset in _vibePresets) {
        if (preset.id == _selectedChipId) {
          _executeTextSearch(preset.query);
          return;
        }
      }
    }
  }

  void _onVibeChipSelected(String chipId, String? query) {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    if (chipId == 'vip') {
      _debounce?.cancel();
      _controller.removeListener(_onSearchChanged);
      _controller.clear();
      _controller.addListener(_onSearchChanged);
      setState(() {
        _selectedChipId = 'vip';
        _searchResults = [];
        _isLoading = false;
        _error = null;
        _isTextSearchMode = false;
      });
      return;
    }

    // Clear text field without triggering autocomplete listener
    _debounce?.cancel();
    _controller.removeListener(_onSearchChanged);
    _controller.clear();
    _controller.addListener(_onSearchChanged);

    setState(() {
      _selectedChipId = chipId;
    });

    if (query != null) {
      _executeTextSearch(query);
    }
  }

  void _completeWithSelection(PlaceSummaryResult selection) {
    HapticFeedback.mediumImpact();
    widget.onPlaceSelected?.call(selection);
    Navigator.pop(context, selection.selectionString);
  }

  Future<void> _openSummarySheetForResult(PlaceSearchResult item) async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final selected = await PlaceSummarySheet.show(
      context,
      placeId: item.placeId,
      initialName: item.mainText,
      initialAddress: item.secondaryText,
      initialTypes: item.types,
      initialRating: item.rating,
      initialUserRatingsTotal: item.userRatingsTotal,
      initialPriceLevel: item.priceLevel,
      initialOpenNow: item.openNow,
      initialLat: item.lat,
      initialLng: item.lng,
      sessionToken: _sessionToken,
      primaryActionLabel:
          widget.showFavorites ? 'Select This Spot' : 'Add to VIP Places',
      primaryActionIcon: widget.showFavorites
          ? Icons.check_circle_rounded
          : Icons.add_location_alt_rounded,
    );

    // Reset session token after Place Details completes the session
    _sessionToken = _uuid.v4();

    if (selected != null && mounted) {
      _completeWithSelection(selected);
    }
  }

  Future<void> _openSummarySheetForSavedPlace(SavedPlace place) async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    // Decouple private SavedPlace.name from place search/summary sheet.
    // Pass public address info to the search in the background.
    final hasComma = place.address.contains(',');
    final publicName = hasComma
        ? place.address.split(',').first.trim()
        : place.address;

    final selected = await PlaceSummarySheet.show(
      context,
      placeId: place.placeId,
      initialName: publicName,
      initialAddress: place.address,
      initialTypes: place.category != null ? [place.category!] : const [],
      initialLat: place.lat,
      initialLng: place.lng,
      sessionToken: _sessionToken,
      existingSavedDocId: place.id,
      primaryActionLabel: 'Select This Spot',
      primaryActionIcon: Icons.check_circle_rounded,
    );

    _sessionToken = _uuid.v4();

    if (selected != null && mounted) {
      _completeWithSelection(selected);
    }
  }

  Widget _buildVibeChipBar() {
    final chips = <Map<String, String?>>[
      if (widget.showFavorites)
        {'id': 'vip', 'label': 'VIP Places', 'query': null},
      ..._vibePresets.map(
        (v) => {'id': v.id, 'label': v.label, 'query': v.query},
      ),
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          final String id = chip['id']!;
          final String label = chip['label']!;
          final String? query = chip['query'];
          final bool isSelected = _selectedChipId == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected
                      ? themeProvider.pillTextColor
                      : themeProvider.chipUnselectedTextColor,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: themeProvider.pillBackgroundColor,
              backgroundColor: themeProvider.chipUnselectedBackgroundColor,
              side: BorderSide(
                color: isSelected
                    ? themeProvider.pillBackgroundColor
                    : themeProvider.chipBorderColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => _onVibeChipSelected(id, query),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoadingList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
          highlightColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          child: Container(
            height: 82,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesList(bool isDark, Color primaryColor) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) return const SizedBox();

    return StreamBuilder<List<SavedPlace>>(
      stream: PlaceService.placesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoadingList(isDark);
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptySearchPrompt(
            isDark,
            title: 'No VIP Places Saved Yet',
            subtitle:
                'Search for an address or tap a category above to explore local spots.',
          );
        }

        final places = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: places.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final place = places[index];
            final title =
                place.name.isNotEmpty ? place.name : 'Saved VIP Place';
            return _buildResultCard(
              title: title,
              subtitle: place.address,
              icon: Symbols.star,
              iconFill: 1.0,
              iconColor: Colors.amber,
              categoryLabel: place.category,
              isDark: isDark,
              primaryColor: primaryColor,
              onCardTap: () => _openSummarySheetForSavedPlace(place),
              onQuickSelectTap: () => _completeWithSelection(
                PlaceSummaryResult(
                  selectionString: place.address,
                  name: place.address.split(',').first.trim(),
                  address: place.address,
                  placeId: place.placeId,
                  lat: place.lat,
                  lng: place.lng,
                  category: place.category,
                  isVip: true,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptySearchPrompt(
    bool isDark, {
    String title = 'Search or Explore Places',
    String subtitle =
        'Enter an address, venue name, or pick a category above to browse top local spots.',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore_outlined,
                size: 52,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 15.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retryLastSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.pillBackgroundColor,
                foregroundColor: themeProvider.pillTextColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomLocationFallbackCard(
    String customText,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _completeWithSelection(
            PlaceSummaryResult(
              selectionString: customText,
              name: customText,
              address: customText,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_location_alt_outlined,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Use "$customText"',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set as custom location',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreVibeBanner(
    String queryText,
    bool isDark,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            FocusScope.of(context).unfocus();
            _executeTextSearch(queryText, keepSearchText: true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.travel_explore_rounded, size: 18, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Explore top-rated spots for "$queryText"',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Ratings & Hours',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(bool isDark, Color primaryColor) {
    final trimmedQuery = _controller.text.trim();
    final showCustomFallback =
        widget.showFavorites && trimmedQuery.isNotEmpty;
    final showExploreBanner = !_isTextSearchMode &&
        trimmedQuery.length >= 3 &&
        _searchResults.isNotEmpty;

    if (_searchResults.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          if (showCustomFallback) ...[
            _buildCustomLocationFallbackCard(
              trimmedQuery,
              isDark,
              primaryColor,
            ),
            const SizedBox(height: 32),
          ],
          _buildEmptySearchPrompt(
            isDark,
            title: 'No matching places found',
            subtitle: showCustomFallback
                ? 'You can still use your typed text above as a custom spot.'
                : 'Try searching a different name, city, or street address.',
          ),
        ],
      );
    }

    final totalCount = _searchResults.length +
        (showCustomFallback ? 1 : 0) +
        (showExploreBanner ? 1 : 0);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: totalCount,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        int currentIndex = index;

        if (showExploreBanner) {
          if (currentIndex == 0) {
            return _buildExploreVibeBanner(trimmedQuery, isDark, primaryColor);
          }
          currentIndex -= 1;
        }

        if (currentIndex < _searchResults.length) {
          final item = _searchResults[currentIndex];
          final visuals = PlaceCategoryVisuals.fromTypes(
            item.types,
            isDark: isDark,
          );

          return _buildResultCard(
            title: item.mainText,
            subtitle: item.secondaryText,
            icon: visuals.icon,
            iconColor: visuals.color,
            categoryLabel: item.primaryCategoryLabel,
            distanceLabel: item.formattedDistance,
            rating: item.rating,
            ratingsCount: item.userRatingsTotal,
            priceLabel: item.priceLevelLabel,
            openNow: item.openNow,
            isDark: isDark,
            primaryColor: primaryColor,
            onCardTap: () => _openSummarySheetForResult(item),
            onQuickSelectTap: () => _completeWithSelection(
              PlaceSummaryResult(
                selectionString: item.fullSelectionString,
                name: item.mainText,
                address: item.secondaryText,
                placeId: item.placeId,
                lat: item.lat,
                lng: item.lng,
                category: visuals.label,
              ),
            ),
          );
        }

        return _buildCustomLocationFallbackCard(
          trimmedQuery,
          isDark,
          primaryColor,
        );
      },
    );
  }

  Widget _buildResultCard({
    required String title,
    required String subtitle,
    required IconData icon,
    double iconFill = 0.0,
    required Color iconColor,
    String? categoryLabel,
    String? distanceLabel,
    double? rating,
    int? ratingsCount,
    String? priceLabel,
    bool? openNow,
    required bool isDark,
    required Color primaryColor,
    required VoidCallback onCardTap,
    required VoidCallback onQuickSelectTap,
  }) {
    final bool hasRichMeta =
        rating != null || priceLabel != null || openNow != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onCardTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category / Star Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    fill: iconFill,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Main Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (distanceLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                distanceLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (hasRichMeta) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (rating != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  if (ratingsCount != null) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '($ratingsCount)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            if (priceLabel != null)
                              Text(
                                '• $priceLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            if (categoryLabel != null)
                              Text(
                                '• $categoryLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            if (openNow != null)
                              Text(
                                openNow ? '• Open' : '• Closed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: openNow
                                      ? (isDark
                                            ? Colors.greenAccent.shade400
                                            : Colors.green.shade700)
                                      : (isDark
                                            ? Colors.redAccent.shade100
                                            : Colors.red.shade700),
                                ),
                              ),
                          ],
                        ),
                      ],

                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // 1-Tap Quick-Select Button
                Tooltip(
                  message: widget.showFavorites
                      ? 'Quick select'
                      : 'Quick add to VIP Places',
                  child: Material(
                    color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.1),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onQuickSelectTap,
                      child: Padding(
                        padding: const EdgeInsets.all(9.0),
                        child: Icon(
                          widget.showFavorites
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
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

  Widget _buildActiveBody(bool isDark, Color primaryColor) {
    if (_isLoading) {
      return _buildShimmerLoadingList(isDark);
    }
    if (_error != null) {
      return _buildErrorState(isDark);
    }
    if (_selectedChipId == 'vip' && _controller.text.trim().isEmpty) {
      return _buildFavoritesList(isDark, primaryColor);
    }
    if (_controller.text.trim().isEmpty && _selectedChipId == null) {
      return widget.showFavorites
          ? _buildFavoritesList(isDark, primaryColor)
          : _buildEmptySearchPrompt(isDark);
    }
    return _buildResultsList(isDark, primaryColor);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.showFavorites ? 'Find a Spot' : 'Add VIP Place',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CenteredContentColumn(
        maxWidth: 860,
        child: Column(
          children: [
            // Search Input Container
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    _executeTextSearch(val, keepSearchText: true);
                  }
                },
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Search address, venue, or vibe (e.g. date spot)...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    fontSize: 14.5,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: primaryColor.withValues(alpha: 0.7),
                      width: 1.8,
                    ),
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.cancel_rounded,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                          ),
                          onPressed: () {
                            _debounce?.cancel();
                            _controller.clear();
                            setState(() {
                              _searchResults = [];
                              _error = null;
                              _isTextSearchMode = false;
                              _selectedChipId =
                                  widget.showFavorites ? 'vip' : null;
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Persistent Horizontal Vibe Discovery Chip Bar (no emojis)
            _buildVibeChipBar(),

            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
            ),

            // Results / Favorites / Shimmer Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildActiveBody(isDark, primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
