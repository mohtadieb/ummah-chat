// lib/pages/create_group_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';
import '../services/database/database_provider.dart';
import '../models/user_profile.dart';
import 'group_chat_page.dart';

/// CREATE GROUP PAGE
///
/// - Shows a TextField for group name
/// - Shows list of your friends with checkboxes
/// - On "Create group":
///   - calls ChatProvider.createGroupRoom(...)
///   - navigates to GroupChatPage for that new room
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _groupNameController = TextEditingController();
  final _authService = AuthService();

  // Keep track of selected friend IDs
  final Set<String> _selectedFriendIds = {};

  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup(BuildContext context) async {
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a group name'.tr())),
      );
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one member'.tr())),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final chatProvider =
      Provider.of<ChatProvider>(context, listen: false);

      // Creator + selected friends → initial members
      final roomId = await chatProvider.createGroupRoom(
        name: name,
        creatorId: currentUserId,
        initialMemberIds: _selectedFriendIds.toList(),
      );

      if (!mounted) return;

      // After creating, go straight into the group chat
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            chatRoomId: roomId,
            groupName: name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group:'.tr() + ' $e'))
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final currentUserId = _authService.getCurrentUserId();

    if (currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('New group'.tr()),
          backgroundColor: colorScheme.surface,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'You must be logged in to create a group'.tr(),
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text('New group'.tr()),
      ),
      body: Column(
        children: [
          // Group name input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group name'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select members'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // Friends list (from your friendsStream)
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: dbProvider.friendsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading friends'.tr(),
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // All friends except yourself (just in case)
                final allFriends = (snapshot.data ?? [])
                    .where((u) => u.id != currentUserId)
                    .toList();

                if (allFriends.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'You have no friends yet. Add some friends before creating a group.'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: allFriends.length,
                  itemBuilder: (context, index) {
                    final friend = allFriends[index];
                    final isSelected = _selectedFriendIds.contains(friend.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedFriendIds.add(friend.id);
                          } else {
                            _selectedFriendIds.remove(friend.id);
                          }
                        });
                      },
                      title: Text(
                        friend.name,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '@${friend.username}',
                        style: TextStyle(
                          color:
                          colorScheme.primary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      secondary: _buildFriendAvatar(colorScheme, friend),
                    );
                  },
                );
              },
            ),
          ),

          // Create button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : () => _createGroup(context),
                icon: _isCreating
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.check),
                label:
                Text(_isCreating ? 'Creating...'.tr() : 'Create group'.tr()),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFF0D6746),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendAvatar(ColorScheme colors, UserProfile user) {
    final radius = 18.0;

    if (user.profilePhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user.profilePhotoUrl),
      );
    }

    final initials = () {
      if (user.name.trim().isEmpty) return '?';
      final parts = user.name.trim().split(' ');
      if (parts.length == 1) return parts.first[0].toUpperCase();
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }();

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
