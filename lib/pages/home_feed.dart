import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'hangout_details_page.dart';
import 'hangout_editor_page.dart';
import 'vibe_check_editor_page.dart';
import '../components/shared/user_profile_sheet.dart';
import '../components/shared/event_summary_card.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import '../components/feed/feed_filter_bar.dart';
import '../components/feed/empty_feed_states.dart';
import '../components/feed/feed_skeleton.dart';
import '../components/feed/contextual_empty_card.dart';
import '../components/feed/carousel_feed_list.dart';
import '../models/feed_snapshot.dart';
import '../services/feed_service.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../utils/event_service.dart';
import '../utils/feed_filter_utils.dart';
import '../utils/theme_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedEventId;
  Map<String, dynamic>? _selectedEventData;
  bool _showHidden = false;
  FeedFilter _selectedFilter = FeedFilter.thisWeek;

  Stream<FeedSnapshot>? _feedStream;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _initFeedStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initFeedStream();
  }

  void _initFeedStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid != _currentUid) {
      _currentUid = uid;
      _feedStream = FeedService.feedStream(uid);
    }
  }

  void _showAddMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.how_to_vote, size: 28, color: primaryColor),
                title: const Text(
                  "Hangout",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text("Let the squad know what's happening."),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HangoutEditorPage(),
                    ),
                  );
                },
              ),
              Divider(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              ListTile(
                leading: Icon(
                  Symbols.earthquake,
                  size: 28,
                  color: primaryColor,
                ),
                title: const Text(
                  "Vibe Check",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text("Give options and let the squad decide."),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VibeCheckEditorPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleHideStatus(String eventId, bool currentlyHidden) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final action = currentlyHidden ? "Unhide" : "Hide";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$action Event?"),
        content: Text(
          currentlyHidden
              ? "Put this event back in your active feed?"
              : "Move this event to your Past/Hidden tab?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: currentlyHidden ? Colors.green : Colors.orange,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await EventService.toggleEventHidden(
        eventId: eventId,
        uid: user.uid,
        currentlyHidden: currentlyHidden,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyHidden ? "Event unhidden." : "Event hidden.",
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleHostTap(
    String hostId,
    Map<String, dynamic> hostData,
    List<String> goatedUids,
    List<String> blockedUids,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    hostData['uid'] = hostId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => UserProfileSheet(
        userData: hostData,
        currentUserId: user.uid,
        isGoated: goatedUids.contains(hostId),
        isBlocked: blockedUids.contains(hostId),
        onToggleGoated: (currentGoated) async {
          Navigator.pop(ctx);
          HapticFeedback.mediumImpact();
          await FriendService.toggleGoated(
            myUid: user.uid,
            friendUid: hostId,
            isGoated: !currentGoated,
          );
        },
        onToggleBlocked: (currentBlocked) async {
          Navigator.pop(ctx);
          HapticFeedback.heavyImpact();
          await UserService.toggleBlockUser(
            myUid: user.uid,
            targetUid: hostId,
            isBlocked: !currentBlocked,
          );
        },
      ),
    );
  }

  Widget _buildEventSummaryCardWrapper(
    Map<String, dynamic> item,
    bool isLandscape,
    bool isHorizontal,
    List<String> goatedUids,
    List<String> blockedUids,
  ) {
    final String eventId = item['id'];
    final Map<String, dynamic> data = item['eventData'];
    final bool isHidden = item['inviteData']['isHidden'] ?? false;
    final bool isSelected = _selectedEventId == eventId;

    return EventSummaryCard(
      item: item,
      myUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      isLandscape: isLandscape,
      isHorizontal: isHorizontal,
      isSelected: isSelected,
      onTap: () {
        if (isLandscape) {
          setState(() {
            _selectedEventId = eventId;
            _selectedEventData = data;
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HangoutDetailsPage(eventId: eventId, eventData: data),
            ),
          );
        }
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _toggleHideStatus(eventId, isHidden);
      },
      onHostTap: (hostId, hostData) =>
          _handleHostTap(hostId, hostData, goatedUids, blockedUids),
    );
  }

  Widget _buildSectionHeader(
    String title,
    Color color, {
    EdgeInsets padding = const EdgeInsets.only(left: 20, bottom: 12),
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: padding,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEventsCarouselOrList({
    required List<Map<String, dynamic>> items,
    required bool isLandscape,
    required List<String> goatedUids,
    required List<String> blockedUids,
    bool forceVertical = false,
    EdgeInsets landscapePadding = const EdgeInsets.symmetric(horizontal: 16),
    double carouselBottomPadding = 0,
  }) {
    if (isLandscape || forceVertical) {
      return SliverPadding(
        padding: landscapePadding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildEventSummaryCardWrapper(
              items[index],
              isLandscape,
              false,
              goatedUids,
              blockedUids,
            ),
            childCount: items.length,
          ),
        ),
      );
    } else {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: carouselBottomPadding),
          child: SizedBox(
            height: 310,
            child: CarouselFeedList(
              itemCount: items.length,
              itemBuilder: (context, index) => _buildEventSummaryCardWrapper(
                items[index],
                isLandscape,
                true,
                goatedUids,
                blockedUids,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContextualEmptySliver({
    required IconData icon,
    required String title,
    required String message,
    required bool isLandscape,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 16 : 20),
        child: SizedBox(
          height: isLandscape ? 240 : 310,
          child: ContextualEmptyCard(
            icon: icon,
            title: title,
            message: message,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    if (user != null && (_feedStream == null || user.uid != _currentUid)) {
      _initFeedStream();
    }

    return StreamBuilder<FeedSnapshot>(
      stream: _feedStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          final skeleton = FeedSkeleton(isLandscape: isLandscape);
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: isLandscape
                ? Row(
                    children: [
                      Expanded(
                        flex: 35,
                        child: skeleton,
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color:
                            isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                      const Expanded(
                        flex: 65,
                        child: FeedDetailPlaceholder(),
                      ),
                    ],
                  )
                : skeleton,
          );
        }

        final feedSnapshot = snapshot.data ?? FeedSnapshot.empty;
        final filtered = FeedFilterUtils.filterAndBucket(
          events: feedSnapshot.events,
          myInvitesMap: feedSnapshot.myInvitesMap,
          blockedUids: feedSnapshot.blockedUids,
          goatedUids: feedSnapshot.goatedUids,
          currentUserId: user?.uid ?? '',
          filter: _selectedFilter,
        );

        final filterText = FeedFilterUtils.getFilterSubtitle(_selectedFilter);
        final greeting = FeedFilterUtils.getGreeting();

        final Widget scrollView = CustomScrollView(
          slivers: [
            SharedSliverAppBar(
              title: "the i's",
              collapsedTitle: "thanks for the invite",
              subtitle: "$greeting, ${feedSnapshot.firstName}",
              expandedHeight: isLandscape ? 56.0 : 140.0,
              hasBackButton: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showAddMenu();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: themeProvider.pillBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              color: themeProvider.pillTextColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Create",
                              style: TextStyle(
                                color: themeProvider.pillTextColor,
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: FeedFilterBar(
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (f) => setState(() => _selectedFilter = f),
                ),
              ),
            ),

            // --- ACTION NEEDED ---
            _buildSectionHeader(
              "Action Needed",
              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            if (filtered.actionNeeded.isNotEmpty)
              _buildEventsCarouselOrList(
                items: filtered.actionNeeded,
                isLandscape: isLandscape,
                goatedUids: feedSnapshot.goatedUids,
                blockedUids: feedSnapshot.blockedUids,
              )
            else
              _buildContextualEmptySliver(
                icon: Icons.check_circle_outline,
                title: "You're all caught up!",
                message: _selectedFilter == FeedFilter.vip
                    ? "You have no pending invites with your VIP friends."
                    : "You have no pending invites.",
                isLandscape: isLandscape,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // --- THE AGENDA ---
            _buildSectionHeader(
              "The Agenda",
              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            if (filtered.agenda.isNotEmpty)
              _buildEventsCarouselOrList(
                items: filtered.agenda,
                isLandscape: isLandscape,
                goatedUids: feedSnapshot.goatedUids,
                blockedUids: feedSnapshot.blockedUids,
                forceVertical: true,
              )
            else
              _buildContextualEmptySliver(
                icon: Icons.celebration,
                title: "Nothing on the agenda.",
                message:
                    "Your agenda is looking a bit empty$filterText... Tap the + to host a hangout!",
                isLandscape: isLandscape,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // --- NOT GOING ---
            if (filtered.declined.isNotEmpty) ...[
              _buildSectionHeader(
                "Not Going",
                isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                padding: const EdgeInsets.only(left: 20, top: 12, bottom: 12),
              ),
              _buildEventsCarouselOrList(
                items: filtered.declined,
                isLandscape: isLandscape,
                goatedUids: feedSnapshot.goatedUids,
                blockedUids: feedSnapshot.blockedUids,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // --- PAST HANGOUTS ---
            if (filtered.past.isNotEmpty) ...[
              _buildSectionHeader(
                "Past Hangouts",
                isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                padding: const EdgeInsets.only(left: 20, top: 12, bottom: 12),
              ),
              _buildEventsCarouselOrList(
                items: filtered.past,
                isLandscape: isLandscape,
                goatedUids: feedSnapshot.goatedUids,
                blockedUids: feedSnapshot.blockedUids,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // --- HIDDEN EVENTS ---
            if (filtered.hidden.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showHidden = !_showHidden),
                    icon: Icon(
                      _showHidden ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    label: Text(
                      _showHidden
                          ? "Hide Archived Events"
                          : "View Hidden Events (${filtered.hidden.length})",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
              if (_showHidden)
                _buildEventsCarouselOrList(
                  items: filtered.hidden,
                  isLandscape: isLandscape,
                  goatedUids: feedSnapshot.goatedUids,
                  blockedUids: feedSnapshot.blockedUids,
                  landscapePadding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 100,
                  ),
                  carouselBottomPadding: 100,
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ] else ...[
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        );

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: isLandscape
              ? Row(
                  children: [
                    Expanded(
                      flex: 35,
                      child: scrollView,
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                    Expanded(
                      flex: 65,
                      child: _selectedEventId != null &&
                              _selectedEventData != null
                          ? HangoutDetailsPage(
                              key: ValueKey(_selectedEventId),
                              eventId: _selectedEventId!,
                              eventData: _selectedEventData!,
                            )
                          : const FeedDetailPlaceholder(),
                    ),
                  ],
                )
              : scrollView,
        );
      },
    );
  }
}
