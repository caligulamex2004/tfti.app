import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme_provider.dart';

class PlacesSearchPage extends StatefulWidget {
  final bool showFavorites;

  // Defaults to true so it doesn't break the Hangout Editor Page!
  const PlacesSearchPage({super.key, this.showFavorites = true});

  @override
  State<PlacesSearchPage> createState() => _PlacesSearchPageState();
}

class _PlacesSearchPageState extends State<PlacesSearchPage> {
  final _controller = TextEditingController();
  List<dynamic> _placePredictions = [];
  final _uuid = const Uuid();
  String? _sessionToken;

  final String _apiKey = "REDACTED_GOOGLE_API_KEY";

  @override
  void initState() {
    super.initState();
    _sessionToken = _uuid.v4();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_sessionToken == null) {
      setState(() => _sessionToken = _uuid.v4());
    }
    _fetchSuggestions(_controller.text);
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _placePredictions = []);
      return;
    }

    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_apiKey&sessiontoken=$_sessionToken";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _placePredictions = data['predictions'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching maps data: $e");
    }
  }

  Widget _buildFavoritesList(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorite_places')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptySearchPrompt(isDark);
        }

        final places = snapshot.data!.docs;
        return ListView.builder(
          itemCount: places.length,
          itemBuilder: (context, index) {
            final data = places[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.star, color: Colors.amber, size: 28),
              title: Text(
                data['name'] ?? 'Favorite Place',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                data['address'] ?? '',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(context, data['address']);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptySearchPrompt(bool isDark) {
    return Center(
      child: Text(
        "Search for an address above.",
        style: TextStyle(
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildPredictionsList(bool isDark) {
    return ListView.builder(
      itemCount: _placePredictions.length,
      itemBuilder: (context, index) {
        final place = _placePredictions[index];
        final mainText = place['structured_formatting']['main_text'];
        final secondaryText =
            place['structured_formatting']['secondary_text'] ?? "";

        return ListTile(
          leading: Icon(
            Icons.location_on,
            color: isDark ? Colors.redAccent : Colors.red,
          ),
          title: Text(
            mainText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            secondaryText,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          onTap: () {
            Navigator.pop(context, "$mainText, $secondaryText");
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Search Places"),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: themeProvider.appGradient),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "e.g. Starbucks, Central Park",
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _placePredictions = []);
                  },
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
          Expanded(
            child: _controller.text.isEmpty
                ? (widget.showFavorites
                      ? _buildFavoritesList(isDark)
                      : _buildEmptySearchPrompt(isDark))
                : _buildPredictionsList(isDark),
          ),
        ],
      ),
    );
  }
}
