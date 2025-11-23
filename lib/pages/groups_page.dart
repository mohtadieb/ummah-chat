import 'dart:async';
import 'package:flutter/material.dart';

import '../services/auth/auth_service.dart';
import '../services/chat/chat_service.dart';
import '../pages/group_chat_page.dart';
import 'create_group_page.dart';
import '../models/message.dart';
import '../helper/time_ago_text.dart'; // <-- make sure this import exists!
import '../components/my_card_tile.dart'; // 🆕 use MyCardTile

/// GROUPS PAGE
///
/// - Shows all group chats where the current user is a member
/// - Data comes from ChatService.groupRoomsForUserPollingStream(...)
/// - Tapping a tile opens GroupChatPage
/// - Shows last message + time ago + unread badge per group
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();

  // Last message per group: { roomId: MessageModel }
  Map<String, MessageModel> _lastGroupMessages = {};

  // Unread counts per group: { roomId: count }
  Map<String, int> _groupUnreadCounts = {};

  StreamSubscription<Map<String, MessageModel>>? _lastMsgSub;
  StreamSubscription<Map<String, int>>? _unreadSub;

  @override
  void initState() {
    super.initState();

    final currentUserId = _authService.getCurrentUserId();

    // Only start polling when a user is logged in
    if (currentUserId != null && currentUserId.isNotEmpty) {
      // Poll last group messages
      _lastMsgSub =
          _chatService.lastGroupMessagesPollingStream().listen((map) {
            if (!mounted) return;
            setState(() {
              _lastGroupMessages = map;
            });
          });

      // Poll unread counts per group
      _unreadSub =
          _chatService.groupUnreadCountsPollingStream(currentUserId).listen(
                (map) {
              if (!mounted) return;
              debugPrint('📥 GroupsPage: unread map from service: $map');
              setState(() {
                _groupUnreadCounts = map;
              });
            },
          );
    }
  }

  @override
  void dispose() {
    _lastMsgSub?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.getCurrentUserId();

    if (currentUserId == null || currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Groups'),
          backgroundColor: colorScheme.surface,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            'You must be logged in to view your groups',
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
        centerTitle: true,
        title: Text(
          'Groups',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.groupRoomsForUserPollingStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading groups',
                style: TextStyle(color: colorScheme.primary),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 52,
                      color: colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No groups yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create a group to start chatting with multiple friends at once.',
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

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final groupId = group['id']?.toString() ?? '';
              final groupName =
              (group['name'] as String?)?.trim().isNotEmpty == true
                  ? group['name'] as String
                  : 'Group';
              final avatarUrl = group['avatar_url'] as String?;

              final MessageModel? lastMsg = _lastGroupMessages[groupId];
              final int unread = _groupUnreadCounts[groupId] ?? 0;

              final String subtitle = lastMsg != null
                  ? _buildLastMessagePreview(
                msg: lastMsg,
                currentUserId: currentUserId,
              )
                  : 'No messages yet';

              return MyCardTile(
                onTap: groupId.isEmpty
                    ? null
                    : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupChatPage(
                        chatRoomId: groupId,
                        groupName: groupName,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    // Avatar
                    _buildGroupAvatar(
                      colorScheme: colorScheme,
                      name: groupName,
                      avatarUrl: avatarUrl,
                    ),

                    const SizedBox(width: 12),

                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread > 0
                                  ? colorScheme.primary
                                  : colorScheme.primary
                                  .withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Time + unread badge
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (lastMsg != null)
                          TimeAgoText(
                            createdAt: lastMsg.createdAt,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (unread > 0)
                          _UnreadBadge(
                            count: unread,
                            colorScheme: colorScheme,
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateGroupPage(),
            ),
          );
        },
        icon: const Icon(Icons.group_add),
        label: const Text('New group'),
        backgroundColor: const Color(0xFF0D6746),
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  /// Simple avatar for group
  Widget _buildGroupAvatar({
    required ColorScheme colorScheme,
    required String name,
    String? avatarUrl,
  }) {
    final radius = 22.0;

    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    final initial =
    name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'G';

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Build a short preview of the last message
  String _buildLastMessagePreview({
    required MessageModel msg,
    required String currentUserId,
  }) {
    final raw = msg.message;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final bool isMine = msg.senderId == currentUserId;
    final String base = isMine ? 'You: $trimmed' : trimmed;

    const maxLen = 40;
    if (base.length <= maxLen) return base;
    return '${base.substring(0, maxLen)}…';
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;

  const _UnreadBadge({
    required this.count,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
