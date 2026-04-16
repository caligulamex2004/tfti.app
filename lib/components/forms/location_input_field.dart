import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'custom_input_field.dart';
import '../../pages/places_search_page.dart';

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

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorite_places')
        .where('address', isEqualTo: widget.controller.text)
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        _isLocFavorite = query.docs.isNotEmpty;
        _favoriteDocId = query.docs.isNotEmpty ? query.docs.first.id : null;
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorite_places')
          .doc(_favoriteDocId)
          .delete();

      setState(() {
        _isLocFavorite = false;
        _favoriteDocId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removed from Goated Places")),
        );
      }
    } else {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final defaultName = widget.controller.text.split(',').first;
      final nameController = TextEditingController(text: defaultName);

      final confirmedName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Save Goated Place"),
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

      if (confirmedName == null || confirmedName.isEmpty) {
        return;
      }

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorite_places')
          .add({
            'name': confirmedName,
            'address': widget.controller.text,
            'createdAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _isLocFavorite = true;
        _favoriteDocId = docRef.id;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Added to Goated Places! 🐐")),
        );
      }
    }
  }

  Future<void> _selectLocation() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlacesSearchPage(showFavorites: true),
      ),
    );
    if (selectedAddress != null && mounted) {
      setState(() {
        widget.controller.text = selectedAddress;
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
                _isLocFavorite ? Icons.star : Icons.star_border,
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
