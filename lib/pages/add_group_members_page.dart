// lib/pages/add_group_members_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/chat/chat_provider.dart';
import '../services/database/database_provider.dart';

/// ADD GROUP MEMBERS PAGE
///
/// Re-uses your existing friends stream to let the user pick
/// extra members for an existing group chat.
/// - Shows all friends
/// - Friends that are already in the group are disabled with an "In group" label
/// - Selected friends are added via ChatProvider.addUsersToGroup(...)
class AddGroupMembersPage extends StatefulWidget {
  final String chatRoomId;
  final Set<String> existingMemberIds;
  final String groupName;

  const AddGroupMembersPage({
    super.key,
    required this.chatRoomId,
    required this.existingMemberIds,
    required this.groupName,
  });

  @override
  State<AddGroupMembersPage> createState() => _AddGroupMembersPageState();
}

class _AddGroupMembersPageState extends State<AddGroupMembersPage> {
  // Locally selected friend IDs to add
  final Set<String> _selectedUserIds = {};

  bool _isSaving = false;

  Future<void> _save() async {
    if (_selectedUserIds.isEmpty || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final chatProvider =
      Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.addUsersToGroup(
        chatRoomId: widget.chatRoomId,
        userIds: _selectedUserIds.toList(),
      );

      if (!mounted) return;

      // Pop and indicate that something changed (members added)
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('❌ AddGroupMembersPage _save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add members. Please try again.'.tr()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add members'.tr()),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
      ),
      body: StreamBuilder<List<UserProfile>>(
        stream: dbProvider.friendsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading friends'.tr(),
                style: TextStyle(color: colorScheme.primary),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final friends = snapshot.data ?? [];

          if (friends.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 52,
                      color: colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text('No friends yet'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Add friends first before inviting them to a group.'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: friends.length,
            separatorBuilder: (_, __) => Divider(
              height: 0,
              color: colorScheme.secondary.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final user = friends[index];
              final alreadyInGroup = widget.existingMemberIds.contains(user.id);
              final isSelected = _selectedUserIds.contains(user.id);

              final displayName =
              user.name.isNotEmpty ? user.name : user.username;

              return ListTile(
                enabled: !alreadyInGroup,
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor:
                  colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(
                  displayName.isNotEmpty ? displayName : 'User'.tr(),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: user.username.isNotEmpty
                    ? Text('@${user.username}',
                  style: TextStyle(
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                )
                    : null,
                trailing: alreadyInGroup
                    ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('In group'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color:
                      colorScheme.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                    : Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedUserIds.add(user.id);
                      } else {
                        _selectedUserIds.remove(user.id);
                      }
                    });
                  },
                ),
                onTap: alreadyInGroup
                    ? null
                    : () {
                  setState(() {
                    if (isSelected) {
                      _selectedUserIds.remove(user.id);
                    } else {
                      _selectedUserIds.add(user.id);
                    }
                  });
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
              _selectedUserIds.isEmpty || _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6746),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text('Add to group'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
