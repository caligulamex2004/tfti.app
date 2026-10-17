import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_profile.dart';
import '../../services/friend_service.dart';
import '../../services/user_cache_repository.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/theme_provider.dart';
import '../shared/app_avatar.dart';

class AddFriendSection extends StatefulWidget {
  final bool isDark;
  final Color primaryColor;
  final bool useGradient;
  final bool isLandscape;
  final String myUid;
  final Set<String> myFriendUids;
  final String statusMessage;
  final VoidCallback onOpenQrDuo;
  final VoidCallback onShareLink;
  final VoidCallback onImportContacts;
  final Function(String targetUid, String username) onSendSquadRequest;
  final Function(String phone) onInvitePhone;

  const AddFriendSection({
    super.key,
    required this.isDark,
    required this.primaryColor,
    this.useGradient = false,
    this.isLandscape = false,
    required this.myUid,
    required this.myFriendUids,
    required this.statusMessage,
    required this.onOpenQrDuo,
    required this.onShareLink,
    required this.onImportContacts,
    required this.onSendSquadRequest,
    required this.onInvitePhone,
  });

  @override
  State<AddFriendSection> createState() => _AddFriendSectionState();
}

class _AddFriendSectionState extends State<AddFriendSection> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _searchExecuted = false;
  UserProfile? _matchedUser;
  bool _isPendingRequest = false;
  bool _isPhoneInput = false;
  String _searchedRawPhone = "";

  // In-memory session cache to avoid repeated Firestore reads (e.g. backspacing and re-typing)
  final Map<String, UserProfile?> _queryCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchInputChanged() {
    final text = _searchController.text.trim();
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    if (text.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchExecuted = false;
        _matchedUser = null;
        _isPendingRequest = false;
        _isPhoneInput = false;
        _searchedRawPhone = "";
      });
      return;
    }

    // Defensive 500ms debounce (matching PlacesSearchPage pattern)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(text);
    });
    setState(() {});
  }

  bool _isDigitsOnly(String s) {
    final clean = s.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return clean.isNotEmpty && RegExp(r'^\d+$').hasMatch(clean);
  }

  Future<void> _executeSearch(String rawQuery) async {
    final text = rawQuery.trim();
    if (text.isEmpty) return;

    final isPhone = _isDigitsOnly(text);
    final cleanQuery = isPhone
        ? text.replaceAll(RegExp(r'[^\d]'), '')
        : text.toLowerCase().replaceAll(RegExp(r'^@'), '');

    // Threshold check: Username >= 3 chars, Phone >= 10 digits
    if (!isPhone && cleanQuery.length < 3) {
      setState(() {
        _isSearching = false;
        _searchExecuted = false;
        _matchedUser = null;
      });
      return;
    }
    if (isPhone && cleanQuery.length < 10) {
      setState(() {
        _isSearching = false;
        _searchExecuted = false;
        _matchedUser = null;
      });
      return;
    }

    // Check in-memory cache first
    final cacheKey = isPhone ? "phone:$cleanQuery" : "user:$cleanQuery";
    if (_queryCache.containsKey(cacheKey)) {
      final cachedProfile = _queryCache[cacheKey];
      bool isPending = false;
      if (cachedProfile != null) {
        isPending = await FriendService.hasPendingRequest(
          fromUid: widget.myUid,
          toUid: cachedProfile.uid,
        );
      }
      if (!mounted) return;
      setState(() {
        _matchedUser = cachedProfile;
        _isPendingRequest = isPending;
        _isSearching = false;
        _searchExecuted = true;
        _isPhoneInput = isPhone;
        _searchedRawPhone = text;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchExecuted = false;
      _isPhoneInput = isPhone;
      _searchedRawPhone = text;
    });

    try {
      String? foundUid;
      if (isPhone) {
        String formattedPhone = cleanQuery;
        if (formattedPhone.length == 10) {
          formattedPhone = "+1$formattedPhone";
        } else if (!formattedPhone.startsWith('+')) {
          formattedPhone = "+$formattedPhone";
        }
        foundUid = await FriendService.findUidByPhone(formattedPhone);
      } else {
        foundUid = await FriendService.findUidByUsername(cleanQuery);
      }

      UserProfile? profile;
      bool isPending = false;

      if (foundUid != null) {
        profile = await UserCacheRepository.instance.getUser(foundUid);
        if (profile != null) {
          isPending = await FriendService.hasPendingRequest(
            fromUid: widget.myUid,
            toUid: profile.uid,
          );
        }
      }

      // Store in query cache
      _queryCache[cacheKey] = profile;

      if (!mounted) return;
      setState(() {
        _matchedUser = profile;
        _isPendingRequest = isPending;
        _isSearching = false;
        _searchExecuted = true;
      });
    } catch (e) {
      debugPrint("Error performing friend lookup: $e");
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchExecuted = true;
        _matchedUser = null;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = false;
      _searchExecuted = false;
      _matchedUser = null;
      _isPendingRequest = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = widget.primaryColor;
    final useGradient = widget.useGradient;
    final isLandscape = widget.isLandscape;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 16.0 : 20.0,
        vertical: 16.0,
      ),
      decoration: BoxDecoration(
        color: useGradient ? null : Theme.of(context).cardColor,
        gradient: useGradient ? themeProvider.appGradient : null,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Grow the Squad",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                  color: (useGradient || isDark) ? Colors.white : Colors.black87,
                ),
              ),
              if (widget.statusMessage.isNotEmpty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (widget.statusMessage.contains("Added") ||
                              widget.statusMessage.contains("prepared") ||
                              widget.statusMessage.contains("sent"))
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (widget.statusMessage.contains("Added") ||
                                widget.statusMessage.contains("prepared") ||
                                widget.statusMessage.contains("sent"))
                            ? (isDark ? Colors.greenAccent : Colors.green)
                            : (isDark ? Colors.redAccent : Colors.red),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Action Pills Row
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _buildActionPill(
                icon: Icons.qr_code_scanner,
                label: "QR Duo",
                onTap: widget.onOpenQrDuo,
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              _buildActionPill(
                icon: Icons.share_rounded,
                label: "Share Link",
                onTap: widget.onShareLink,
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              if (!kIsWeb)
                _buildActionPill(
                  icon: Icons.contacts_rounded,
                  label: "Contacts",
                  onTap: widget.onImportContacts,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Smart Search Input
          TextField(
            controller: _searchController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (val) {
              _debounceTimer?.cancel();
              _executeSearch(val);
            },
            decoration: InputDecoration(
              hintText: "Search @username or phone number...",
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: primaryColor,
                size: 20,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      onPressed: _clearSearch,
                    ),
                ],
              ),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),

          // Result Preview Card / Not Found Notice
          if (_matchedUser != null) ...[
            const SizedBox(height: 10),
            _buildMatchedUserCard(isDark, primaryColor),
          ] else if (_searchExecuted && !_isSearching) ...[
            const SizedBox(height: 10),
            _buildNotFoundView(isDark, primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchedUserCard(bool isDark, Color primaryColor) {
    final user = _matchedUser!;
    final isMe = user.uid == widget.myUid;
    final isAlreadyFriend = widget.myFriendUids.contains(user.uid);
    final avatarColor = user.avatarColor ?? Colors.blue.toARGB32();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar.fromColorValue(
            radius: 20,
            avatarColor: avatarColor,
            avatarUrl: user.avatarUrl,
            displayName: user.displayName,
            fontSize: 15,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : "@${user.username}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "@${user.username}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "You",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          else if (isAlreadyFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    "In Squad",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            )
          else if (_isPendingRequest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.schedule, size: 14, color: Colors.amber),
                  SizedBox(width: 4),
                  Text(
                    "Sent",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                widget.onSendSquadRequest(user.uid, user.username);
                setState(() => _isPendingRequest = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Squad Up 🔥",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView(bool isDark, Color primaryColor) {
    if (_isPhoneInput) {
      final beautified = PhoneFormatter.beautify(_searchedRawPhone);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Not on TFTI yet",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    "Invite $beautified via SMS",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onInvitePhone(_searchedRawPhone),
              icon: const Icon(Icons.sms_rounded, size: 14),
              label: const Text(
                "Invite",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 4),
      child: Text(
        "No TFTI user found for \"${_searchController.text.trim()}\"",
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
