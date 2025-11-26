import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:ummah_chat/services/auth/auth_service.dart';

import '../components/my_chat_bubble.dart';
import '../components/my_chat_text_field.dart';
import '../components/my_voice_message_bubble.dart';
import '../components/my_selectable_bubble.dart';
import '../components/my_reply_preview_bar.dart';
import '../helper/time_ago_text.dart';
import '../helper/chat_separators.dart';
import '../helper/chat_media_helper.dart';
import '../helper/message_grouping.dart';
import '../helper/voice_recorder_helper.dart';
import '../helper/likes_bottom_sheet_helper.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/chat/chat_provider.dart';
import '../services/chat/chat_service.dart';
import '../services/database/database_service.dart';

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatPage({super.key, required this.friendId, required this.friendName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final DatabaseService _dbService = DatabaseService();

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

  // Track last message count (for auto-scroll)
  int _lastMessageCount = 0;

  // Reply target
  MessageModel? _replyTo;

  // 🎙 Voice recorder controller (extracted)
  late final VoiceRecorderController _voiceRecorder;

  // 🧹 Multi-select delete state
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  @override
  void initState() {
    super.initState();

    _voiceRecorder = VoiceRecorderController(
      debugTag: 'DM',
      onTick: () {
        if (mounted) {
          setState(() {});
        }
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
      final currentUserId = _authService.getCurrentUserId();
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await _chatService.updateLastSeen(currentUserId);
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _presenceTimer?.cancel();
    _friendTypingSub?.cancel();
    _typingDebounce?.cancel();

    _voiceRecorder.dispose();

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
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final chatRoomId = await _chatService.getOrCreateChatRoomId(
      currentUserId,
      widget.friendId,
    );

    if (!mounted) return;

    setState(() {
      _chatRoomId = chatRoomId;
    });

    final provider = Provider.of<ChatProvider>(context, listen: false);
    await provider.listenToRoom(chatRoomId);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());

    await _chatService.markRoomMessagesAsRead(chatRoomId, currentUserId);
    await _chatService.updateLastSeen(currentUserId);

    _subscribeToFriendTyping(chatRoomId);
  }

  void _subscribeToFriendTyping(String chatRoomId) {
    _friendTypingSub?.cancel();
    _friendTypingSub = _chatService
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
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final hasText = _messageController.text.trim().isNotEmpty;

    if (hasText && !_sentTypingTrue) {
      _sentTypingTrue = true;
      await _chatService.setTypingStatus(
        chatRoomId: _chatRoomId!,
        userId: currentUserId,
        isTyping: true,
      );
    }

    if (!hasText && _sentTypingTrue) {
      _sentTypingTrue = false;
      await _chatService.setTypingStatus(
        chatRoomId: _chatRoomId!,
        userId: currentUserId,
        isTyping: false,
      );
    }

    _typingDebounce?.cancel();
    if (hasText) {
      _typingDebounce = Timer(const Duration(seconds: 4), () async {
        if (_chatRoomId == null) return;
        final uid = _authService.getCurrentUserId();
        if (uid == null || uid.isEmpty) return;

        _sentTypingTrue = false;
        await _chatService.setTypingStatus(
          chatRoomId: _chatRoomId!,
          userId: uid,
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

    // Stop recording and discard result
    try {
      await _voiceRecorder.stop();
      if (mounted) {
        setState(() {});
      }
      debugPrint('🎤 Voice recording cancelled by slide');
    } catch (e) {
      debugPrint('Error cancelling voice recording: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final recorded = await _voiceRecorder.stop();
    if (recorded == null) {
      // Either too short or failed
      return;
    }

    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty || _chatRoomId == null) {
      return;
    }

    try {
      final messageId = const Uuid().v4();

      final audioUrl = await _chatService.uploadVoiceFile(
        chatRoomId: _chatRoomId!,
        messageId: messageId,
        filePath: recorded.filePath,
      );

      await _chatService.sendVoiceMessageDM(
        chatRoomId: _chatRoomId!,
        senderId: currentUserId,
        receiverId: widget.friendId,
        audioUrl: audioUrl,
        durationSeconds: recorded.durationSeconds,
        replyToMessageId: _replyTo?.id,
      );

      setState(() {
        _replyTo = null; // clear reply target after sending voice
      });

      await _chatService.updateLastSeen(currentUserId);

      debugPrint('✅ Voice message sent');
    } catch (e) {
      debugPrint('Error sending voice message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Send text
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatRoomId == null) return;

    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);

    final replyId = _replyTo?.id;

    _messageController.clear();
    _scrollDown();

    await provider.sendMessage(
      _chatRoomId!,
      currentUserId,
      widget.friendId,
      text,
      replyToMessageId: replyId,
    );

    setState(() {
      _replyTo = null;
    });

    await _chatService.updateLastSeen(currentUserId);

    if (_chatRoomId != null) {
      await _chatService.setTypingStatus(
        chatRoomId: _chatRoomId!,
        userId: currentUserId,
        isTyping: false,
      );
      _sentTypingTrue = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Multi-select helpers
  // ---------------------------------------------------------------------------

  void _startSelection(MessageModel msg) {
    // Only allow selecting your own messages for deletion
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || msg.senderId != currentUserId) {
      // Fallback: normal long-press behaviour
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
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || msg.senderId != currentUserId) return;

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

  Future<void> _confirmDeleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final count = _selectedMessageIds.length;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Delete $count message${count == 1 ? '' : 's'}?'),
          content: const Text(
            'Selected messages will be deleted for everyone in this chat.',
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
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        userId: currentUserId,
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

    final provider = Provider.of<ChatProvider>(context, listen: false);
    final rawMessages = provider.getMessages(_chatRoomId!);

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
  // Likes bottom sheet (uses LikesBottomSheetHelper)
  // ---------------------------------------------------------------------------

  Future<void> _openLikesBottomSheet(List<String> userIds) async {
    final uniqueIds = userIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) return;

    final currentUserId = _authService.getCurrentUserId();

    await LikesBottomSheetHelper.show(
      context: context,
      currentUserId: currentUserId,
      loadProfiles: () async {
        final List<UserProfile> profiles = [];
        for (final id in uniqueIds) {
          final profile = await _dbService.getUserFromDatabase(id);
          if (profile != null) {
            profiles.add(profile);
          }
        }
        return profiles;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers (subtitle, reply bar, delete)
  // ---------------------------------------------------------------------------

  Widget? _buildSubtitle(ColorScheme colorScheme) {
    if (_isFriendTyping) {
      return Text(
        'Typing...',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.primary.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final profile = _friendProfile;
    if (profile == null) return null;

    final baseStyle = TextStyle(
      fontSize: 12,
      color: colorScheme.primary.withValues(alpha: 0.7),
    );

    if (profile.isOnline) {
      return Text(
        'Online',
        style: baseStyle.copyWith(
          color: const Color(0xFF12B981),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (profile.lastSeenAt == null) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Last seen ', style: baseStyle),
        TimeAgoText(createdAt: profile.lastSeenAt!, style: baseStyle),
      ],
    );
  }

  Widget _buildReplyPreviewBar(
      MessageModel msg,
      String currentUserId,
      ) {
    final isMine = msg.senderId == currentUserId;
    final author = isMine ? 'You' : widget.friendName;

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
      onCancel: _cancelReply,
    );
  }

  Future<void> _confirmDeleteMessage(String messageId) async {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text(
            'This message will be deleted for everyone in this chat.',
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
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await _chatService.deleteMessageForEveryone(
      messageId: messageId,
      userId: currentUserId,
    );
  }

  // Long press handler for NON-selection scenarios (other user's message)
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
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(context).pop();
                  _startReplyTo(msg);
                },
              ),
              if (isCurrentUser) ...[
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete'),
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

  // Unified long-press entry point used by bubbles
  void _handleBubbleLongPress(MessageModel msg, bool isCurrentUser) {
    if (msg.isDeleted) return;

    final currentUserId = _authService.getCurrentUserId();

    if (_isSelectionMode &&
        currentUserId != null &&
        msg.senderId == currentUserId) {
      _toggleSelection(msg);
      return;
    }

    if (currentUserId != null && msg.senderId == currentUserId) {
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
    final currentUserId = _authService.getCurrentUserId();
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
            '${_selectedMessageIds.length} selected',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.friendName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (subtitleWidget != null) subtitleWidget,
            ],
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
              // Messages
              Expanded(
                child: _chatRoomId == null
                    ? const Center(child: CircularProgressIndicator())
                    : Consumer<ChatProvider>(
                  builder: (context, provider, _) {
                    final rawMessages = provider.getMessages(
                      _chatRoomId!,
                    );

                    if (rawMessages.isEmpty) {
                      return const Center(
                          child: Text("No messages yet"));
                    }

                    final messages = rawMessages
                        .map((m) => MessageModel.fromMap(m))
                        .toList()
                      ..sort(
                            (a, b) => a.createdAt.compareTo(b.createdAt),
                      ); // force chronological

                    int unreadCount = 0;
                    int? firstUnreadIndexFromStart;
                    if (currentUserId != null) {
                      for (int i = 0; i < messages.length; i++) {
                        final m = messages[i];
                        final isMine = m.senderId == currentUserId;
                        if (!m.isRead && !isMine) {
                          unreadCount++;
                          firstUnreadIndexFromStart ??= i;
                        }
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
                      messageIndexToGroupIndex[
                      firstUnreadIndexFromStart];
                    }

                    if (messages.length != _lastMessageCount) {
                      if (_isNearBottom()) {
                        _scrollDown();
                      }
                      _lastMessageCount = messages.length;
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

                        final isCurrentUser = currentUserId != null &&
                            firstMsg.senderId == currentUserId;

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
                        final isLikedByMe = currentUserId != null &&
                            likedBy.contains(currentUserId);
                        final likeCount = likedBy.length;

                        final msgDate = firstMsg.createdAt;
                        DateTime? prevDate;
                        if (groupIndex > 0) {
                          prevDate =
                              groups[groupIndex - 1].first.createdAt;
                        }
                        final showDayDivider = prevDate == null ||
                            !isSameDay(msgDate, prevDate);

                        final showUnreadSeparator = unreadCount > 0 &&
                            firstUnreadGroupIndex != null &&
                            groupIndex == firstUnreadGroupIndex;

                        MessageModel? repliedTo;
                        if (lastMsg.replyToMessageId != null &&
                            lastMsg.replyToMessageId!
                                .trim()
                                .isNotEmpty) {
                          try {
                            repliedTo = messages.firstWhere(
                                  (m) =>
                              m.id == lastMsg.replyToMessageId,
                            );
                          } catch (_) {
                            repliedTo = null;
                          }
                        }

                        String? replyAuthorName;
                        String? replySnippet;
                        bool replyHasMedia = false;

                        if (repliedTo != null) {
                          final isMineReply = currentUserId != null &&
                              repliedTo.senderId == currentUserId;
                          replyAuthorName =
                          isMineReply ? 'You' : widget.friendName;

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

                        // 👉 build inner bubble (voice or text/media)
                        Widget innerBubble;
                        if (lastMsg.isAudio &&
                            (lastMsg.audioUrl ?? '')
                                .trim()
                                .isNotEmpty) {
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
                            senderName: isCurrentUser
                                ? 'You'
                                : widget.friendName,
                            onDoubleTap: () async {
                              if (_isSelectionMode) return;

                              final String? uid =
                              _authService.getCurrentUserId();
                              if (uid == null || uid.isEmpty) {
                                return;
                              }

                              await _chatService.toggleLikeMessage(
                                messageId: lastMsg.id,
                                userId: uid,
                              );
                            },
                            onLongPress: !_isSelectionMode &&
                                !lastMsg.isDeleted
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

                        final bool isSelected =
                        _selectedMessageIds.contains(lastMsg.id);

                        final selectableBubble = MySelectableBubble(
                          isSelected: isSelected,
                          onLongPress: () =>
                              _handleBubbleLongPress(
                                lastMsg,
                                isCurrentUser,
                              ),
                          onTap: () {
                            if (_isSelectionMode &&
                                currentUserId != null &&
                                lastMsg.senderId == currentUserId) {
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

              // Input
              SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTo != null &&
                        currentUserId != null &&
                        currentUserId.isNotEmpty)
                      _buildReplyPreviewBar(
                        _replyTo!,
                        currentUserId,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: MyChatTextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        onSendPressed: _sendMessage,
                        onEmojiPressed: () =>
                            debugPrint('Emoji pressed'),
                        onAttachmentPressed: () async {
                          if (_chatRoomId == null) return;
                          final currentUserId =
                          _authService.getCurrentUserId();
                          if (currentUserId == null ||
                              currentUserId.isEmpty) {
                            return;
                          }

                          await ChatMediaHelper
                              .openAttachmentSheetForDM(
                            context: context,
                            chatRoomId: _chatRoomId!,
                            currentUserId: currentUserId,
                            otherUserId: widget.friendId,
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
