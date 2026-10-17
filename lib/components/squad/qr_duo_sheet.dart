import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/app_avatar.dart';

class QrDuoSheet extends StatefulWidget {
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int avatarColor;
  final Function(String scannedUsername) onScanned;

  const QrDuoSheet({
    super.key,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.avatarColor,
    required this.onScanned,
  });

  static void show(
    BuildContext context, {
    required String username,
    required String displayName,
    String? avatarUrl,
    required int avatarColor,
    required Function(String scannedUsername) onScanned,
    bool initialScanTab = false,
  }) {
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please set a username in Account first to use QR!"),
        ),
      );
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
      ),
    );
  }

  @override
  State<QrDuoSheet> createState() => _QrDuoSheetState();
}

class _QrDuoSheetState extends State<QrDuoSheet> {
  int _selectedTabIndex = 0; // 0 = My Code, 1 = Scan
  bool _hasScanned = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _copyInviteLink() {
    final link = "https://tfti-app.web.app/add/@${widget.username}";
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final qrData = "tfti://add/@${widget.username}";

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
            if (_selectedTabIndex == 0) ...[
              // User avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(widget.avatarColor).withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AppAvatar.fromColorValue(
                  radius: 30,
                  avatarColor: widget.avatarColor,
                  avatarUrl: widget.avatarUrl,
                  displayName: widget.displayName,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.displayName.isNotEmpty ? widget.displayName : "Me",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "@${widget.username}",
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
                onPressed: _copyInviteLink,
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
            ] else ...[
              // Scan tab
              if (kIsWeb) ...[
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices,
                            size: 48,
                            color: primaryColor,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Mobile Scanning",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Camera scanning is optimized for the TFTI mobile app. You can share your personal QR code or invite link from the web!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => setState(() => _selectedTabIndex = 0),
                            icon: const Icon(Icons.qr_code, size: 18),
                            label: const Text("Show My QR Code"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
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
          ],
        ),
      ),
    );
  }
}
