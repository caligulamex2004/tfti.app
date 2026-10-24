import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/app_avatar.dart';
import '../../services/contact_resolver.dart';

// --- FULL DETAILS SHEET ---
class FullDetailsSheet extends StatelessWidget {
  final String details;

  const FullDetailsSheet({super.key, required this.details});

  List<TextSpan> _buildLinkedTextSpans(
    String text,
    bool isDark,
    Color primaryColor,
  ) {
    final List<TextSpan> spans = [];
    final RegExp urlRegExp = RegExp(
      r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
      caseSensitive: false,
    );
    final matches = urlRegExp.allMatches(text);
    int previousEnd = 0;

    for (final match in matches) {
      if (match.start > previousEnd) {
        spans.add(
          TextSpan(
            text: text.substring(previousEnd, match.start),
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.black87,
              height: 1.5,
            ),
          ),
        );
      }
      final String url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            height: 1.5,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              HapticFeedback.lightImpact();
              String launchUrlString = url;
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                launchUrlString = 'https://$url';
              }
              final Uri uri = Uri.parse(launchUrlString);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      previousEnd = match.end;
    }
    if (previousEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(previousEnd),
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.black87,
            height: 1.5,
          ),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
            const SizedBox(height: 16),
            const Text(
              "About",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText.rich(
                  TextSpan(
                    children: _buildLinkedTextSpans(
                      details,
                      isDark,
                      primaryColor,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- SEEN BY SHEET ---
class SeenBySheet extends StatelessWidget {
  final List<Map<String, dynamic>> seenGuests;

  const SeenBySheet({super.key, required this.seenGuests});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
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
            const SizedBox(height: 16),
            const Text(
              "Seen By",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: seenGuests.length,
                itemBuilder: (context, index) {
                  final guest = seenGuests[index];
                  final String displayName =
                      (guest['displayName'] as String?)?.trim() ?? 'Attendee';
                  final String rawPhone =
                      (guest['phoneNumber'] ?? '').toString();
                  final contactName =
                      ContactResolver.instance.resolveName(rawPhone);
                  final bool hasContactName =
                      contactName != null && contactName.trim().isNotEmpty;
                  final String primaryName =
                      ContactResolver.instance.resolveMiniProfileName(
                            rawPhone,
                            fallbackName: displayName,
                          ) ??
                          ContactResolver.instance.formatMiniProfileFallback(
                            displayName,
                          );

                  final String username =
                      (guest['username'] as String?)?.trim() ?? '';
                  final String? avatarUrl = guest['avatarUrl'];
                  final int avatarColor =
                      guest['avatarColor'] ?? Colors.blue.toARGB32();

                  Widget? subtitleWidget;
                  if (hasContactName &&
                      displayName.isNotEmpty &&
                      displayName != primaryName) {
                    subtitleWidget = Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "~ $displayName${username.isNotEmpty ? ' (@$username)' : ''}",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  } else if (username.isNotEmpty) {
                    subtitleWidget = Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "@$username",
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(avatarColor).withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: AppAvatar.fromColorValue(
                        radius: 20,
                        avatarColor: avatarColor,
                        avatarUrl: avatarUrl,
                        displayName: primaryName,
                        fontSize: 16,
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            primaryName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasContactName)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Icon(
                              Icons.contact_phone_outlined,
                              size: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    subtitle: subtitleWidget,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
