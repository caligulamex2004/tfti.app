import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/theme_provider.dart';
import '../components/places/goated_place_card.dart';
import 'places_search_page.dart';

class GoatedPlacesPage extends StatefulWidget {
  const GoatedPlacesPage({super.key});

  @override
  State<GoatedPlacesPage> createState() => _GoatedPlacesPageState();
}

class _GoatedPlacesPageState extends State<GoatedPlacesPage> {
  Future<void> _renamePlace(String docId, String currentName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renameController = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
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

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorite_places')
            .doc(docId)
            .update({'name': newName});

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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorite_places')
            .doc(docId)
            .delete();

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
      MaterialPageRoute(builder: (context) => const PlacesSearchPage()),
    );

    if (result != null && result is String && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final parts = result.split(',');
        final name = parts.isNotEmpty ? parts[0] : "Saved Place";

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorite_places')
            .add({
              'name': name,
              'address': result,
              'addedAt': FieldValue.serverTimestamp(),
            });

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Favorite Places",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewPlace,
        backgroundColor: primaryColor,
        foregroundColor: themeProvider.onPrimaryColor,
        icon: const Icon(Icons.add_location_alt),
        label: const Text(
          "Add Place",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorite_places')
            // .orderBy('addedAt', descending: true) // Uncomment if index exists
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading places."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final places = snapshot.data!.docs;

          if (places.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final data = places[index].data() as Map<String, dynamic>;
              final docId = places[index].id;
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
            },
          );
        },
      ),
    );
  }
}
