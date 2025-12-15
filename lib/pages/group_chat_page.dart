import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';
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
import '../services/notifications/notification_service.dart';

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
  final DatabaseService _dbService = DatabaseService();
  late final ChatProvider _chatProvider;
  final NotificationService _notifService = NotificationService();

  late final String _currentUserId;

  bool _isLoadingMembers = true;
  List<UserProfile> _members = [];
  final Map<String, UserProfile> _userCache = {};

  final Map<String, Color> _senderColorCache = {};

  int _lastMessageCount = 0;

  // 🆕 Unread separator behavior for groups
  int? _initialUnreadGroupIndex;
  int? _initialUnreadCount;
  bool _hasCapturedInitialUnreadIndex = false;
  bool _hideUnreadSeparatorForNewMessages = false;

  Timer? _presenceTimer;

  bool _isCurrentUserAdmin = false;

  // current reply target
  MessageModel? _replyTo;

  // 🎙 Voice recorder controller
  late final VoiceRecorderController _voiceRecorder;

  // 🧹 Multi-select delete
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // 🟢 NEW: Typing indicator state for group
  List<String> _typingUserIds = [];
  StreamSubscription<List<String>>? _groupTypingSub;
  Timer? _typingDebounce;
  bool _sentTypingTrue = false;

  @override
  void initState() {
    super.initState();

    _currentUserId = _authService.getCurrentUserId() ?? '';
    debugPrint(
      '🟢 GroupChatPage opened for room=${widget.chatRoomId}, user=$_currentUserId',
    );
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);

    _voiceRecorder = VoiceRecorderController(
      debugTag: 'Group',
      onTick: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    _loadMembers();

    final provider = _chatProvider;
    provider.listenToRoom(widget.chatRoomId);

    if (_currentUserId.isNotEmpty) {
      provider.markGroupMessagesAsRead(widget.chatRoomId, _currentUserId);

      // Mark that this user is currently viewing this group chat
      provider.setActiveChatRoom(
        userId: _currentUserId,
        chatRoomId: widget.chatRoomId,
      );
      // Also mark chat notifications for this group room as read
      _notifService.markChatNotificationsAsRead(
        chatRoomId: widget.chatRoomId,
        userId: _currentUserId,
      );
    }

    // Tell NotificationService that this chat is active
    _notifService.setActiveChatRoomId(widget.chatRoomId);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollDown);
      }
    });

    // 🟢 NEW: Watch the textfield to update typing status (like DM)
    _messageController.addListener(_handleTypingChange);

    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_currentUserId.isNotEmpty) {
        await provider.updateLastSeen(_currentUserId);
      }
    });

    // 🟢 NEW: Subscribe to group typing users
    _subscribeToGroupTyping(widget.chatRoomId);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _voiceRecorder.dispose();

    // 🟢 NEW: typing subscriptions + debounce
    _groupTypingSub?.cancel();
    _typingDebounce?.cancel();

    // Clear active chat presence for group
    if (_currentUserId.isNotEmpty) {
      _chatProvider.setActiveChatRoom(
        userId: _currentUserId,
        chatRoomId: null,
      );

      // 🟢 NEW: ensure our typing flag is cleared for this room
      _chatProvider.setTypingStatus(
        chatRoomId: widget.chatRoomId,
        userId: _currentUserId,
        isTyping: false,
      );
    }

    // Clear active chat id for notification UI
    _notifService.setActiveChatRoomId(null);

    _focusNode.dispose();
    _messageController.removeListener(_handleTypingChange); // 🟢 NEW
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 🟢 NEW: Typing handling (group)
  // ---------------------------------------------------------------------------

  void _subscribeToGroupTyping(String chatRoomId) {
    _groupTypingSub?.cancel();

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // 👉 This expects a method like:
    // Stream<List<String>> groupTypingStream({
    //   required String chatRoomId,
    //   required String currentUserId,
    // })
    _groupTypingSub = chatProvider
        .groupTypingStream(
      chatRoomId: chatRoomId,
      currentUserId: _currentUserId,
    )
        .listen((userIds) {
      if (!mounted) return;
      setState(() {
        _typingUserIds = userIds;
      });
    });
  }

  void _handleTypingChange() async {
    if (_currentUserId.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final hasText = _messageController.text.trim().isNotEmpty;

    if (hasText && !_sentTypingTrue) {
      _sentTypingTrue = true;
      await chatProvider.setTypingStatus(
        chatRoomId: widget.chatRoomId,
        userId: _currentUserId,
        isTyping: true,
      );
    }

    if (!hasText && _sentTypingTrue) {
      _sentTypingTrue = false;
      await chatProvider.setTypingStatus(
        chatRoomId: widget.chatRoomId,
        userId: _currentUserId,
        isTyping: false,
      );
    }

    _typingDebounce?.cancel();
    if (hasText) {
      _typingDebounce = Timer(const Duration(seconds: 4), () async {
        if (!mounted) return;
        if (_currentUserId.isEmpty) return;

        _sentTypingTrue = false;
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.setTypingStatus(
          chatRoomId: widget.chatRoomId,
          userId: _currentUserId,
          isTyping: false,
        );
      });
    }
  }

  String? _buildTypingLabel() {
    // Exclude ourselves from the label if backend still includes us
    final others = _typingUserIds.where((id) => id != _currentUserId).toList();
    if (others.isEmpty) return null;

    final names = others.map(_displayNameForSender).toList();

    if (names.length == 1) {
      // Reuse your existing "typing_indicator" key: "{{name}} is aan het typen…"
      return 'typing_indicator'.tr(
        namedArgs: {'name': names.first},
      );
    }

    if (names.length == 2) {
      // New key: group_typing_two
      return 'group_typing_two'.tr(
        namedArgs: {'name1': names[0], 'name2': names[1]},
      );
    }

    // 3+ users
    // New key: group_typing_many
    return 'group_typing_many'.tr(
      namedArgs: {'name1': names[0], 'name2': names[1]},
    );
  }


  // ---------------------------------------------------------------------------
  // Members & admin
  // ---------------------------------------------------------------------------

  Future<void> _loadMembers() async {
    setState(() {
      _isLoadingMembers = true;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final links = await chatProvider.fetchGroupMemberLinks(widget.chatRoomId);

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
          return SizedBox(
            height: 200,
            child: Center(child: Text('No members found'.tr())),
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
                  backgroundColor:
                  colorScheme.primary.withValues(alpha: 0.12),
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
          title: Text('Leave group?'.tr()),
        content: Text(
        'leave_group_warning'.tr(
        namedArgs: {'name': widget.groupName},
        ),
        ),
          actions: [
            TextButton(
              child: Text(
                'Cancel'.tr(),
                style: TextStyle(color: colorScheme.primary),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Leave'.tr(), style: TextStyle(color: Colors.red[600])),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.leaveGroup(
        chatRoomId: widget.chatRoomId,
        userId: _currentUserId,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error leaving group: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave group. Please try again.'.tr()),
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
          title: Text('Delete group?'.tr()),
          content: Text(
            'delete_group_warning'.tr(
              namedArgs: {'name': widget.groupName},
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel'.tr(),
                style: TextStyle(color: colorScheme.primary),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete'.tr(), style: TextStyle(color: Colors.red[600])),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.deleteGroupAsAdmin(chatRoomId: widget.chatRoomId);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error deleting group: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete group. Please try again.'.tr()),
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
  // Voice recording (group)
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
      return;
    }

    if (_currentUserId.isEmpty) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final messageId = const Uuid().v4();

      final audioUrl = await chatProvider.uploadVoiceFile(
        chatRoomId: widget.chatRoomId,
        messageId: messageId,
        filePath: recorded.filePath,
      );

      await chatProvider.sendVoiceMessageGroup(
        chatRoomId: widget.chatRoomId,
        senderId: _currentUserId,
        audioUrl: audioUrl,
        durationSeconds: recorded.durationSeconds,
        replyToMessageId: _replyTo?.id,
      );

      setState(() {
        _replyTo = null;
      });

      await chatProvider.updateLastSeen(_currentUserId);

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

    await provider.updateLastSeen(_currentUserId);

    // 🟢 NEW: clear our typing flag after sending
    await provider.setTypingStatus(
      chatRoomId: widget.chatRoomId,
      userId: _currentUserId,
      isTyping: false,
    );
    _sentTypingTrue = false;
  }

  // ---------------------------------------------------------------------------
  // Helpers
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
    return 'User'.tr();
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
          title: Text('Delete message?'.tr()),
          content: Text(
            'This message will be deleted for everyone in the group.'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel'.tr(),
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'.tr(), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    await chatProvider.deleteMessageForEveryone(
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
          title: Text(
            'Delete messages'.plural(
              count,
              namedArgs: {'count': count.toString()},
            ),
          ),
          content: Text(
            'Selected messages will be deleted for everyone in the group.'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel'.tr(),
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'.tr(), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final ids = List<String>.from(_selectedMessageIds);
    for (final id in ids) {
      await chatProvider.deleteMessageForEveryone(
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
                leading: Icon(Icons.reply, color: colorScheme.primary),
                title: Text('Reply'.tr()),
                onTap: () {
                  Navigator.of(context).pop();
                  _startReplyToGroupMessage(msg);
                },
              ),
              if (isCurrentUser) ...[
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'.tr()),
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

  // Unified handler
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
      label = 'Photo'.tr();
    } else if ((msg.videoUrl ?? '').trim().isNotEmpty) {
      label = 'Video'.tr();
    } else if ((msg.audioUrl ?? '').trim().isNotEmpty || msg.isAudio) {
      label = 'Voice message'.tr();
    } else {
      label = 'Message'.tr();
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
        ? 'Loading members…'.tr()
        : memberCount == 0
        ? 'No members'.tr()
        : 'member_count'.plural(
      memberCount,
      namedArgs: {
        'count': memberCount.toString(),
      },
    );


    final typingLabel = _buildTypingLabel();

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
            '${_selectedMessageIds.length} ${"selected".tr()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.groupName,
                style: TextStyle(fontWeight: FontWeight.w600),
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
                        Text('View members'.tr()),
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
                          Text('Add members'.tr()),
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
                          Text('Delete group'.tr()),
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
                        Icon(
                          Icons.logout,
                          size: 20,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 12),
                        Text('Leave group'.tr()),
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
                      return Center(child: Text("No messages yet".tr()));
                    }

                    final messages = rawMessages
                        .map((m) => MessageModel.fromMap(m))
                        .toList()
                      ..sort(
                            (a, b) => a.createdAt.compareTo(b.createdAt),
                      );

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

                    // Capture initial unread index + count once
                    if (!_hasCapturedInitialUnreadIndex) {
                      _initialUnreadGroupIndex = firstUnreadGroupIndex;
                      _initialUnreadCount = unreadCount;
                      _hasCapturedInitialUnreadIndex = true;
                    }

                    // Detect new messages while open
                    if (_currentUserId.isNotEmpty &&
                        messages.length != _lastMessageCount) {
                      if (_lastMessageCount > 0 &&
                          messages.length > _lastMessageCount) {
                        _hideUnreadSeparatorForNewMessages = true;
                      }

                      if (_isNearBottom()) {
                        _scrollDown();
                      }

                      _lastMessageCount = messages.length;

                      provider.markGroupMessagesAsRead(
                        widget.chatRoomId,
                        _currentUserId,
                      );
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
                          prevDate =
                              groups[groupIndex - 1].first.createdAt;
                        }
                        final showDayDivider =
                            prevDate == null || !isSameDay(msgDate, prevDate);

                        final showUnreadSeparator =
                            _initialUnreadGroupIndex != null &&
                                groupIndex == _initialUnreadGroupIndex &&
                                !_hideUnreadSeparatorForNewMessages;

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
                          replyAuthorName = _displayNameForSender(
                            repliedTo.senderId,
                          );

                          if (repliedTo.message.trim().isNotEmpty) {
                            replySnippet = repliedTo.message.trim();
                          } else if ((repliedTo.imageUrl ?? '')
                              .trim()
                              .isNotEmpty) {
                            replySnippet = 'Photo'.tr();
                            replyHasMedia = true;
                          } else if ((repliedTo.videoUrl ?? '')
                              .trim()
                              .isNotEmpty) {
                            replySnippet = 'Video'.tr();
                            replyHasMedia = true;
                          } else if ((repliedTo.audioUrl ?? '')
                              .trim()
                              .isNotEmpty ||
                              repliedTo.isAudio) {
                            replySnippet = 'Voice message'.tr();
                            replyHasMedia = true;
                          } else {
                            replySnippet = 'Message'.tr();
                          }
                        }

                        // Inner bubble
                        Widget innerBubble;
                        if (lastMsg.isAudio &&
                            (lastMsg.audioUrl ?? '').trim().isNotEmpty) {
                          innerBubble = MyVoiceMessageBubble(
                            key: ValueKey(lastMsg.id),
                            audioUrl: lastMsg.audioUrl!,
                            isCurrentUser: isCurrentUser,
                            durationSeconds:
                            lastMsg.audioDurationSeconds,
                          );
                        } else {
                          innerBubble = MyChatBubble(
                            key: ValueKey(lastMsg.id),
                            message: lastMsg.message,
                            imageUrls: imageUrls,
                            imageUrl: imageUrls.isNotEmpty
                                ? imageUrls.first
                                : null,
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

                              await provider.toggleLikeMessage(
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
                                context: context,
                                date: msgDate,
                              ),
                            if (showUnreadSeparator)
                              buildUnreadBubble(
                                context: context,
                                unreadCount:
                                _initialUnreadCount ?? unreadCount,
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
                    // 🟢 NEW: bottom typing indicator (same style as DM)
                    if (typingLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            typingLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
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

                          await ChatMediaHelper.openAttachmentSheetForGroup(
                            context: context,
                            chatRoomId: widget.chatRoomId,
                            currentUserId: _currentUserId,
                          );
                        },
                        hasPendingAttachment: false,
                        isRecording: _voiceRecorder.isRecording,
                        recordingLabel: _voiceRecorder.isRecording
                            ? 'recording_label'.tr(
                          namedArgs: {'time': _voiceRecorder.formattedDuration},
                        )
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
