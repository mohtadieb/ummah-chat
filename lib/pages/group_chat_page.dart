// lib/pages/group_chat_page.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../models/user.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_service.dart';
import '../components/my_chat_bubble.dart';
import '../components/my_chat_text_field.dart';
import '../helper/chat_separators.dart';
import '../helper/chat_media_helper.dart';
import 'add_group_members_page.dart';

enum _GroupMenuAction { viewMembers, addMembers, leaveGroup, deleteGroup }

/// Same grouping helper as in ChatPage
class _MessageGroup {
  final List<MessageModel> messages;
  final int firstIndex;

  _MessageGroup({required this.messages, required this.firstIndex});

  MessageModel get first => messages.first;

  MessageModel get last => messages.last;
}

class GroupChatPage extends StatefulWidget {
  final String chatRoomId;
  final String groupName;

  const GroupChatPage({
    super.key,
    required this.chatRoomId,
    required this.groupName,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final DatabaseService _dbService = DatabaseService();

  late final String _currentUserId;

  bool _isLoadingMembers = true;
  List<UserProfile> _members = [];
  final Map<String, UserProfile> _userCache = {};

  final Map<String, Color> _senderColorCache = {};

  int _lastMessageCount = 0;

  Timer? _presenceTimer;

  bool _isCurrentUserAdmin = false;

  @override
  void initState() {
    super.initState();

    _currentUserId = _authService.getCurrentUserId() ?? '';
    debugPrint(
      '🟢 GroupChatPage opened for room=${widget.chatRoomId}, user=$_currentUserId',
    );

    _loadMembers();

    final provider = Provider.of<ChatProvider>(context, listen: false);
    provider.listenToRoom(widget.chatRoomId);

    if (_currentUserId.isNotEmpty) {
      _chatService.markGroupMessagesAsRead(widget.chatRoomId, _currentUserId);
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollDown);
      }
    });

    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_currentUserId.isNotEmpty) {
        await _chatService.updateLastSeen(_currentUserId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _focusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoadingMembers = true;
    });

    try {
      final links = await _chatService.fetchGroupMemberLinks(widget.chatRoomId);

      final List<UserProfile> profiles = [];
      bool isAdmin = false;

      for (final row in links) {
        final String userId = row['user_id']?.toString() ?? '';
        final String role = row['role']?.toString() ?? '';
        if (userId.isEmpty) continue;

        if (userId == _currentUserId && role == 'admin') {
          isAdmin = true;
        }

        if (_userCache.containsKey(userId)) {
          profiles.add(_userCache[userId]!);
        } else {
          final profile = await _dbService.getUserFromDatabase(userId);
          if (profile != null) {
            _userCache[userId] = profile;
            profiles.add(profile);
          }
        }
      }

      setState(() {
        _members = profiles;
        _isCurrentUserAdmin = isAdmin;
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error loading group members: $e');
      setState(() {
        _isLoadingMembers = false;
      });
    }
  }

  void _showMembersBottomSheet() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        if (_isLoadingMembers) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_members.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No members found')),
          );
        }

        return SizedBox(
          height: 320,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _members.length,
            separatorBuilder: (_, __) => Divider(
              height: 0,
              color: colorScheme.secondary.withValues(alpha: 0.5),
            ),
            itemBuilder: (_, index) {
              final user = _members[index];
              final name = user.name.isNotEmpty ? user.name : user.username;

              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: user.username.isNotEmpty
                    ? Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmLeaveGroup() async {
    if (_currentUserId.isEmpty) return;

    final colorScheme = Theme.of(context).colorScheme;

    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Leave group?'),
          content: Text(
            'You will no longer receive messages from "${widget.groupName}".',
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Leave', style: TextStyle(color: Colors.red[600])),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) return;

    try {
      await _chatService.leaveGroup(
        chatRoomId: widget.chatRoomId,
        userId: _currentUserId,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error leaving group: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to leave group. Please try again.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteGroup() async {
    if (!_isCurrentUserAdmin) return;

    final colorScheme = Theme.of(context).colorScheme;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete group?'),
          content: Text(
            'This will permanently delete "${widget.groupName}" '
            'for all members, including all messages.',
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red[600])),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _chatService.deleteGroupAsAdmin(chatRoomId: widget.chatRoomId);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error deleting group: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete group. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openAddMembers() async {
    if (_members.isEmpty) {
      await _loadMembers();
    }

    final existingIds = _members.map((u) => u.id).toSet();

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddGroupMembersPage(
          chatRoomId: widget.chatRoomId,
          existingMemberIds: existingIds,
          groupName: widget.groupName,
        ),
      ),
    );

    if (changed == true) {
      await _loadMembers();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    const threshold = 80.0;
    return (pos.pixels - pos.minScrollExtent).abs() <= threshold;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_currentUserId.isEmpty) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);

    _messageController.clear();
    _scrollDown();

    await provider.sendGroupMessage(widget.chatRoomId, _currentUserId, text);

    await _chatService.updateLastSeen(_currentUserId);
  }

  String _displayNameForSender(String senderId) {
    final profile =
        _userCache[senderId] ??
        _members.firstWhere(
          (u) => u.id == senderId,
          orElse: () => UserProfile(
            id: senderId,
            name: '',
            email: '',
            username: '',
            bio: '',
            profilePhotoUrl: '',
            createdAt: DateTime.now().toUtc(),
            lastSeenAt: null,
          ),
        );

    if (profile.name.isNotEmpty) return profile.name;
    if (profile.username.isNotEmpty) return profile.username;
    return 'User';
  }

  Color _colorForSender(String senderId, ColorScheme colorScheme) {
    if (_senderColorCache.containsKey(senderId)) {
      return _senderColorCache[senderId]!;
    }

    final palette = <Color>[
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFEAB308),
      const Color(0xFF22C55E),
      const Color(0xFF06B6D4),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    int hash = 0;
    for (int i = 0; i < senderId.length; i++) {
      hash = (hash + senderId.codeUnitAt(i)) & 0x7FFFFFFF;
    }

    final color = palette[hash % palette.length];
    _senderColorCache[senderId] = color;
    return color;
  }

  /// Group flat message list into logical bubbles
  List<_MessageGroup> _buildMessageGroups(List<MessageModel> messages) {
    final List<_MessageGroup> groups = [];
    if (messages.isEmpty) return groups;

    _MessageGroup? currentGroup;

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      if (currentGroup == null) {
        currentGroup = _MessageGroup(messages: [msg], firstIndex: i);
        groups.add(currentGroup);
        continue;
      }

      final base = currentGroup.messages.first;

      final sameSender = msg.senderId == base.senderId;
      final sameCaption = msg.message == base.message;
      final sameCreatedAt = msg.createdAt.isAtSameMomentAs(base.createdAt);

      final baseHasMedia =
          (base.imageUrl?.trim().isNotEmpty ?? false) ||
          (base.videoUrl?.trim().isNotEmpty ?? false);
      final msgHasMedia =
          (msg.imageUrl?.trim().isNotEmpty ?? false) ||
          (msg.videoUrl?.trim().isNotEmpty ?? false);
      final bothHaveMedia = baseHasMedia && msgHasMedia;

      final canGroup =
          sameSender && sameCaption && bothHaveMedia && sameCreatedAt;

      if (canGroup) {
        currentGroup.messages.add(msg);
      } else {
        currentGroup = _MessageGroup(messages: [msg], firstIndex: i);
        groups.add(currentGroup);
      }
    }

    return groups;
  }

  /// Show bottom sheet with list of users who liked a group message
  Future<void> _showLikesBottomSheet(List<String> userIds) async {
    final colorScheme = Theme.of(context).colorScheme;

    final uniqueIds = userIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) return;

    List<UserProfile> resolveProfiles() {
      final List<UserProfile> profiles = [];
      for (final id in uniqueIds) {
        UserProfile? profile = _userCache[id];
        profile ??= _members.firstWhere(
          (u) => u.id == id,
          orElse: () => UserProfile(
            id: id,
            name: '',
            email: '',
            username: '',
            bio: '',
            profilePhotoUrl: '',
            createdAt: DateTime.now().toUtc(),
            lastSeenAt: null,
          ),
        );
        profiles.add(profile);
      }
      return profiles;
    }

    if (!mounted) return;

    final profiles = resolveProfiles();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        if (profiles.isEmpty) {
          return const SizedBox(
            height: 220,
            child: Center(child: Text('No likes yet')),
          );
        }

        return SizedBox(
          height: 320,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => Divider(
              height: 0,
              color: colorScheme.secondary.withValues(alpha: 0.5),
            ),
            itemBuilder: (_, index) {
              final user = profiles[index];
              final isYou = user.id == _currentUserId;

              final name = user.name.isNotEmpty
                  ? user.name
                  : (user.username.isNotEmpty ? user.username : user.email);

              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(You)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: user.username.isNotEmpty
                    ? Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  /// DELETE MESSAGE
  Future<void> _confirmDeleteGroupMessage(String messageId) async {
    final colorScheme = Theme.of(context).colorScheme;
    if (_currentUserId.isEmpty) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text(
            'This message will be deleted for everyone in the group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await _chatService.deleteMessageForEveryone(
      messageId: messageId,
      userId: _currentUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final memberCount = _members.length;
    final subtitleText = _isLoadingMembers
        ? 'Loading members...'
        : memberCount == 0
        ? 'No members'
        : '$memberCount member${memberCount == 1 ? '' : 's'}';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.primary,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitleText,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_GroupMenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) async {
              switch (action) {
                case _GroupMenuAction.viewMembers:
                  _showMembersBottomSheet();
                  break;
                case _GroupMenuAction.addMembers:
                  await _openAddMembers();
                  break;
                case _GroupMenuAction.leaveGroup:
                  await _confirmLeaveGroup();
                  break;
                case _GroupMenuAction.deleteGroup:
                  await _confirmDeleteGroup();
                  break;
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<_GroupMenuAction>>[];

              items.add(
                PopupMenuItem(
                  value: _GroupMenuAction.viewMembers,
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text('View members'),
                    ],
                  ),
                ),
              );

              if (_isCurrentUserAdmin) {
                items.add(
                  PopupMenuItem(
                    value: _GroupMenuAction.addMembers,
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Text('Add members'),
                      ],
                    ),
                  ),
                );

                items.add(
                  PopupMenuItem(
                    value: _GroupMenuAction.deleteGroup,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_forever_outlined,
                          size: 20,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 12),
                        const Text('Delete group'),
                      ],
                    ),
                  ),
                );
              }

              items.add(const PopupMenuDivider());

              items.add(
                PopupMenuItem(
                  value: _GroupMenuAction.leaveGroup,
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red.shade600),
                      const SizedBox(width: 12),
                      const Text('Leave group'),
                    ],
                  ),
                ),
              );

              return items;
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  final rawMessages = provider.getMessages(widget.chatRoomId);

                  if (rawMessages.isEmpty) {
                    return const Center(child: Text("No messages yet"));
                  }

                  final messages = rawMessages
                      .map((m) => MessageModel.fromMap(m))
                      .toList();

                  // unread counts still based on flat messages
                  int unreadCount = 0;
                  int? firstUnreadIndexFromStart;
                  if (_currentUserId.isNotEmpty) {
                    for (int i = 0; i < messages.length; i++) {
                      final m = messages[i];
                      final isMine = m.senderId == _currentUserId;
                      if (!m.isRead && !isMine) {
                        unreadCount++;
                        firstUnreadIndexFromStart ??= i;
                      }
                    }
                  }

                  // groups
                  final groups = _buildMessageGroups(messages);

                  // map message index -> group index
                  final messageIndexToGroupIndex = List<int>.filled(
                    messages.length,
                    0,
                  );
                  for (int gi = 0; gi < groups.length; gi++) {
                    final g = groups[gi];
                    for (final m in g.messages) {
                      final idx = messages.indexOf(m);
                      if (idx != -1) {
                        messageIndexToGroupIndex[idx] = gi;
                      }
                    }
                  }

                  int? firstUnreadGroupIndex;
                  if (firstUnreadIndexFromStart != null) {
                    firstUnreadGroupIndex =
                        messageIndexToGroupIndex[firstUnreadIndexFromStart];
                  }

                  // auto-scroll + mark as read
                  if (messages.length != _lastMessageCount) {
                    if (_isNearBottom()) {
                      _scrollDown();
                    }

                    _lastMessageCount = messages.length;

                    if (_currentUserId.isNotEmpty) {
                      _chatService.markGroupMessagesAsRead(
                        widget.chatRoomId,
                        _currentUserId,
                      );
                    }
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final groupIndex = groups.length - 1 - index;
                      final group = groups[groupIndex];

                      final firstMsg = group.first;
                      final lastMsg = group.last;

                      final bool isCurrentUser =
                          firstMsg.senderId == _currentUserId;

                      final String senderName = _displayNameForSender(
                        firstMsg.senderId,
                      );

                      final Color senderColor = _colorForSender(
                        firstMsg.senderId,
                        colorScheme,
                      );

                      final imageUrls = group.messages
                          .map((m) => m.imageUrl)
                          .whereType<String>()
                          .where((u) => u.trim().isNotEmpty)
                          .toList();

                      // 🆕 first video in this group (if any)
                      final String? groupVideoUrl = group.messages
                          .map((m) => m.videoUrl)
                          .whereType<String>()
                          .firstWhere(
                            (u) => u.trim().isNotEmpty,
                            orElse: () => '',
                          );
                      final String? effectiveVideoUrl =
                          (groupVideoUrl != null &&
                              groupVideoUrl.trim().isNotEmpty)
                          ? groupVideoUrl
                          : null;

                      final List<String> likedBy = lastMsg.likedBy;
                      final bool isLikedByMe =
                          _currentUserId.isNotEmpty &&
                          likedBy.contains(_currentUserId);
                      final int likeCount = likedBy.length;

                      final msgDate = firstMsg.createdAt;
                      DateTime? prevDate;
                      if (groupIndex > 0) {
                        prevDate = groups[groupIndex - 1].first.createdAt;
                      }
                      final showDayDivider =
                          prevDate == null || !isSameDay(msgDate, prevDate);

                      final showUnreadSeparator =
                          unreadCount > 0 &&
                          firstUnreadGroupIndex != null &&
                          groupIndex == firstUnreadGroupIndex;

                      return Column(
                        children: [
                          if (showDayDivider)
                            buildDayBubble(context: context, date: msgDate),
                          if (showUnreadSeparator)
                            buildUnreadBubble(
                              context: context,
                              unreadCount: unreadCount,
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 8,
                            ),
                            child: Align(
                              alignment: isCurrentUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: MyChatBubble(
                                message: lastMsg.message,
                                imageUrls: imageUrls,
                                imageUrl: imageUrls.isNotEmpty
                                    ? imageUrls.first
                                    : null,
                                videoUrl: lastMsg.videoUrl,
                                isCurrentUser: isCurrentUser,
                                createdAt: lastMsg.createdAt,
                                isRead: lastMsg.isRead,
                                isDelivered: lastMsg.isDelivered,
                                isLikedByMe: isLikedByMe,
                                likeCount: likeCount,
                                isUploading: lastMsg.isUploading,
                                isDeleted: lastMsg.isDeleted,
                                // 🆕
                                onDoubleTap: () async {
                                  if (_currentUserId.isEmpty) return;

                                  await _chatService.toggleLikeMessage(
                                    messageId: lastMsg.id,
                                    userId: _currentUserId,
                                  );
                                },
                                onLongPress: isCurrentUser && !lastMsg.isDeleted
                                    ? () =>
                                          _confirmDeleteGroupMessage(lastMsg.id)
                                    : null,
                                // 🆕
                                onLikeTap: likedBy.isEmpty
                                    ? null
                                    : () => _showLikesBottomSheet(likedBy),
                                senderName: isCurrentUser ? null : senderName,
                                senderColor: isCurrentUser ? null : senderColor,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: MyChatTextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  onSendPressed: _sendMessage,
                  onEmojiPressed: () => debugPrint("Emoji pressed"),
                  onAttachmentPressed: () async {
                    if (_currentUserId.isEmpty) return;

                    await ChatMediaHelper.openAttachmentSheetForGroup(
                      context: context,
                      chatRoomId: widget.chatRoomId,
                      currentUserId: _currentUserId,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
