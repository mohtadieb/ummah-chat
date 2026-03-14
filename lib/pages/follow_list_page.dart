/*
FOLLOW LIST PAGE

This page displays a tab bar for a given uid:

- a list of all followers
- a list of all following
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/my_user_tile.dart';
import '../models/user_profile.dart';
import '../services/database/database_provider.dart';
import '../helper/navigate_pages.dart';
import '../services/auth/auth_service.dart';

class FollowListPage extends StatefulWidget {
  final String userId;
  final int initialTabIndex;

  const FollowListPage({
    super.key,
    required this.userId,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider = Provider.of<DatabaseProvider>(
    context,
    listen: false,
  );

  @override
  void initState() {
    super.initState();
    loadFollowerList();
    loadFollowingList();
  }

  Future<void> loadFollowerList() async {
    await databaseProvider.loadUserFollowerProfiles(widget.userId);
  }

  Future<void> loadFollowingList() async {
    await databaseProvider.loadUserFollowingProfiles(widget.userId);
  }

  Widget _buildUserList(List<UserProfile> userList, String emptyMessage) {
    return userList.isEmpty
        ? Center(
      child: Text(
        emptyMessage,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    )
        : ListView.builder(
      itemCount: userList.length,
      itemBuilder: (context, index) {
        final user = userList[index];

        return MyUserTile(
          user: user,
          onTap: () {
            final currentUserId = AuthService().getCurrentUserId();

            if (user.id == currentUserId) {
              goToOwnProfileTab(context);
              return;
            }

            goUserPage(context, user.id);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final followers = listeningProvider.getListOfFollowerProfiles(
      widget.userId,
    );
    final following = listeningProvider.getListOfFollowingProfiles(
      widget.userId,
    );

    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          foregroundColor: cs.onSurface,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            dividerColor: Colors.transparent,
            labelColor: cs.onSurface,
            unselectedLabelColor: cs.onSurface.withValues(alpha: 0.60),
            indicatorColor: cs.primary,
            tabs: [
              Tab(text: "Followers".tr()),
              Tab(text: "Following".tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserList(followers, "No followers..".tr()),
            _buildUserList(following, "No following..".tr()),
          ],
        ),
      ),
    );
  }
}