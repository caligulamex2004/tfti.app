import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A bottom sheet for managing Squad Needs locally (in-memory) before
/// the event exists in Firestore. Used during the CREATE flow.
/// Mirrors the look/feel of [SquadNeedsSheet] but operates on a
/// `List<String>` callback instead of Firestore writes.
class LocalSquadNeedsSheet extends StatefulWidget {
  final List<String> roles;
  final ValueChanged<List<String>> onChanged;

  const LocalSquadNeedsSheet({
    super.key,
    required this.roles,
    required this.onChanged,
  });

  @override
  State<LocalSquadNeedsSheet> createState() => _LocalSquadNeedsSheetState();
}

class _LocalSquadNeedsSheetState extends State<LocalSquadNeedsSheet> {
  late List<String> _localRoles;
  final _roleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localRoles = List.from(widget.roles);
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  void _addNeed() {
    final title = _roleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _localRoles.add(title));
    widget.onChanged(_localRoles);
    _roleController.clear();
  }

  void _removeNeed(int index) {
    HapticFeedback.mediumImpact();
    setState(() => _localRoles.removeAt(index));
    widget.onChanged(_localRoles);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_box_outlined,
                      color: primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Squad Needs",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // List of current roles
              Flexible(
                child: _localRoles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volunteer_activism,
                              size: 48,
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Add things you need the crew to bring or do\n(e.g. Bring ice, Drive 1st half)",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _localRoles.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pan_tool_outlined,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _localRoles[index],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeNeed(index),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Input Bar
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _roleController,
                        maxLength: 30,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addNeed(),
                        decoration: InputDecoration(
                          hintText: "Add a new need (e.g. Bring Ice)",
                          counterText: "",
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addNeed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
