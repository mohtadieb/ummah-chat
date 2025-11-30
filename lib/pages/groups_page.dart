import 'dart:async';
import 'package:flutter/material.dart';

import '../services/auth/auth_service.dart';
import '../services/chat/chat_service.dart';
import '../pages/group_chat_page.dart';
import '../models/message.dart';
import '../helper/last_message_time_formatter.dart';
import '../components/my_search_bar.dart';
import '../components/my_group_tile.dart';

/// GROUPS PAGE (content-only version)
///
/// - Shows all group chats where the current user is a member
/// - Data comes from ChatService.groupRoomsForUserPollingStream(...)
//  - Tapping a tile opens GroupChatPage
/// - Shows last message + time + unread badge per group
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

  // 🔍 Local search within groups list
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.getCurrentUserId();

    if (currentUserId == null || currentUserId.isEmpty) {
      return Center(
        child: Text(
          'You must be logged in to view your groups',
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    // ⬇️ No Scaffold here; this is content-only inside ChatTabsPage.
    return StreamBuilder<List<Map<String, dynamic>>>(
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

        // If there are literally no groups at all, show the empty state
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

        // 🎯 Apply local search filter on group name
        List<Map<String, dynamic>> filteredGroups = groups;
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          filteredGroups = groups.where((g) {
            final name = (g['name'] as String? ?? '').toLowerCase();
            return name.contains(q);
          }).toList();
        }

        final noMatches =
            _searchQuery.trim().isNotEmpty && filteredGroups.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 Local search bar for groups (same style as FriendsPage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
              child: MySearchBar(
                controller: _searchController,
                hintText: 'Search groups',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onClear: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
            ),

            const SizedBox(height: 4),

            // Header with total groups count
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Text(
                    "Your groups",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${groups.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Groups list or "no matches" message
            Expanded(
              child: noMatches
                  ? Center(
                child: Text(
                  'No groups match your search',
                  style: TextStyle(
                    color: colorScheme.primary
                        .withValues(alpha: 0.8),
                  ),
                ),
              )
                  : ScrollConfiguration(
                // ✅ Disable stretch / weird independent text movement
                behavior: ScrollConfiguration.of(context)
                    .copyWith(overscroll: false),
                child: ListView.builder(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom:
                    MediaQuery.of(context).padding.bottom +
                        96, // match FriendsPage padding / avoid FAB overlap
                  ),
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = filteredGroups[index];
                    final groupId = group['id']?.toString() ?? '';
                    final groupName =
                    (group['name'] as String?)?.trim().isNotEmpty ==
                        true
                        ? group['name'] as String
                        : 'Group';
                    final avatarUrl = group['avatar_url'] as String?;

                    final MessageModel? lastMsg =
                    _lastGroupMessages[groupId];
                    final int unread =
                        _groupUnreadCounts[groupId] ?? 0;

                    final String subtitle = lastMsg != null
                        ? _buildLastMessagePreview(
                      msg: lastMsg,
                      currentUserId: currentUserId,
                    )
                        : 'No messages yet';

                    final String? lastTimeLabel = lastMsg != null
                        ? formatLastMessageTime(lastMsg.createdAt)
                        : null;

                    return MyGroupTile(
                      groupName: groupName,
                      avatarUrl: avatarUrl,
                      lastMessagePreview: subtitle,
                      lastMessageTimeLabel: lastTimeLabel,
                      unreadCount: unread,
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
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
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
