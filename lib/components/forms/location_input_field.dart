import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'custom_input_field.dart';
import '../../pages/places_search_page.dart';
import '../../services/place_service.dart';

class LocationInputField extends StatefulWidget {
  final TextEditingController controller;
  final bool isPast;

  const LocationInputField({
    super.key,
    required this.controller,
    required this.isPast,
  });

  @override
  State<LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<LocationInputField> {
  bool _isLocFavorite = false;
  String? _favoriteDocId;
  PlaceSummaryResult? _lastSelectedPlace;

  @override
  void initState() {
    super.initState();
    // If the controller already has text (e.g. editing an event), check if it's favorited
    if (widget.controller.text.isNotEmpty) {
      _checkFavoriteStatus();
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.controller.text.isEmpty) {
      return;
    }

    final placeId = await PlaceService.findPlaceIdByAddress(
      uid: user.uid,
      address: widget.controller.text,
      googlePlaceId: _lastSelectedPlace?.placeId,
    );

    if (mounted) {
      setState(() {
        _isLocFavorite = placeId != null;
        _favoriteDocId = placeId;
      });
    }
  }

  Future<void> _toggleFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.controller.text.isEmpty) {
      return;
    }

    HapticFeedback.lightImpact();

    if (_isLocFavorite && _favoriteDocId != null) {
      await PlaceService.deletePlace(uid: user.uid, placeId: _favoriteDocId!);

      if (!mounted) return;
      setState(() {
        _isLocFavorite = false;
        _favoriteDocId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Removed from VIP Places")));
    } else {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final defaultName = widget.controller.text.split(',').first;
      final nameController = TextEditingController(text: defaultName);

      final String? confirmedName;
      try {
        confirmedName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Save VIP Place"),
            content: TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "Give this spot a name...",
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Text(
                  "Save",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      } finally {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          nameController.dispose();
        });
      }

      if (confirmedName == null || confirmedName.isEmpty) {
        return;
      }

      final placeId = await PlaceService.savePlace(
        uid: user.uid,
        name: confirmedName,
        address: widget.controller.text,
        placeId: _lastSelectedPlace?.placeId,
        latitude: _lastSelectedPlace?.lat,
        longitude: _lastSelectedPlace?.lng,
        category: _lastSelectedPlace?.category,
      );

      if (!mounted) return;
      setState(() {
        _isLocFavorite = true;
        _favoriteDocId = placeId;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Added to VIP Places!")));
    }
  }

  Future<void> _selectLocation() async {
    PlaceSummaryResult? richSelection;
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlacesSearchPage(
          showFavorites: true,
          onPlaceSelected: (sel) => richSelection = sel,
        ),
      ),
    );
    if (selectedAddress != null && mounted) {
      setState(() {
        _lastSelectedPlace = richSelection;
        widget.controller.text = selectedAddress;
        if (richSelection?.isVip ?? false) {
          _isLocFavorite = true;
        }
      });
      _checkFavoriteStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: CustomInputField(
            controller: widget.controller,
            label: "Location",
            hint: "Tap to search address...",
            prefixIcon: Icons.location_on,
            prefixIconColor: isDark ? Colors.redAccent : Colors.red,
            readOnly: true,
            enabled: !widget.isPast,
            onTap: widget.isPast ? null : _selectLocation,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
        ),
        if (widget.controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: Icon(
                Symbols.star,
                fill: _isLocFavorite ? 1.0 : 0.0,
                color: Colors.amber,
                size: 32,
              ),
              onPressed: widget.isPast ? null : _toggleFavoriteStatus,
            ),
          ),
      ],
    );
  }
}
