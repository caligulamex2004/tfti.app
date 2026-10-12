import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/friend_service.dart';
import '../components/shared/shared_sliver_app_bar.dart';
import '../components/teams/create_team_sheet.dart';
import '../components/teams/team_card.dart';
import 'team_members_page.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  String? _selectedCircleId;
  String? _selectedCircleName;
  bool _autoOpenNewCircle = false;

  Future<void> _handleCreateTeamTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final hasFriends = await FriendService.hasFriends(user.uid);
      if (!mounted) return;

      if (!hasFriends) {
        CreateTeamSheet.showNoFriendsDialog(context);
        return;
      }
      _showCreateSheet(user.uid);
    } catch (_) {
      if (mounted) {
        _showCreateSheet(user.uid);
      }
    }
  }

  void _showCreateSheet(String uid) {
    CreateTeamSheet.showCreate(
      context: context,
      onCreated: (name) async {
        final newId = await TeamService.createTeam(uid: uid, name: name);
        if (!mounted) return;

        if (MediaQuery.orientationOf(context) == Orientation.landscape) {
          setState(() {
            _selectedCircleId = newId;
            _selectedCircleName = name;
            _autoOpenNewCircle = true;
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeamMembersPage(
                circleId: newId,
                circleName: name,
                autoOpenAddMembers: true,
              ),
            ),
          );
        }
      },
    );
  }

  void _showRenameSheet(String uid, TeamCircle team) {
    CreateTeamSheet.showRename(
      context: context,
      currentName: team.name,
      onRenamed: (newName) async {
        await TeamService.renameTeam(
          uid: uid,
          circleId: team.id,
          newName: newName,
        );
        if (_selectedCircleId == team.id && mounted) {
          setState(() => _selectedCircleName = newName);
        }
      },
    );
  }

  Future<void> _handleDeleteTeam(String uid, TeamCircle team) async {
    if (_selectedCircleId == team.id && mounted) {
      setState(() {
        _selectedCircleId = null;
        _selectedCircleName = null;
      });
    }
    await TeamService.deleteTeam(uid: uid, circleId: team.id);
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.touch_app,
              size: 64,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Select a Team to view members",
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.supervised_user_circle_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No Teams Yet",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Create one to group your friends!",
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsList(
    BuildContext context,
    String uid,
    bool isLandscape,
    bool isDark,
    Color primaryColor,
  ) {
    return StreamBuilder<List<TeamCircle>>(
      stream: TeamService.teamsStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final teams = snapshot.data!;

        return CustomScrollView(
          slivers: [
            SharedSliverAppBar(
              title: "Teams",
              collapsedTitle: "Teams",
              expandedHeight: isLandscape ? 56.0 : 140.0,
              hasBackButton: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: InkWell(
                      onTap: _handleCreateTeamTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: primaryColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Create",
                              style: TextStyle(
                                color: primaryColor,
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
              bottomContent: Row(
                children: [
                  Icon(
                    Symbols.circles,
                    color: primaryColor.withValues(alpha: 0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${teams.length} ${teams.length == 1 ? 'Team' : 'Teams'}",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (teams.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(isDark),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8.0 : 16.0,
                  vertical: 16.0,
                ),
                sliver: SliverList.builder(
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    final isSelected = isLandscape && _selectedCircleId == team.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TeamCard(
                        team: team,
                        myUid: uid,
                        isSelected: isSelected,
                        isLandscape: isLandscape,
                        onTap: () {
                          if (isLandscape) {
                            setState(() {
                              _selectedCircleId = team.id;
                              _selectedCircleName = team.name;
                              _autoOpenNewCircle = false;
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeamMembersPage(
                                  circleId: team.id,
                                  circleName: team.name,
                                ),
                              ),
                            );
                          }
                        },
                        onRename: () => _showRenameSheet(uid, team),
                        onDelete: () => _handleDeleteTeam(uid, team),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLandscape = MediaQuery.sizeOf(context).width > 600;

    final listContent = _buildTeamsList(
      context,
      user.uid,
      isLandscape,
      isDark,
      primaryColor,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 40,
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: listContent,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
                Expanded(
                  flex: 60,
                  child: _selectedCircleId != null && _selectedCircleName != null
                      ? TeamMembersPage(
                          key: ValueKey(_selectedCircleId),
                          circleId: _selectedCircleId!,
                          circleName: _selectedCircleName!,
                          autoOpenAddMembers: _autoOpenNewCircle,
                        )
                      : _buildPlaceholder(isDark),
                ),
              ],
            )
          : Scaffold(
              backgroundColor: Colors.transparent,
              body: listContent,
            ),
    );
  }
}
