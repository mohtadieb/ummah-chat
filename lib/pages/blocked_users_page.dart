/*
BLOCKED USERS PAGE

Displays a list of users that have been blocked.
Allows unblocking directly from the list.
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/services/database/database_provider.dart';


class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {

  //providers
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

  // on startup,
  @override
  void initState() {
    super.initState();

    // load blocked users
    loadBlockedUsers();
  }

  Future<void> loadBlockedUsers() async {
    await databaseProvider.loadBlockedUsers();
  }

  void _showUnblockConfirmationBox(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unblock User"),
        content: const Text("Are you sure you want to unblock this user?"),
        actions: [
          // cancel Button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          // Unblock button
          TextButton(
            onPressed: () async {
              // unblock user
              await databaseProvider.unblockUser(userId);

              // close box
              Navigator.pop(context);

              // let user know user was successfully unblocked
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User unblocked!")),
              );
            },
            child: const Text("Unblock"),
          ),
        ],
      ),
    );
  }

  // BUILD UI
  @override
  Widget build(BuildContext context) {
    // Listen to changes in blocked users
    final blockedUsers = listeningProvider.blockedUsers;
    // SCAFFOLD
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      // App bar
      appBar: AppBar(
        title: const Text("Blocked Users"),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: blockedUsers.isEmpty
          ? const Center(
        child: Text(
          "No blocked users...",
          style: TextStyle(fontSize: 14),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: blockedUsers.length,
        itemBuilder: (context, index) {
          // get each user
          final user = blockedUsers[index];
          return ListTile(
            title: Text(user.name),
            subtitle: Text('@${user.username}'),
            trailing: IconButton(
              icon: const Icon(Icons.block),
              color: Colors.red,
              onPressed: () => _showUnblockConfirmationBox(user.id),
            ),
          );
        },
      ),
    );
  }
}