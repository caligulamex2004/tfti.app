import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// --- COMPONENTS & UTILITIES ---
import '../models/squad_request_model.dart';
import '../components/squad/add_friend_section.dart';
import '../components/squad/suggested_squad_rail.dart';
import '../components/squad/qr_duo_sheet.dart';
import '../components/squad/friend_list_feed.dart';
import '../components/squad/contact_import_sheet.dart';
import '../components/squad/squad_requests_section.dart';
import '../services/contact_service.dart';
import '../services/contact_resolver.dart';
import '../services/friend_service.dart';
import '../services/user_cache_repository.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import '../utils/responsive_layout.dart';

class SquadPage extends StatefulWidget {
  const SquadPage({super.key});

  @override
  State<SquadPage> createState() => _SquadPageState();
}

class _SquadPageState extends State<SquadPage> {
  String _statusMessage = "";
  bool _sortByScore = true;

  final Set<String> _removedFriendUids = {};
  Set<String> _myFriendUids = {};
  StreamSubscription? _friendsSubscription;

  // Current user profile details for QR and Link sharing
  String _myUsername = "";
  String _myDisplayName = "";
  String? _myAvatarUrl;
  int _myAvatarColor = Colors.blue.toARGB32();

  // Suggested Squad state
  List<Map<String, dynamic>> _suggestedUsers = [];
  final Set<String> _suggestedAddedUids = {};
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    _listenToFriends();

    if (!kIsWeb) {
      ContactResolver.instance.warmUpIfPermitted();
      ContactResolver.instance.addListener(_onContactResolverUpdated);
    }
  }

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    if (!kIsWeb) {
      ContactResolver.instance.removeListener(_onContactResolverUpdated);
    }
    super.dispose();
  }

  void _onContactResolverUpdated() {
    if (mounted) {
      setState(() {});
      if (ContactResolver.instance.hasWarmedUp) {
        _loadSuggestedContacts();
      }
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = await UserCacheRepository.instance.getUser(user.uid);
    if (!mounted || profile == null) return;

    setState(() {
      _myUsername = profile.username;
      _myDisplayName = profile.displayName;
      _myAvatarUrl = profile.avatarUrl;
      _myAvatarColor = profile.avatarColor ?? Colors.blue.toARGB32();
    });
  }

  void _listenToFriends() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _friendsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _myFriendUids = snap.docs.map((doc) => doc.id).toSet();
      });
      // Re-filter suggestions so friends don't appear in suggested squad
      if (_suggestedUsers.isNotEmpty) {
        setState(() {
          _suggestedUsers.removeWhere((u) => _myFriendUids.contains(u['uid']));
        });
      }
    });
  }

  Future<void> _loadSuggestedContacts() async {
    if (kIsWeb) return;
    if (_isLoadingSuggestions) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cache = ContactResolver.instance.cache;
    if (cache.isEmpty) return;

    _isLoadingSuggestions = true;
    try {
      final List<String> allPhones = cache.keys.toList();
      final List<Map<String, dynamic>> matches = [];

      for (int i = 0; i < allPhones.length && matches.length < 15; i += 30) {
        final end = (i + 30 < allPhones.length) ? i + 30 : allPhones.length;
        final chunk = allPhones.sublist(i, end);

        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', whereIn: chunk)
            .get(const GetOptions(source: Source.server));

        for (final doc in snap.docs) {
          final data = doc.data();
          final uid = doc.id;
          final phone = data['phoneNumber'] as String?;

          if (uid != user.uid && !_myFriendUids.contains(uid)) {
            data['uid'] = uid;
            if (phone != null && cache.containsKey(phone)) {
              data['contactName'] = cache[phone];
            }
            matches.add(data);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _suggestedUsers = matches;
      });
    } catch (e) {
      debugPrint("Error loading suggested contacts: $e");
    } finally {
      _isLoadingSuggestions = false;
    }
  }

  void _clearStatusAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _statusMessage = "");
      }
    });
  }

  void _openQrDuo() {
    QrDuoSheet.show(
      context,
      username: _myUsername,
      displayName: _myDisplayName,
      avatarUrl: _myAvatarUrl,
      avatarColor: _myAvatarColor,
      onScanned: (scannedUsername) {
        _addFriend(overrideUsername: scannedUsername, isFromQrCode: true);
      },
    );
  }

  void _shareInviteLink() {
    final link = "https://tfti-app.web.app/add/@$_myUsername";
    Clipboard.setData(ClipboardData(text: link));
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            SizedBox(width: 8),
            Text("Invite link copied to clipboard!"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _importContacts() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Contact import is only available on mobile devices."),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final contacts = await ContactHelper.getContacts();
      if (contacts == null) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permission denied for contacts.")),
        );
        return;
      }

      final myUid = FirebaseAuth.instance.currentUser!.uid;
      final myFriendUids = await FriendService.getFriendUids(myUid);

      List<String> allPhones = [];
      Map<String, Contact> phoneToContact = {};

      for (var c in contacts) {
        for (var p in c.phones) {
          final raw = p.number;
          final norm = ContactHelper.normalizePhone(raw);
          if (norm != null && !allPhones.contains(norm)) {
            allPhones.add(norm);
            phoneToContact[norm] = c;
          }
        }
      }

      List<Map<String, dynamic>> onTfti = [];
      List<Contact> notOnTfti = [];
      Set<String> allTftiPhones = {};

      if (allPhones.isNotEmpty) {
        for (int i = 0; i < allPhones.length; i += 30) {
          int end = (i + 30 < allPhones.length) ? i + 30 : allPhones.length;
          List<String> chunk = allPhones.sublist(i, end);

          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('phoneNumber', whereIn: chunk)
              .get(const GetOptions(source: Source.server));
          for (var doc in snap.docs) {
            final data = doc.data();
            final uid = doc.id;
            final phone = data['phoneNumber'] as String;
            allTftiPhones.add(phone);
            if (uid != myUid && !myFriendUids.contains(uid)) {
              data['uid'] = uid;
              final contact = phoneToContact[phone];
              final contactDisplayName = contact?.displayName?.trim();
              if (contactDisplayName != null && contactDisplayName.isNotEmpty) {
                data['contactName'] = contactDisplayName;
              }
              onTfti.add(data);
            }
          }
        }
      }

      for (var phone in allPhones) {
        if (!allTftiPhones.contains(phone)) {
          notOnTfti.add(phoneToContact[phone]!);
        }
      }

      onTfti.sort(
        (a, b) {
          final nameA =
              (a['contactName'] ?? a['displayName'] ?? '').toString().toLowerCase();
          final nameB =
              (b['contactName'] ?? b['displayName'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        },
      );
      notOnTfti.sort(
        (a, b) => (a.displayName ?? '')
            .toLowerCase()
            .compareTo((b.displayName ?? '').toLowerCase()),
      );

      if (!mounted) return;
      Navigator.pop(context);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => ContactImportSheet(
          onTfti: onTfti,
          notOnTfti: notOnTfti,
          myUid: myUid,
          onInviteSms: _inviteViaSms,
          onFriendAdded: (uid) {
            setState(() {
              _removedFriendUids.remove(uid);
            });
            _loadSuggestedContacts();
          },
        ),
      );

      _loadSuggestedContacts();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      debugPrint("Error fetching contacts: $e");
    }
  }

  Future<void> _inviteViaSms(String phone) async {
    const String kAppUrl = "https://tfti-app.web.app";
    final String message =
        "Hey! Join me on tfti.app so I can invite you to events! Check it out: $kAppUrl";
    final Uri smsLaunchUri = Uri.parse(
      'sms:$phone?body=${Uri.encodeComponent(message)}',
    );
    try {
      if (!await launchUrl(smsLaunchUri) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch SMS app.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Could not launch SMS.")));
      }
    }
  }

  Future<void> _addFriend({
    required String overrideUsername,
    bool isFromQrCode = false,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    String input = overrideUsername.trim().toLowerCase();
    if (input.startsWith('@')) {
      input = input.substring(1);
    }
    if (input.isEmpty) return;

    final targetUid = await FriendService.findUidByUsername(input);
    if (!mounted) return;
    if (targetUid == null) {
      setState(() => _statusMessage = "Username @$input not found.");
      _clearStatusAfterDelay();
      return;
    }

    if (targetUid == myUid) {
      setState(() => _statusMessage = "You can't add yourself!");
      _clearStatusAfterDelay();
      return;
    }

    final myFriends = await FriendService.getFriendUids(myUid);
    if (myFriends.contains(targetUid)) {
      setState(() => _statusMessage = "@$input is already in your squad!");
      _clearStatusAfterDelay();
      return;
    }

    if (isFromQrCode) {
      // In-person QR fast-path directly adds friend
      final targetUser = await UserCacheRepository.instance.getUser(targetUid);
      if (!mounted) return;
      final targetPhone = targetUser?.phoneNumber ?? '';

      await FriendService.addFriend(
        myUid: myUid,
        friendUid: targetUid,
        phoneNumber: targetPhone,
      );

      if (!mounted) return;
      setState(() {
        _removedFriendUids.remove(targetUid);
        _statusMessage = "Added @$input to the squad!";
      });
      _clearStatusAfterDelay();
    } else {
      await FriendService.sendSquadRequest(
        fromUid: myUid,
        toUid: targetUid,
        source: 'username',
      );

      if (!mounted) return;
      setState(() {
        _statusMessage = "Squad request sent to @$input!";
      });
      _clearStatusAfterDelay();
    }
  }

  Future<void> _sendSquadRequest(String targetUid, String username) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    await FriendService.sendSquadRequest(
      fromUid: myUid,
      toUid: targetUid,
      source: 'search',
    );
    if (!mounted) return;
    setState(() {
      _statusMessage = "Squad request sent to @$username!";
    });
    _clearStatusAfterDelay();
  }

  Future<void> _handleSuggestedSquadUp(Map<String, dynamic> user) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final targetUid = user['uid'] as String;
    final username = user['username'] as String? ?? '';

    setState(() {
      _suggestedAddedUids.add(targetUid);
    });

    await FriendService.sendSquadRequest(
      fromUid: myUid,
      toUid: targetUid,
      source: 'suggested',
    );

    if (!mounted) return;
    setState(() {
      _statusMessage =
          "Squad request sent${username.isNotEmpty ? ' to @$username' : ''}!";
    });
    _clearStatusAfterDelay();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final myUid = user.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = context.isWideScreen;
    final hasContactsPermission =
        !kIsWeb && ContactResolver.instance.hasWarmedUp && ContactResolver.instance.cache.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 40,
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          toolbarHeight: 56,
                          primary: true,
                          backgroundColor: isDark
                              ? Colors.black.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.7),
                          automaticallyImplyLeading: false,
                          flexibleSpace: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 15.0,
                                sigmaY: 15.0,
                              ),
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "The Squad",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: AddFriendSection(
                            isDark: isDark,
                            primaryColor: primaryColor,
                            isLandscape: true,
                            myUid: myUid,
                            myFriendUids: _myFriendUids,
                            statusMessage: _statusMessage,
                            onOpenQrDuo: _openQrDuo,
                            onShareLink: _shareInviteLink,
                            onImportContacts: _importContacts,
                            onSendSquadRequest: _sendSquadRequest,
                            onInvitePhone: _inviteViaSms,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SuggestedSquadRail(
                            isDark: isDark,
                            primaryColor: primaryColor,
                            isLandscape: true,
                            suggestions: _suggestedUsers,
                            hasContactsPermission: hasContactsPermission,
                            addedUids: _suggestedAddedUids,
                            onRequestContacts: _importContacts,
                            onSquadUp: _handleSuggestedSquadUp,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildSquadRequestsStream(myUid),
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                Expanded(
                  flex: 60,
                  child: FriendListFeed(
                    myUid: myUid,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    sortByScore: _sortByScore,
                    removedFriendUids: _removedFriendUids,
                    headerSlivers: const [
                      SharedSliverAppBar(
                        title: "Squad List",
                        collapsedTitle: "Squad List",
                        expandedHeight: 56.0,
                        hasBackButton: false,
                      ),
                    ],
                    onToggleSort: () {
                      HapticFeedback.lightImpact();
                      setState(() => _sortByScore = !_sortByScore);
                    },
                    onFriendRemoved: (uid) {
                      setState(() => _removedFriendUids.add(uid));
                    },
                  ),
                ),
              ],
            )
          : FriendListFeed(
              myUid: myUid,
              isDark: isDark,
              primaryColor: primaryColor,
              sortByScore: _sortByScore,
              removedFriendUids: _removedFriendUids,
              headerSlivers: [
                SharedSliverAppBar(
                  title: "The Squad",
                  collapsedTitle: "The Squad",
                  expandedHeight: 140.0,
                  hasBackButton: false,
                ),
                SliverToBoxAdapter(
                  child: AddFriendSection(
                    isDark: isDark,
                    primaryColor: primaryColor,
                    useGradient: false,
                    isLandscape: false,
                    myUid: myUid,
                    myFriendUids: _myFriendUids,
                    statusMessage: _statusMessage,
                    onOpenQrDuo: _openQrDuo,
                    onShareLink: _shareInviteLink,
                    onImportContacts: _importContacts,
                    onSendSquadRequest: _sendSquadRequest,
                    onInvitePhone: _inviteViaSms,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SuggestedSquadRail(
                    isDark: isDark,
                    primaryColor: primaryColor,
                    isLandscape: false,
                    suggestions: _suggestedUsers,
                    hasContactsPermission: hasContactsPermission,
                    addedUids: _suggestedAddedUids,
                    onRequestContacts: _importContacts,
                    onSquadUp: _handleSuggestedSquadUp,
                  ),
                ),
                SliverToBoxAdapter(child: _buildSquadRequestsStream(myUid)),
              ],
              onToggleSort: () {
                HapticFeedback.lightImpact();
                setState(() => _sortByScore = !_sortByScore);
              },
              onFriendRemoved: (uid) {
                setState(() => _removedFriendUids.add(uid));
              },
            ),
    );
  }

  Widget _buildSquadRequestsStream(String myUid) {
    return StreamBuilder<List<SquadRequest>>(
      stream: FriendService.incomingRequestsStream(myUid),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }
        return SquadRequestsSection(
          requests: requests,
          onSquadUp: (req) async {
            await FriendService.acceptSquadRequest(
              myUid: myUid,
              requesterUid: req.fromUid,
            );
            if (!mounted) return;
            setState(() {
              _removedFriendUids.remove(req.fromUid);
              _statusMessage =
                  "Squadded up with ${req.displayName.isNotEmpty ? req.displayName : '@${req.username}'}!";
            });
            _clearStatusAfterDelay();
          },
          onPass: (req) async {
            await FriendService.passSquadRequest(
              myUid: myUid,
              requesterUid: req.fromUid,
            );
            if (!mounted) return;
            setState(() {
              _statusMessage = "Passed on squad request.";
            });
            _clearStatusAfterDelay();
          },
          onBlock: (req) async {
            await FriendService.blockSquadRequest(
              myUid: myUid,
              requesterUid: req.fromUid,
            );
            if (!mounted) return;
            setState(() {
              _statusMessage = "Blocked user.";
            });
            _clearStatusAfterDelay();
          },
        );
      },
    );
  }
}
