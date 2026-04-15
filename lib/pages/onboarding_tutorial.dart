import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_provider.dart';

class OnboardingTutorial extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingTutorial({super.key, required this.onComplete});

  @override
  State<OnboardingTutorial> createState() => _OnboardingTutorialState();
}

class _OnboardingTutorialState extends State<OnboardingTutorial> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 7;

  Future<void> _finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
    widget.onComplete();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black87, // Semi-transparent overlay feel
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR: SKIP BUTTON
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishTutorial,
                child: const Text(
                  "Skip Tutorial",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),

            // MAIN CAROUSEL
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildSlide1(isDark),
                  _buildSlide2(primaryColor),
                  _buildSlide3(primaryColor, isDark),
                  _buildSlide4(primaryColor),
                  _buildSlide5(primaryColor, isDark),
                  _buildSlide6(primaryColor),
                  _buildSlide7(primaryColor, isDark),
                ],
              ),
            ),

            // BOTTOM BAR: DOTS & NEXT BUTTON
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Progress Dots
                  Row(
                    children: List.generate(
                      _totalPages,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? primaryColor
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next / Let's Go Button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: themeProvider.onPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _currentPage == _totalPages - 1 ? "Let's Go!" : "Next",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SLIDE 1: Welcome ---
  Widget _buildSlide1(bool isDark) {
    return _TutorialCard(
      title: "Welcome to TFTI!",
      description:
          "Thanks For The Invite! The app that lets all your friends know what you're up to and invites them to join you.",
      child: Center(
        child: Icon(
          Symbols.diversity_2,
          size: 120,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // --- SLIDE 2: Add Friends Navigation ---
  Widget _buildSlide2(Color primaryColor) {
    return _TutorialCard(
      title: "1. Build Your Squad",
      description:
          "First things first, let's get your friends on board. Tap the Squad icon at the bottom of your screen.",
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.home, color: Colors.grey, size: 30),
                const Icon(
                  Icons.supervised_user_circle,
                  color: Colors.grey,
                  size: 30,
                ),
                // Highlighted Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.people, color: primaryColor, size: 35),
                ),
                const Icon(Icons.account_circle, color: Colors.grey, size: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 3: Import Contacts ---
  Widget _buildSlide3(Color primaryColor, bool isDark) {
    return _TutorialCard(
      title: "Import Contacts",
      description:
          "Feel free to add your friend's phone number one at a time, or hit the book icon to import them directly from your phone!",
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.import_contacts,
                  color: themeProvider.onPrimaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: isDark ? Colors.grey[800] : Colors.white,
            child: const ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text("J", style: TextStyle(color: Colors.white)),
              ),
              title: Text("John Appleseed"),
              subtitle: Text("(888) 555-1212"),
            ),
          ),
          Card(
            color: isDark ? Colors.grey[800] : Colors.white,
            child: const ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.pink,
                child: Text("K", style: TextStyle(color: Colors.white)),
              ),
              title: Text("Kate Bell"),
              subtitle: Text("(555) 564-8583"),
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 4: Intro to Circles ---
  Widget _buildSlide4(Color primaryColor) {
    return _TutorialCard(
      title: "2. The Fun Part",
      description:
          "Once you have your friends added, it's time to group them up! Tap the Circles icon.",
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.home, color: Colors.grey, size: 30),
                // Highlighted Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.supervised_user_circle,
                    color: primaryColor,
                    size: 35,
                  ),
                ),
                const Icon(Icons.people, color: Colors.grey, size: 30),
                const Icon(Icons.account_circle, color: Colors.grey, size: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 5: Create Circles ---
  Widget _buildSlide5(Color primaryColor, bool isDark) {
    return _TutorialCard(
      title: "Create Circles",
      description:
          "Make a circle for your pickleball buddies, foodie friends, or coworkers. Create as many as you like! Long press to delete them later.",
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "New Friend Circle",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: "e.g. Movie Buffs",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: Text(
                  "Create",
                  style: TextStyle(color: themeProvider.onPrimaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SLIDE 6: Host Event Intro ---
  Widget _buildSlide6(Color primaryColor) {
    return _TutorialCard(
      title: "3. Announce to the World",
      description:
          "(...or just your friends lol) \n\nYou're ready to host! Head to the Home feed and tap the Add button to start an event.",
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.6),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(Icons.add, color: themeProvider.onPrimaryColor, size: 60),
        ),
      ),
    );
  }

  // --- SLIDE 7: Sending the 'i' ---
  Widget _buildSlide7(Color primaryColor, bool isDark) {
    return _TutorialCard(
      title: "Send out the i's!",
      description:
          "Fill in the details and select which circle gets the 'i' (invite). No more hearing 'TFTI' from your sarcastic buddies!",
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MockInput(
            icon: Symbols.campaign,
            text: "Lights, Camera, Action!",
            color: primaryColor,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _MockInput(
            icon: Icons.location_on,
            text: "Studio Movie Grill",
            color: Colors.red,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _MockInput(
            icon: Icons.people,
            text: "Movie Buffs",
            color: Colors.teal,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                "send out the i's",
                style: TextStyle(
                  color: themeProvider.onPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _TutorialCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _TutorialCard({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(flex: 5, child: child),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockInput extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool isDark;

  const _MockInput({
    required this.icon,
    required this.text,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }
}
