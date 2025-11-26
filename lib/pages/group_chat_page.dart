import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/user.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_service.dart';
import '../components/my_chat_bubble.dart';
import '../components/my_chat_text_field.dart';
import '../components/my_voice_message_bubble.dart';
import '../components/my_selectable_bubble.dart';
import '../components/my_reply_preview_bar.dart';
import '../helper/chat_separators.dart';
import '../helper/chat_media_helper.dart';
import '../helper/message_grouping.dart';
import '../helper/voice_recorder_helper.dart';
import '../helper/likes_bottom_sheet_helper.dart';
import 'add_group_members_page.dart';

enum _GroupMenuAction { viewMembers, addMembers, leaveGroup, deleteGroup }

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

  // current reply target
  MessageModel? _replyTo;

  // 🎙 Voice recorder controller (extracted)
  late final VoiceRecorderController _voiceRecorder;

  // 🧹 Multi-select delete
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  @override
  void initState() {
    super.initState();

    _currentUserId = _authService.getCurrentUserId() ?? '';
    debugPrint(
      '🟢 GroupChatPage opened for room=${widget.chatRoomId}, user=$_currentUserId',
    );

    _voiceRecorder = VoiceRecorderController(
      debugTag: 'Group',
      onTick: () {
        if (mounted) {
          setState(() {});
        }
      },
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
    _voiceRecorder.dispose();

    _focusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Members & admin
  // ---------------------------------------------------------------------------

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
                    color:
                    colorScheme.primary.withValues(alpha: 0.7),
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
              child: Text(
                'Leave',
                style: TextStyle(color: Colors.red[600]),
              ),
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
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red[600]),
              ),
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

  // ---------------------------------------------------------------------------
  // Scroll
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Reply
  // ---------------------------------------------------------------------------

  void _startReplyToGroupMessage(MessageModel msg) {
    setState(() {
      _replyTo = msg;
    });
    _focusNode.requestFocus();
  }

  void _cancelReplyToGroupMessage() {
    if (_replyTo == null) return;
    setState(() {
      _replyTo = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Voice recording (group) using VoiceRecorderController
  // ---------------------------------------------------------------------------

  void _handleMicLongPressStart() {
    if (_voiceRecorder.isRecording) return;

    _voiceRecorder.start().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleMicLongPressEnd() {
    _stopRecordingAndSend();
  }

  Future<void> _handleMicCancel() async {
    if (!_voiceRecorder.isRecording) return;

    try {
      await _voiceRecorder.stop(); // discard
      if (mounted) {
        setState(() {});
      }
      debugPrint('🎤 Group voice recording cancelled by slide');
    } catch (e) {
      debugPrint('Error cancelling group voice recording: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final recorded = await _voiceRecorder.stop();
    if (recorded == null) {
      // too short or failed
      return;
    }

    if (_currentUserId.isEmpty) return;

    try {
      final messageId = const Uuid().v4();

      final audioUrl = await _chatService.uploadVoiceFile(
        chatRoomId: widget.chatRoomId,
        messageId: messageId,
        filePath: recorded.filePath,
      );

      await _chatService.sendVoiceMessageGroup(
        chatRoomId: widget.chatRoomId,
        senderId: _currentUserId,
        audioUrl: audioUrl,
        durationSeconds: recorded.durationSeconds,
        replyToMessageId: _replyTo?.id,
      );

      setState(() {
        _replyTo = null;
      });

      await _chatService.updateLastSeen(_currentUserId);

      debugPrint('✅ Group voice message sent');
    } catch (e) {
      debugPrint('Error sending group voice message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Send text
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_currentUserId.isEmpty) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);

    final replyId = _replyTo?.id;

    _messageController.clear();
    _scrollDown();

    await provider.sendGroupMessage(
      widget.chatRoomId,
      _currentUserId,
      text,
      replyToMessageId: replyId,
    );

    setState(() {
      _replyTo = null;
    });

    await _chatService.updateLastSeen(_currentUserId);
  }

  // ---------------------------------------------------------------------------
  // Helpers (display name, colors, likes, delete, reply previews)
  // ---------------------------------------------------------------------------

  String _displayNameForSender(String senderId) {
    final profile = _userCache[senderId] ??
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

  List<UserProfile> _resolveProfilesForIds(List<String> userIds) {
    final uniqueIds = userIds.toSet().where((id) => id.isNotEmpty).toList();
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

  Future<void> _openLikesBottomSheet(List<String> userIds) async {
    final uniqueIds = userIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) return;

    await LikesBottomSheetHelper.show(
      context: context,
      currentUserId: _currentUserId.isEmpty ? null : _currentUserId,
      loadProfiles: () async {
        return _resolveProfilesForIds(uniqueIds);
      },
    );
  }

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
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
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

  // Multi-select helpers
  void _startSelection(MessageModel msg) {
    if (msg.senderId != _currentUserId) {
      _onGroupBubbleLongPress(msg, false);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds
        ..clear()
        ..add(msg.id);
    });
  }

  void _toggleSelection(MessageModel msg) {
    if (msg.senderId != _currentUserId) return;

    setState(() {
      if (_selectedMessageIds.contains(msg.id)) {
        _selectedMessageIds.remove(msg.id);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(msg.id);
      }
    });
  }

  Future<void> _confirmDeleteSelectedGroupMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    if (_currentUserId.isEmpty) return;

    final colorScheme = Theme.of(context).colorScheme;
    final count = _selectedMessageIds.length;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Delete $count message${count == 1 ? '' : 's'}?'),
          content: const Text(
            'Selected messages will be deleted for everyone in the group.',
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
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final ids = List<String>.from(_selectedMessageIds);
    for (final id in ids) {
      await _chatService.deleteMessageForEveryone(
        messageId: id,
        userId: _currentUserId,
      );
    }

    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _replyToSelectedGroupMessage() async {
    if (!_isSelectionMode || _selectedMessageIds.length != 1) return;
    if (widget.chatRoomId.isEmpty) return;

    final selectedId = _selectedMessageIds.first;

    final provider = Provider.of<ChatProvider>(context, listen: false);
    final rawMessages = provider.getMessages(widget.chatRoomId);

    final messages = rawMessages.map((m) => MessageModel.fromMap(m)).toList();

    MessageModel? target;
    try {
      target = messages.firstWhere((m) => m.id == selectedId);
    } catch (_) {
      target = null;
    }

    if (target == null) return;

    setState(() {
      _replyTo = target;
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });

    _focusNode.requestFocus();
  }

  Future<void> _onGroupBubbleLongPress(
      MessageModel msg,
      bool isCurrentUser,
      ) async {
    if (msg.isDeleted) return;

    HapticFeedback.mediumImpact();

    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.reply,
                  color: colorScheme.primary,
                ),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(context).pop();
                  _startReplyToGroupMessage(msg);
                },
              ),
              if (isCurrentUser) ...[
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDeleteGroupMessage(msg.id);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Unified handler: selection vs normal long-press
  void _handleGroupBubbleLongPress(MessageModel msg, bool isCurrentUser) {
    if (msg.isDeleted) return;

    if (_isSelectionMode && msg.senderId == _currentUserId) {
      _toggleSelection(msg);
      return;
    }

    if (msg.senderId == _currentUserId) {
      _startSelection(msg);
      return;
    }

    _onGroupBubbleLongPress(msg, isCurrentUser);
  }

  Widget _buildReplyPreviewBar(MessageModel msg) {
    final author = _displayNameForSender(msg.senderId);

    String label;
    if (msg.message.trim().isNotEmpty) {
      label = msg.message.trim();
    } else if ((msg.imageUrl ?? '').trim().isNotEmpty) {
      label = 'Photo';
    } else if ((msg.videoUrl ?? '').trim().isNotEmpty) {
      label = 'Video';
    } else if ((msg.audioUrl ?? '').trim().isNotEmpty || msg.isAudio) {
      label = 'Voice message';
    } else {
      label = 'Message';
    }

    return MyReplyPreviewBar(
      author: author,
      label: label,
      onCancel: _cancelReplyToGroupMessage,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final memberCount = _members.length;
    final subtitleText = _isLoadingMembers
        ? 'Loading members...'
        : memberCount == 0
        ? 'No members'
        : '$memberCount member${memberCount == 1 ? '' : 's'}';

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) {
        if (didPop) return;

        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedMessageIds.clear();
          });
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: colorScheme.primary,
          centerTitle: false,
          title: _isSelectionMode
              ? Text(
            '${_selectedMessageIds.length} selected',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )
              : Column(
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
                  color:
                  colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          actions: _isSelectionMode
              ? [
            if (_selectedMessageIds.length == 1)
              IconButton(
                icon: const Icon(Icons.reply),
                onPressed: _replyToSelectedGroupMessage,
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedMessageIds.isEmpty
                  ? null
                  : _confirmDeleteSelectedGroupMessages,
            ),
          ]
              : [
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
                final items =
                <PopupMenuEntry<_GroupMenuAction>>[];

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
                        Icon(Icons.logout,
                            size: 20,
                            color: Colors.red.shade600),
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
                    final rawMessages =
                    provider.getMessages(widget.chatRoomId);

                    if (rawMessages.isEmpty) {
                      return const Center(child: Text("No messages yet"));
                    }

                    final messages = rawMessages
                        .map((m) => MessageModel.fromMap(m))
                        .toList()
                      ..sort((a, b) =>
                          a.createdAt.compareTo(b.createdAt)); // chronological

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

                    final groups = MessageGrouping.build(messages);

                    final messageIndexToGroupIndex =
                    List<int>.filled(messages.length, 0);
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
                      padding:
                      const EdgeInsets.symmetric(vertical: 8),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final groupIndex = groups.length - 1 - index;
                        final group = groups[groupIndex];

                        final firstMsg = group.first;
                        final lastMsg = group.last;

                        final bool isCurrentUser =
                            firstMsg.senderId == _currentUserId;

                        final String senderName =
                        _displayNameForSender(firstMsg.senderId);

                        final Color senderColor = _colorForSender(
                          firstMsg.senderId,
                          colorScheme,
                        );

                        final imageUrls = group.messages
                            .map((m) => m.imageUrl)
                            .whereType<String>()
                            .where((u) => u.trim().isNotEmpty)
                            .toList();

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
                        final bool isLikedByMe = _currentUserId.isNotEmpty &&
                            likedBy.contains(_currentUserId);
                        final int likeCount = likedBy.length;

                        final msgDate = firstMsg.createdAt;
                        DateTime? prevDate;
                        if (groupIndex > 0) {
                          prevDate =
                              groups[groupIndex - 1].first.createdAt;
                        }
                        final showDayDivider =
                            prevDate == null || !isSameDay(msgDate, prevDate);

                        final showUnreadSeparator =
                            unreadCount > 0 &&
                                firstUnreadGroupIndex != null &&
                                groupIndex == firstUnreadGroupIndex;

                        MessageModel? repliedTo;
                        if (lastMsg.replyToMessageId != null &&
                            lastMsg.replyToMessageId!
                                .trim()
                                .isNotEmpty) {
                          try {
                            repliedTo = messages.firstWhere(
                                  (m) => m.id == lastMsg.replyToMessageId,
                            );
                          } catch (_) {
                            repliedTo = null;
                          }
                        }

                        String? replyAuthorName;
                        String? replySnippet;
                        bool replyHasMedia = false;

                        if (repliedTo != null) {
                          replyAuthorName =
                              _displayNameForSender(repliedTo.senderId);

                          if (repliedTo.message.trim().isNotEmpty) {
                            replySnippet = repliedTo.message.trim();
                          } else if ((repliedTo.imageUrl ?? '')
                              .trim()
                              .isNotEmpty) {
                            replySnippet = 'Photo';
                            replyHasMedia = true;
                          } else if ((repliedTo.videoUrl ?? '')
                              .trim()
                              .isNotEmpty) {
                            replySnippet = 'Video';
                            replyHasMedia = true;
                          } else if ((repliedTo.audioUrl ?? '')
                              .trim()
                              .isNotEmpty ||
                              repliedTo.isAudio) {
                            replySnippet = 'Voice message';
                            replyHasMedia = true;
                          } else {
                            replySnippet = 'Message';
                          }
                        }

                        // Inner bubble
                        Widget innerBubble;
                        if (lastMsg.isAudio &&
                            (lastMsg.audioUrl ?? '')
                                .trim()
                                .isNotEmpty) {
                          innerBubble = MyVoiceMessageBubble(
                            key: ValueKey(lastMsg.id),
                            audioUrl: lastMsg.audioUrl!,
                            isCurrentUser: isCurrentUser,
                            durationSeconds: lastMsg.audioDurationSeconds,
                          );
                        } else {
                          innerBubble = MyChatBubble(
                            key: ValueKey(lastMsg.id),
                            message: lastMsg.message,
                            imageUrls: imageUrls,
                            imageUrl:
                            imageUrls.isNotEmpty ? imageUrls.first : null,
                            videoUrl: effectiveVideoUrl,
                            isCurrentUser: isCurrentUser,
                            createdAt: lastMsg.createdAt,
                            isRead: lastMsg.isRead,
                            isDelivered: lastMsg.isDelivered,
                            isLikedByMe: isLikedByMe,
                            likeCount: likeCount,
                            isUploading: lastMsg.isUploading,
                            isDeleted: lastMsg.isDeleted,
                            onDoubleTap: () async {
                              if (_isSelectionMode) return;
                              if (_currentUserId.isEmpty) return;

                              await _chatService.toggleLikeMessage(
                                messageId: lastMsg.id,
                                userId: _currentUserId,
                              );
                            },
                            onLongPress: !_isSelectionMode &&
                                !lastMsg.isDeleted
                                ? () => _handleGroupBubbleLongPress(
                              lastMsg,
                              isCurrentUser,
                            )
                                : null,
                            onLikeTap: likedBy.isEmpty
                                ? null
                                : () {
                              if (_isSelectionMode) return;
                              _openLikesBottomSheet(likedBy);
                            },
                            senderName: isCurrentUser ? null : senderName,
                            senderColor:
                            isCurrentUser ? null : senderColor,
                            replyAuthorName: replyAuthorName,
                            replySnippet: replySnippet,
                            replyHasMedia: replyHasMedia,
                          );
                        }

                        final bool isSelected =
                        _selectedMessageIds.contains(lastMsg.id);

                        final selectableBubble = MySelectableBubble(
                          isSelected: isSelected,
                          onLongPress: () =>
                              _handleGroupBubbleLongPress(
                                lastMsg,
                                isCurrentUser,
                              ),
                          onTap: () {
                            if (_isSelectionMode &&
                                lastMsg.senderId == _currentUserId) {
                              _toggleSelection(lastMsg);
                            }
                          },
                          child: innerBubble,
                        );

                        return Column(
                          children: [
                            if (showDayDivider)
                              buildDayBubble(
                                  context: context, date: msgDate),
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
                                child: selectableBubble,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTo != null) _buildReplyPreviewBar(_replyTo!),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: MyChatTextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        onSendPressed: _sendMessage,
                        onEmojiPressed: () =>
                            debugPrint("Emoji pressed"),
                        onAttachmentPressed: () async {
                          if (_currentUserId.isEmpty) return;

                          await ChatMediaHelper
                              .openAttachmentSheetForGroup(
                            context: context,
                            chatRoomId: widget.chatRoomId,
                            currentUserId: _currentUserId,
                          );
                        },
                        hasPendingAttachment: false,
                        isRecording: _voiceRecorder.isRecording,
                        recordingLabel: _voiceRecorder.isRecording
                            ? 'Recording… ${_voiceRecorder.formattedDuration}'
                            : null,
                        onMicLongPressStart: _handleMicLongPressStart,
                        onMicLongPressEnd: _handleMicLongPressEnd,
                        onMicCancel: _handleMicCancel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
