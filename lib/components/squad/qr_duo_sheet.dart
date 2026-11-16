import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/user_profile.dart';
import '../../services/app_toast.dart';
import '../shared/app_avatar.dart';

class QrDuoSheet extends StatefulWidget {
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int avatarColor;
  final Function(String scannedUsername) onScanned;
  final bool initialScanTab;
  final ValueListenable<UserProfile?>? profileListenable;

  const QrDuoSheet({
    super.key,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.avatarColor,
    required this.onScanned,
    this.initialScanTab = false,
    this.profileListenable,
  });

  static void show(
    BuildContext context, {
    required String username,
    required String displayName,
    String? avatarUrl,
    required int avatarColor,
    required Function(String scannedUsername) onScanned,
    bool initialScanTab = false,
    ValueListenable<UserProfile?>? profileListenable,
  }) {
    final liveUsername = profileListenable?.value?.username ?? '';
    final effectiveUsername =
        liveUsername.isNotEmpty ? liveUsername : username;
    if (!initialScanTab && effectiveUsername.isEmpty) {
      AppToast.warning("Please set a username in Account first to use QR!");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => QrDuoSheet(
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        avatarColor: avatarColor,
        onScanned: onScanned,
        initialScanTab: initialScanTab,
        profileListenable: profileListenable,
      ),
    );
  }

  @override
  State<QrDuoSheet> createState() => _QrDuoSheetState();
}

class _QrDuoSheetState extends State<QrDuoSheet> {
  late int _selectedTabIndex; // 0 = My Code, 1 = Scan
  bool _hasScanned = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialScanTab ? 1 : 0;
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _copyInviteLink(String username) {
    if (username.isEmpty) return;
    final link = "https://tfti-app.web.app/add/@$username";
    Clipboard.setData(ClipboardData(text: link));
    HapticFeedback.lightImpact();
    AppToast.success(
      "Invite link copied to clipboard!",
      duration: const Duration(seconds: 2),
    );
  }

  Widget _buildMyCodeTab(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
  }) {
    final listenable = widget.profileListenable;
    if (listenable == null) {
      return _buildMyCodeContent(
        context,
        isDark: isDark,
        primaryColor: primaryColor,
        username: widget.username,
        displayName: widget.displayName,
        avatarUrl: widget.avatarUrl,
        avatarColor: widget.avatarColor,
      );
    }

    return ValueListenableBuilder<UserProfile?>(
      valueListenable: listenable,
      builder: (context, profile, _) {
        final username = (profile?.username.isNotEmpty ?? false)
            ? profile!.username
            : widget.username;
        final displayName = (profile?.displayName.isNotEmpty ?? false)
            ? profile!.displayName
            : widget.displayName;
        final avatarUrl = profile?.avatarUrl ?? widget.avatarUrl;
        final avatarColor = profile?.avatarColor ?? widget.avatarColor;
        return _buildMyCodeContent(
          context,
          isDark: isDark,
          primaryColor: primaryColor,
          username: username,
          displayName: displayName,
          avatarUrl: avatarUrl,
          avatarColor: avatarColor,
        );
      },
    );
  }

  Widget _buildMyCodeContent(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required String username,
    required String displayName,
    required String? avatarUrl,
    required int avatarColor,
  }) {
    if (username.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 56,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              "Please set a username in Account first to share your QR code.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final qrData = "tfti://add/@$username";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // User avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(avatarColor).withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: AppAvatar.fromColorValue(
            radius: 30,
            avatarColor: avatarColor,
            avatarUrl: avatarUrl,
            displayName: displayName,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          displayName.isNotEmpty ? displayName : "Me",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          "@$username",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // QR Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 190.0,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: primaryColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Hold this up for a friend to scan and squad up!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _copyInviteLink(username),
          icon: const Icon(Icons.link, size: 18),
          label: const Text(
            "Copy My Invite Link",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab Switcher
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTabIndex = 0);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0
                              ? (isDark ? Colors.grey.shade800 : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTabIndex == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2,
                              size: 18,
                              color: _selectedTabIndex == 0
                                  ? primaryColor
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "My Code",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTabIndex == 0
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTabIndex = 1);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1
                              ? (isDark ? Colors.grey.shade800 : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTabIndex == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 18,
                              color: _selectedTabIndex == 1
                                  ? primaryColor
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Scan Code",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTabIndex == 1
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            if (_selectedTabIndex == 0)
              _buildMyCodeTab(
                context,
                isDark: isDark,
                primaryColor: primaryColor,
              )
            else ...[
              // Scan tab (enabled on Web and Mobile)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 280,
                  width: double.infinity,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_scannerController != null)
                        MobileScanner(
                          controller: _scannerController!,
                          errorBuilder: (context, error) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.videocam_off_rounded,
                                      size: 44,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.white70,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      error.errorCode ==
                                              MobileScannerErrorCode.permissionDenied
                                          ? "Camera permission denied.\nPlease allow camera access in your browser or device settings."
                                          : "Unable to access camera (${error.errorCode.name}).",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          onDetect: (BarcodeCapture capture) {
                            if (_hasScanned) return;
                            for (final barcode in capture.barcodes) {
                              final raw = barcode.rawValue;
                              if (raw != null && raw.startsWith('tfti://add/@')) {
                                _hasScanned = true;
                                final scannedUsername =
                                    raw.replaceFirst('tfti://add/@', '');
                                HapticFeedback.heavyImpact();
                                Navigator.pop(context);
                                widget.onScanned(scannedUsername);
                                break;
                              }
                            }
                          },
                        ),
                      // Reticle box
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const Positioned(
                        bottom: 16,
                        child: Text(
                          "Point at a friend's TFTI QR Code",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
