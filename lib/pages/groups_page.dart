// lib/pages/groups_page.dart
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';
import '../pages/group_chat_page.dart';
import '../models/message.dart';
import '../helper/last_message_time_formatter.dart';
import '../components/my_search_bar.dart';
import '../components/my_group_tile.dart';
import '../services/notifications/notification_service.dart';

/// GROUPS PAGE (content-only version)
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final AuthService _authService = AuthService();

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

    if (currentUserId != null && currentUserId.isNotEmpty) {
      final chatProvider =
      Provider.of<ChatProvider>(context, listen: false);
      // (nothing else needed here for now)
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Start subscriptions here to safely use Provider.of(context)
    _startSubscriptionsIfNeeded();
  }

  void _startSubscriptionsIfNeeded() {
    if (_lastMsgSub != null || _unreadSub != null) return;

    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final chatProvider =
    Provider.of<ChatProvider>(context, listen: false);

    _lastMsgSub =
        chatProvider.lastGroupMessagesPollingStream().listen((map) {
          if (!mounted) return;
          setState(() {
            _lastGroupMessages = map;
          });
        });

    _unreadSub =
        chatProvider.groupUnreadCountsPollingStream(currentUserId).listen(
              (map) {
            if (!mounted) return;
            debugPrint('📥 GroupsPage: unread map from provider: $map');
            setState(() {
              _groupUnreadCounts = map;
            });
          },
        );
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
          'You must be logged in to view your groups'.tr(),
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    final chatProvider =
    Provider.of<ChatProvider>(context, listen: false);

    // 🆕 Access NotificationService singleton
    final notificationService = NotificationService();
    final String? activeChatRoomId = notificationService.activeChatRoomId;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: chatProvider.groupRoomsForUserPollingStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading groups'.tr(),
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
                    'No groups yet'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a group to start chatting with multiple friends at once.'.tr(),
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
            Padding(
              padding:
              const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
              child: MySearchBar(
                controller: _searchController,
                hintText: 'Search groups'.tr(),
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Text("Your groups".tr(),
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
            Expanded(
              child: noMatches
                  ? Center(
                child: Text(
                  'No groups match your search'.tr(),
                  style: TextStyle(
                    color: colorScheme.primary
                        .withValues(alpha: 0.8),
                  ),
                ),
              )
                  : ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(overscroll: false),
                child: ListView.builder(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context)
                        .padding
                        .bottom +
                        96,
                  ),
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = filteredGroups[index];
                    final groupId =
                        group['id']?.toString() ?? '';
                    final groupName =
                    (group['name'] as String?)?.trim().isNotEmpty ==
                        true
                        ? group['name'] as String
                        : 'Group'.tr();
                    final avatarUrl =
                    group['avatar_url'] as String?;

                    final MessageModel? lastMsg =
                    _lastGroupMessages[groupId];

                    // Raw unread from DB
                    final int rawUnread =
                        _groupUnreadCounts[groupId] ?? 0;

                    // 🆕 If this group chat is currently active, hide unread count
                    final int unread =
                    (activeChatRoomId != null &&
                        activeChatRoomId == groupId)
                        ? 0
                        : rawUnread;

                    final String subtitle = lastMsg != null
                        ? _buildLastMessagePreview(
                      msg: lastMsg,
                      currentUserId: currentUserId,
                    )
                        : 'No messages yet'.tr();

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

  String _buildLastMessagePreview({
    required MessageModel msg,
    required String currentUserId,
  }) {
    final raw = msg.message;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final bool isMine = msg.senderId == currentUserId;

    // 👇 Localized "You"
    final String base = isMine ? '${"You".tr()}: $trimmed' : trimmed;

    const maxLen = 40;
    if (base.length <= maxLen) return base;
    return '${base.substring(0, maxLen)}…';
  }

}
