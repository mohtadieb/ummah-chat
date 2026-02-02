// lib/pages/chat_page.dart
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/pages/post_page.dart';
import 'package:ummah_chat/pages/profile_page.dart';
import 'package:uuid/uuid.dart';

import 'package:ummah_chat/services/auth/auth_service.dart';

import '../components/my_chat_bubble.dart';
import '../components/my_chat_text_field.dart';
import '../components/my_voice_message_bubble.dart';
import '../components/my_selectable_bubble.dart';
import '../components/my_reply_preview_bar.dart';
import '../helper/post_share.dart';
import '../helper/time_ago_text.dart';
import '../helper/chat_separators.dart';
import '../helper/chat_media_helper.dart';
import '../helper/message_grouping.dart';
import '../helper/voice_recorder_helper.dart';
import '../helper/likes_bottom_sheet_helper.dart';
import '../models/message.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../models/user_profile.dart';
import '../services/chat/chat_provider.dart';
import '../services/database/database_provider.dart';
import '../services/database/database_service.dart';
import '../services/notifications/notification_service.dart';

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? initialDraftMessage;
  final bool sendDraftOnOpen;

  const ChatPage({
    super.key,
    required this.friendId,
    required this.friendName,
    this.initialDraftMessage,
    this.sendDraftOnOpen = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notifService = NotificationService();

  late final ChatProvider _chatProvider;
  late final String _currentUserId;

  String? _chatRoomId;

  // 👤 Friend profile (for Online / Last seen)
  UserProfile? _friendProfile;

  // 🔁 Periodic refresh for friend status
  Timer? _statusTimer;

  // 🔁 Periodic refresh for *our* last_seen_at while chat is open
  Timer? _presenceTimer;

  // 🟢 Typing indicator
  bool _isFriendTyping = false;
  StreamSubscription<bool>? _friendTypingSub;

  // Detect our own typing with a debounce
  Timer? _typingDebounce;
  bool _sentTypingTrue = false;

  // Track last message count (for auto-scroll & unread separator behavior)
  int _lastMessageCount = 0;

  // Reply target
  MessageModel? _replyTo;

  // 🆕 Unread separator behavior
  int? _initialUnreadGroupIndex;
  int? _initialUnreadCount; // store count at first open
  bool _hasCapturedInitialUnreadIndex = false;
  bool _hideUnreadSeparatorForNewMessages = false;

  // 🎙 Voice recorder controller (extracted)
  late final VoiceRecorderController _voiceRecorder;

  // 🧹 Multi-select delete state
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  @override
  void initState() {
    super.initState();

    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _currentUserId = _authService.getCurrentUserId() ?? '';

    _voiceRecorder = VoiceRecorderController(
      debugTag: 'DM',
      onTick: () {
        if (mounted) setState(() {});
      },
    );

    // Auto-scroll when keyboard opens
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollDown);
      }
    });

    // Watch the textfield to update typing status
    _messageController.addListener(_handleTypingChange);

    _initChatRoom();
    _loadFriendProfile();

    // Periodically refresh friend's status while chat is open
    _statusTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _loadFriendProfile(),
    );

    // Periodically refresh *our* last_seen_at while chat is open
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      if (_currentUserId.isEmpty) return;
      await _chatProvider.updateLastSeen(_currentUserId);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _presenceTimer?.cancel();
    _friendTypingSub?.cancel();
    _typingDebounce?.cancel();

    _voiceRecorder.dispose();

    // Clear active chat presence (no Provider.of in dispose)
    if (_currentUserId.isNotEmpty) {
      _chatProvider.setActiveChatRoom(userId: _currentUserId, chatRoomId: null);

      // ✅ Ensure typing status is cleared when leaving the chat
      if (_chatRoomId != null) {
        _chatProvider.setTypingStatus(
          chatRoomId: _chatRoomId!,
          userId: _currentUserId,
          isTyping: false,
        );
      }
    }

    // ✅ UI-only suppression: clear when leaving DM
    _notifService.setActiveChatRoomId(null);
    _notifService.setActiveDmFriendId(null);

    _focusNode.dispose();
    _messageController.removeListener(_handleTypingChange);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Chat room init + typing
  // ---------------------------------------------------------------------------

  Future<void> _initChatRoom() async {
    if (_currentUserId.isEmpty) return;

    final chatRoomId = await _chatProvider.getOrCreateChatRoomId(
      _currentUserId,
      widget.friendId,
    );

    if (!mounted) return;

    setState(() {
      _chatRoomId = chatRoomId;
    });

    // ✅ UI-only suppression: hide notif while this DM is open
    _notifService.setActiveChatRoomId(chatRoomId);
    _notifService.setActiveDmFriendId(widget.friendId);

    // Presence: mark this room active
    await _chatProvider.setActiveChatRoom(
      userId: _currentUserId,
      chatRoomId: chatRoomId,
    );

    await _chatProvider.listenToRoom(chatRoomId);

    // ============================================================
    // ✅ PHASE 1 (Step 3): auto-send draft marker AFTER room is ready
    // ============================================================
    if (widget.sendDraftOnOpen == true &&
        widget.initialDraftMessage != null &&
        widget.initialDraftMessage!.trim().isNotEmpty) {
      final marker = widget.initialDraftMessage!.trim();

      // Optional: show it in the input briefly (nice UX)
      _messageController.text = marker;

      // Send next frame so UI is mounted and room stream is active
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sendMessage(textOverride: marker);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());

    await _chatProvider.markRoomMessagesAsRead(chatRoomId, _currentUserId);

    await _chatProvider.updateLastSeen(_currentUserId);

    _subscribeToFriendTyping(chatRoomId);
  }

  void _subscribeToFriendTyping(String chatRoomId) {
    _friendTypingSub?.cancel();

    _friendTypingSub = _chatProvider
        .friendTypingStream(chatRoomId: chatRoomId, friendId: widget.friendId)
        .listen((isTyping) {
          if (!mounted) return;
          setState(() {
            _isFriendTyping = isTyping;
          });
        });
  }

  Future<void> _loadFriendProfile() async {
    final profile = await _dbService.getUserFromDatabase(widget.friendId);
    if (!mounted) return;

    setState(() {
      _friendProfile = profile;
    });
  }

  void _handleTypingChange() async {
    if (_chatRoomId == null) return;
    if (_currentUserId.isEmpty) return;

    final hasText = _messageController.text.trim().isNotEmpty;

    if (hasText && !_sentTypingTrue) {
      _sentTypingTrue = true;
      await _chatProvider.setTypingStatus(
        chatRoomId: _chatRoomId!,
        userId: _currentUserId,
        isTyping: true,
      );
    }

    if (!hasText && _sentTypingTrue) {
      _sentTypingTrue = false;
      await _chatProvider.setTypingStatus(
        chatRoomId: _chatRoomId!,
        userId: _currentUserId,
        isTyping: false,
      );
    }

    _typingDebounce?.cancel();
    if (hasText) {
      _typingDebounce = Timer(const Duration(seconds: 4), () async {
        if (!mounted) return;
        if (_chatRoomId == null) return;
        if (_currentUserId.isEmpty) return;

        _sentTypingTrue = false;
        await _chatProvider.setTypingStatus(
          chatRoomId: _chatRoomId!,
          userId: _currentUserId,
          isTyping: false,
        );
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll helpers
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
  // Reply helpers
  // ---------------------------------------------------------------------------

  void _startReplyTo(MessageModel msg) {
    setState(() {
      _replyTo = msg;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    if (_replyTo == null) return;
    setState(() {
      _replyTo = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Voice recording (using VoiceRecorderController)
  // ---------------------------------------------------------------------------

  void _handleMicLongPressStart() {
    if (_voiceRecorder.isRecording) return;

    _voiceRecorder.start().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleMicLongPressEnd() {
    _stopRecordingAndSend();
  }

  Future<void> _handleMicCancel() async {
    if (!_voiceRecorder.isRecording) return;

    try {
      await _voiceRecorder.stop();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error cancelling voice recording: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final recorded = await _voiceRecorder.stop();
    if (recorded == null) return;

    if (_currentUserId.isEmpty || _chatRoomId == null) return;

    try {
      final messageId = const Uuid().v4();

      final audioUrl = await _chatProvider.uploadVoiceFile(
        chatRoomId: _chatRoomId!,
        messageId: messageId,
        filePath: recorded.filePath,
      );

      await _chatProvider.sendVoiceMessageDM(
        chatRoomId: _chatRoomId!,
        senderId: _currentUserId,
        receiverId: widget.friendId,
        audioUrl: audioUrl,
        durationSeconds: recorded.durationSeconds,
        replyToMessageId: _replyTo?.id,
      );

      setState(() {
        _replyTo = null;
      });

      await _chatProvider.updateLastSeen(_currentUserId);
    } catch (e) {
      debugPrint('Error sending voice message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Send text
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage({String? textOverride}) async {
    final text = (textOverride ?? _messageController.text).trim();
    if (text.isEmpty) return;
    if (text.isEmpty || _chatRoomId == null) return;
    if (_currentUserId.isEmpty) return;

    final replyId = _replyTo?.id;

    _messageController.clear();
    _scrollDown();

    await _chatProvider.sendMessage(
      _chatRoomId!,
      _currentUserId,
      widget.friendId,
      text,
      replyToMessageId: replyId,
    );

    setState(() {
      _replyTo = null;
    });

    await _chatProvider.updateLastSeen(_currentUserId);

    await _chatProvider.setTypingStatus(
      chatRoomId: _chatRoomId!,
      userId: _currentUserId,
      isTyping: false,
    );
    _sentTypingTrue = false;
  }

  // ---------------------------------------------------------------------------
  // Multi-select helpers
  // ---------------------------------------------------------------------------

  void _startSelection(MessageModel msg) {
    if (msg.senderId != _currentUserId) {
      _onBubbleLongPress(msg, false);
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
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMessageIds.add(msg.id);
      }
    });
  }

  Future<void> _confirmDeleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    if (_currentUserId.isEmpty) return;

    final colorScheme = Theme.of(context).colorScheme;
    final count = _selectedMessageIds.length;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        final deleteLabel = "Delete messages".plural(
          count,
          namedArgs: {"count": count.toString()},
        );

        return AlertDialog(
          title: Text(deleteLabel),
          content: Text(
            'Selected messages will be deleted for everyone in this chat.'.tr(),
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
              child: Text(
                'Delete'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final ids = List<String>.from(_selectedMessageIds);
    for (final id in ids) {
      await _chatProvider.deleteMessageForEveryone(
        messageId: id,
        userId: _currentUserId,
      );
    }

    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _replyToSelectedMessage() async {
    if (!_isSelectionMode || _selectedMessageIds.length != 1) return;
    if (_chatRoomId == null) return;

    final selectedId = _selectedMessageIds.first;

    final rawMessages = _chatProvider.getMessages(_chatRoomId!);
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

  // ---------------------------------------------------------------------------
  // Likes bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _openLikesBottomSheet(List<String> userIds) async {
    final uniqueIds = userIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) return;

    await LikesBottomSheetHelper.show(
      context: context,
      currentUserId: _currentUserId.isEmpty ? null : _currentUserId,
      loadProfiles: () async {
        final List<UserProfile> profiles = [];
        for (final id in uniqueIds) {
          final profile = await _dbService.getUserFromDatabase(id);
          if (profile != null) profiles.add(profile);
        }
        return profiles;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget? _buildSubtitle(ColorScheme colorScheme) {
    final profile = _friendProfile;
    if (profile == null) return null;

    final baseStyle = TextStyle(
      fontSize: 12,
      color: colorScheme.onSurface.withOpacity(0.7),
    );

    if (profile.isOnline) {
      return Text(
        'Online'.tr(),
        style: baseStyle.copyWith(
          color: const Color(0xFF12B981),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (profile.lastSeenAt == null) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${"Last seen".tr()} ', style: baseStyle),
        TimeAgoText(createdAt: profile.lastSeenAt!, style: baseStyle),
      ],
    );
  }

  Widget _buildFriendAvatar({double size = 34}) {
    final url = (_friendProfile?.profilePhotoUrl ?? '').trim();

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Icon(
              Icons.person,
              size: size * 0.55,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            )
          : null,
    );
  }

  Widget _buildReplyPreviewBar(MessageModel msg) {
    final isMine = msg.senderId == _currentUserId;
    final author = isMine ? 'You'.tr() : widget.friendName;

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
      onCancel: _cancelReply,
    );
  }

  Future<void> _confirmDeleteMessage(String messageId) async {
    final colorScheme = Theme.of(context).colorScheme;
    if (_currentUserId.isEmpty) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Delete message?'.tr()),
          content: Text(
            'This message will be deleted for everyone in this chat.'.tr(),
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

    await _chatProvider.deleteMessageForEveryone(
      messageId: messageId,
      userId: _currentUserId,
    );
  }

  Future<void> _onBubbleLongPress(MessageModel msg, bool isCurrentUser) async {
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
                  _startReplyTo(msg);
                },
              ),
              if (isCurrentUser) ...[
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'.tr()),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDeleteMessage(msg.id);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _handleBubbleLongPress(MessageModel msg, bool isCurrentUser) {
    if (msg.isDeleted) return;

    if (_isSelectionMode && msg.senderId == _currentUserId) {
      _toggleSelection(msg);
      return;
    }

    if (msg.senderId == _currentUserId) {
      _startSelection(msg);
      return;
    }

    _onBubbleLongPress(msg, isCurrentUser);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleWidget = _buildSubtitle(colorScheme);

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
                  "selected_messages".plural(
                    _selectedMessageIds.length,
                    namedArgs: {"count": _selectedMessageIds.length.toString()},
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: widget.friendId),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      _buildFriendAvatar(size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.friendName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                height: 1.1
                              ),
                            ),
                            if (subtitleWidget != null) subtitleWidget,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

          actions: _isSelectionMode
              ? [
                  if (_selectedMessageIds.length == 1)
                    IconButton(
                      icon: const Icon(Icons.reply),
                      onPressed: _replyToSelectedMessage,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _selectedMessageIds.isEmpty
                        ? null
                        : _confirmDeleteSelectedMessages,
                  ),
                ]
              : null,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: _chatRoomId == null
                    ? const Center(child: CircularProgressIndicator())
                    : Consumer<ChatProvider>(
                        builder: (context, provider, _) {
                          final rawMessages = provider.getMessages(
                            _chatRoomId!,
                          );

                          if (rawMessages.isEmpty) {
                            return Center(child: Text("No messages yet".tr()));
                          }

                          final messages =
                              rawMessages
                                  .map((m) => MessageModel.fromMap(m))
                                  .toList()
                                ..sort(
                                  (a, b) => a.createdAt.compareTo(b.createdAt),
                                );

                          int unreadCount = 0;
                          int? firstUnreadIndexFromStart;

                          for (int i = 0; i < messages.length; i++) {
                            final m = messages[i];
                            final isMine = m.senderId == _currentUserId;
                            if (!m.isRead && !isMine) {
                              unreadCount++;
                              firstUnreadIndexFromStart ??= i;
                            }
                          }

                          final groups = MessageGrouping.build(messages);

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

                          if (!_hasCapturedInitialUnreadIndex) {
                            _initialUnreadGroupIndex = firstUnreadGroupIndex;
                            _initialUnreadCount = unreadCount;
                            _hasCapturedInitialUnreadIndex = true;
                          }

                          if (_currentUserId.isNotEmpty &&
                              messages.length != _lastMessageCount) {
                            if (_lastMessageCount > 0 &&
                                messages.length > _lastMessageCount) {
                              _hideUnreadSeparatorForNewMessages = true;
                            }

                            if (_isNearBottom()) _scrollDown();

                            _lastMessageCount = messages.length;

                            provider.markRoomMessagesAsRead(
                              _chatRoomId!,
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

                              final isCurrentUser =
                                  firstMsg.senderId == _currentUserId;

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

                              final likedBy = lastMsg.likedBy;
                              final isLikedByMe = likedBy.contains(
                                _currentUserId,
                              );
                              final likeCount = likedBy.length;

                              final msgDate = firstMsg.createdAt;
                              DateTime? prevDate;
                              if (groupIndex > 0) {
                                prevDate =
                                    groups[groupIndex - 1].first.createdAt;
                              }
                              final showDayDivider =
                                  prevDate == null ||
                                  !isSameDay(msgDate, prevDate);

                              final showUnreadSeparator =
                                  _initialUnreadGroupIndex != null &&
                                  groupIndex == _initialUnreadGroupIndex &&
                                  !_hideUnreadSeparatorForNewMessages;

                              MessageModel? repliedTo;
                              if (lastMsg.replyToMessageId != null &&
                                  lastMsg.replyToMessageId!.trim().isNotEmpty) {
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
                                final isMineReply =
                                    repliedTo.senderId == _currentUserId;
                                replyAuthorName = isMineReply
                                    ? 'You'.tr()
                                    : widget.friendName;

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

                              Widget innerBubble;

                              if (lastMsg.isAudio &&
                                  (lastMsg.audioUrl ?? '').trim().isNotEmpty) {
                                innerBubble = MyVoiceMessageBubble(
                                  key: ValueKey(lastMsg.id),
                                  audioUrl: lastMsg.audioUrl!,
                                  isCurrentUser: isCurrentUser,
                                  durationSeconds: lastMsg.audioDurationSeconds,
                                );
                              } else if (PostShare.isPostShareMessage(
                                lastMsg.message,
                              )) {
                                final sharedPostId = PostShare.extractPostId(
                                  lastMsg.message,
                                );

                                innerBubble = _SharedPostBubble(
                                  postId: sharedPostId ?? '',
                                  isCurrentUser: isCurrentUser,
                                  createdAt: lastMsg.createdAt,
                                  onTap: () {
                                    if (sharedPostId == null ||
                                        sharedPostId.trim().isEmpty)
                                      return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostPage(
                                          post: null,
                                          postId: sharedPostId.trim(),
                                          highlightPost: true,
                                        ),
                                      ),
                                    );
                                  },
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
                                  senderName: isCurrentUser
                                      ? 'You'.tr()
                                      : widget.friendName,
                                  onDoubleTap: () async {
                                    if (_isSelectionMode) return;
                                    if (_currentUserId.isEmpty) return;

                                    await _chatProvider.toggleLikeMessage(
                                      messageId: lastMsg.id,
                                      userId: _currentUserId,
                                    );
                                  },
                                  onLongPress:
                                      !_isSelectionMode && !lastMsg.isDeleted
                                      ? () => _handleBubbleLongPress(
                                          lastMsg,
                                          isCurrentUser,
                                        )
                                      : null,
                                  onLikeTap: likedBy.isEmpty
                                      ? null
                                      : () {
                                          if (_isSelectionMode) return;
                                          _openLikesBottomSheet(
                                            likedBy
                                                .map((e) => e.toString())
                                                .toList(),
                                          );
                                        },
                                  replyAuthorName: replyAuthorName,
                                  replySnippet: replySnippet,
                                  replyHasMedia: replyHasMedia,
                                );
                              }

                              final bool isSelected = _selectedMessageIds
                                  .contains(lastMsg.id);

                              final selectableBubble = MySelectableBubble(
                                isSelected: isSelected,
                                onLongPress: () => _handleBubbleLongPress(
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
                    if (_replyTo != null && _currentUserId.isNotEmpty)
                      _buildReplyPreviewBar(_replyTo!),

                    if (_isFriendTyping)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'typing_indicator'.tr(
                              namedArgs: {"name": widget.friendName},
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: MyChatTextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        onSendPressed: _sendMessage,
                        onEmojiPressed: () => debugPrint('Emoji pressed'),
                        onAttachmentPressed: () async {
                          if (_chatRoomId == null) return;
                          if (_currentUserId.isEmpty) return;

                          await ChatMediaHelper.openAttachmentSheetForDM(
                            context: context,
                            chatRoomId: _chatRoomId!,
                            currentUserId: _currentUserId,
                            otherUserId: widget.friendId,
                          );
                        },
                        hasPendingAttachment: false,
                        isRecording: _voiceRecorder.isRecording,
                        recordingLabel: _voiceRecorder.isRecording
                            ? 'recording_label'.tr(
                                namedArgs: {
                                  "time": _voiceRecorder.formattedDuration,
                                },
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

class _SharedPostBubble extends StatelessWidget {
  final String postId;
  final bool isCurrentUser;
  final DateTime createdAt; // you already added this
  final VoidCallback onTap;

  const _SharedPostBubble({
    required this.postId,
    required this.isCurrentUser,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final db = context.read<DatabaseProvider>();

    final bg = isCurrentUser ? const Color(0xFF467E55) : cs.tertiary;
    final fg = isCurrentUser ? Colors.white : cs.inversePrimary;

    if (postId.trim().isEmpty) {
      return _buildShell(
        context,
        bg: bg,
        fg: fg,
        title: 'Shared post'.tr(),
        subtitle: 'Post not found'.tr(),
        imageUrls: const [],
        onTap: () {},
      );
    }

    return FutureBuilder<Post?>(
      future: db.getPostById(postId.trim()),
      builder: (context, postSnap) {
        final post = postSnap.data;

        return FutureBuilder<List<PostMedia>>(
          future: db.getPostMediaCached(postId.trim()),
          builder: (context, mediaSnap) {
            final media = mediaSnap.data ?? const <PostMedia>[];

            // Only show images in the preview grid (videos optional later)
            final imageUrls = media
                .where((m) => m.type == 'image')
                .map((m) => m.url.trim())
                .where((u) => u.isNotEmpty)
                .toList(growable: false);

            final caption = (post?.message ?? '').trim();

            final subtitle = caption.isNotEmpty
                ? caption
                : (post == null ? 'Post not found'.tr() : 'Tap to view'.tr());

            return _buildShell(
              context,
              bg: bg,
              fg: fg,
              title: 'Shared post'.tr(),
              subtitle: subtitle,
              imageUrls: imageUrls,
              onTap: post == null ? () {} : onTap,
            );
          },
        );
      },
    );
  }

  Widget _buildShell(
    BuildContext context, {
    required Color bg,
    required Color fg,
    required String title,
    required String subtitle,
    required List<String> imageUrls,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined, color: fg, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new,
                  color: fg.withValues(alpha: 0.9),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ✅ image preview grid (up to 4)
            if (imageUrls.isNotEmpty)
              _SharedPostImageGrid(
                imageUrls: imageUrls.take(4).toList(),
                borderRadius: 12,
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedPostImageGrid extends StatelessWidget {
  final List<String> imageUrls;
  final double borderRadius;

  const _SharedPostImageGrid({required this.imageUrls, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    final count = imageUrls.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 1.25, // nice “preview card” ratio
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count == 1 ? 1 : 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: count,
          itemBuilder: (_, i) {
            return Image.network(
              imageUrls[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            );
          },
        ),
      ),
    );
  }
}
