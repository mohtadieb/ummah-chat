/*
FOLLOW LIST PAGE

This page displays a tab bar for a given uid:

- a list of all followers
- a list of all following
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/my_user_tile.dart';
import '../models/user_profile.dart';
import '../services/database/database_provider.dart';

class FollowListPage extends StatefulWidget {
  final String userId;

  const FollowListPage({super.key, required this.userId});

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  // providers
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider = Provider.of<DatabaseProvider>(
    context,
    listen: false,
  );

  // on startup, load followers and following
  @override
  void initState() {
    super.initState();
    loadFollowerList();
    loadFollowingList();
  }

  // load followers
  Future<void> loadFollowerList() async {
    await databaseProvider.loadUserFollowerProfiles(widget.userId);
  }

  // load following
  Future<void> loadFollowingList() async {
    await databaseProvider.loadUserFollowingProfiles(widget.userId);
  }

  // build user list given a list of profiles
  Widget _buildUserList(List<UserProfile> userList, String emptyMessage) {
    return userList.isEmpty
        ?
          // empty message if there are no users
          Center(child: Text(emptyMessage))
        :
          // user list
          ListView.builder(
            itemCount: userList.length,
            itemBuilder: (context, index) {
              final user = userList[index];
              return MyUserTile(user: user);
            },
          );
  }

  // BUILD UI
  @override
  Widget build(BuildContext context) {

    // listen to followers & following
    final followers = listeningProvider.getListOfFollowerProfiles(
      widget.userId,
    );
    final following = listeningProvider.getListOfFollowingProfiles(
      widget.userId,
    );

    // TAB CONTROLLER
    return DefaultTabController(
      length: 2,

      // SCAFFOLD
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,

        // App bar
        appBar: AppBar(
          foregroundColor: Theme.of(context).colorScheme.primary,

          // Tab bar
          bottom: TabBar(
            dividerColor: Colors.transparent,
            labelColor: Theme.of(context).colorScheme.inversePrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.secondary,

            // Tabs
            tabs: const [
              Tab(text: "Followers"),
              Tab(text: "Following"),
            ],
          ),
        ),

        // Tab bar view
        body: TabBarView(
          children: [
            _buildUserList(followers, "No followers.."),
            _buildUserList(following, "No following.."),
          ],
        ),
      ),
    );
  }
}
