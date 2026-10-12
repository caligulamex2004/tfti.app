import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../components/shared/shared_sliver_app_bar.dart';
import '../components/places/goated_place_card.dart';
import '../services/place_service.dart';
import 'places_search_page.dart';

class SavedPlacesPage extends StatefulWidget {
  const SavedPlacesPage({super.key});

  @override
  State<SavedPlacesPage> createState() => _SavedPlacesPageState();
}

class _SavedPlacesPageState extends State<SavedPlacesPage> {
  // State for sorting
  bool _sortAlphabetically = true;

  Future<void> _renamePlace(String docId, String currentName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renameController = TextEditingController(text: currentName);

    final String? newName;
    try {
      newName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Rename Place"),
          content: TextField(
            controller: renameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: "Enter new name",
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
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, renameController.text.trim()),
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
      renameController.dispose();
    }

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await PlaceService.renamePlace(
          uid: user.uid,
          placeId: docId,
          newName: newName,
        );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Renamed to '$newName'")));
        }
      }
    }
  }

  Future<void> _deletePlace(String docId, String placeName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Favorite?"),
        content: Text("Remove '$placeName' from your favorite places?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.redAccent : Colors.red,
            ),
            child: const Text(
              "Remove",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await PlaceService.deletePlace(
          uid: user.uid,
          placeId: docId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("'$placeName' removed from Goated Places")),
          );
        }
      }
    }
  }

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);

    final Uri url = Platform.isIOS
        ? Uri.parse("https://maps.apple.com/?q=$query")
        : Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open the map application.")),
        );
      }
    }
  }

  Future<void> _addNewPlace() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlacesSearchPage(showFavorites: false),
      ),
    );

    if (result != null && result is String && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final parts = result.split(',');
        final name = parts.isNotEmpty ? parts[0] : "Saved Place";

        await PlaceService.savePlace(
          uid: user.uid,
          name: name,
          address: result,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Added to Goated Places!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorite_places')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading places."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawDocs = snapshot.data!.docs;

          // --- Client-side sorting logic ---
          List<Map<String, dynamic>> sortedPlaces = rawDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Inject ID for the card
            return data;
          }).toList();

          if (_sortAlphabetically) {
            sortedPlaces.sort(
              (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              ),
            );
          } else {
            // Sort by newest first
            sortedPlaces.sort((a, b) {
              final tA = a['addedAt'] as Timestamp?;
              final tB = b['addedAt'] as Timestamp?;
              if (tA == null && tB == null) return 0;
              if (tA == null) return 1;
              if (tB == null) return -1;
              return tB.compareTo(tA);
            });
          }

          return CustomScrollView(
            slivers: [
              SharedSliverAppBar(
                title: "Favorite Places",
                collapsedTitle: "Favorite Places",
                expandedHeight: isLandscape ? 56.0 : 200.0,
                hasBackButton: ModalRoute.of(context)?.canPop ?? false,
                actions: [
                  Padding(
                    padding: EdgeInsets.only(
                      right: isLandscape ? 4.0 : 16.0,
                    ),
                    child: Center(
                      child: InkWell(
                        onTap: _addNewPlace,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_location_alt, color: primaryColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "Add",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                bottomContent: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: primaryColor.withValues(alpha: 0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${sortedPlaces.length} Saved",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (!isLandscape && sortedPlaces.isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _sortAlphabetically = !_sortAlphabetically);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortAlphabetically ? Icons.sort_by_alpha : Icons.access_time,
                                size: 14,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortAlphabetically ? "A-Z" : "Newest",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (sortedPlaces.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star_border,
                            size: 64,
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No Goated Places Yet",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Save your favorite hangout spots here!",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (sortedPlaces.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data = sortedPlaces[index];
                      final docId = data['id'];
                      final name = data['name'] ?? 'Unknown Place';
                      final address = data['address'] ?? '';

                      return GoatedPlaceCard(
                        id: docId,
                        name: name,
                        address: address,
                        onTap: () => _openMap(address),
                        onRename: () => _renamePlace(docId, name),
                        onDelete: () => _deletePlace(docId, name),
                      );
                    }, childCount: sortedPlaces.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
