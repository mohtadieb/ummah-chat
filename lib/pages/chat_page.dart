// lib/pages/chat_page.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/services/auth/auth_service.dart';

import '../components/my_chat_bubble.dart';
import '../components/my_chat_text_field.dart';
import '../helper/time_ago_text.dart';
import '../helper/chat_separators.dart';
import '../helper/chat_media_helper.dart';
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

/// Internal helper to group multiple DB rows into one logical bubble.
///
/// All messages in a group:
/// - same sender
/// - same caption
/// - same createdAt
/// - all have some media (image or video)
class _MessageGroup {
  final List<MessageModel> messages;
  final int firstIndex; // index in the original messages list

  _MessageGroup({required this.messages, required this.firstIndex});

  MessageModel get first => messages.first;

  MessageModel get last => messages.last;

  bool get hasImages =>
      messages.any((m) => m.imageUrl != null && m.imageUrl!.trim().isNotEmpty);
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

  // 🧲 Track last message count so we can auto-scroll when new messages arrive
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();

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

  /// Initialize chat room and start real-time listener
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

  @override
  void dispose() {
    _statusTimer?.cancel();
    _presenceTimer?.cancel();
    _friendTypingSub?.cancel();
    _typingDebounce?.cancel();

    _focusNode.dispose();
    _messageController.removeListener(_handleTypingChange);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    if (text.isEmpty || _chatRoomId == null) return;

    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId == null || currentUserId.isEmpty) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);

    _messageController.clear();
    _scrollDown();

    await provider.sendMessage(
      _chatRoomId!,
      currentUserId,
      widget.friendId,
      text,
    );

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

  /// Build logical message groups from a flat messages list.
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

  /// Show bottom sheet with list of users who liked a message
  Future<void> _showLikesBottomSheet(List<String> userIds) async {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.getCurrentUserId();

    final uniqueIds = userIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) return;

    Future<List<UserProfile>> fetchProfiles() async {
      final List<UserProfile> profiles = [];
      for (final id in uniqueIds) {
        final profile = await _dbService.getUserFromDatabase(id);
        if (profile != null) {
          profiles.add(profile);
        }
      }
      return profiles;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return FutureBuilder<List<UserProfile>>(
          future: fetchProfiles(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final profiles = snapshot.data!;
            if (profiles.isEmpty) {
              return const SizedBox(
                height: 220,
                child: Center(child: Text('No likes yet')),
              );
            }

            return SizedBox(
              height: 320,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => Divider(
                  height: 0,
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, index) {
                  final user = profiles[index];
                  final isYou =
                      currentUserId != null && user.id == currentUserId;

                  final name = user.name.isNotEmpty
                      ? user.name
                      : (user.username.isNotEmpty ? user.username : user.email);

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
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
      },
    );
  }

  /// DELETE MESSAGES
  Future<void> _confirmDeleteMessage(String messageId) async {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId.isEmpty) return;

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
              child: Text('Delete', style: TextStyle(color: Colors.red)),
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.getCurrentUserId();
    final colorScheme = Theme.of(context).colorScheme;

    final subtitleWidget = _buildSubtitle(colorScheme);

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
              widget.friendName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (subtitleWidget != null) subtitleWidget,
          ],
        ),
      ),
      body: SafeArea(
        top: false, // AppBar already handles top inset
        child: Column(
          children: [
            Expanded(
              child: _chatRoomId == null
                  ? const Center(child: CircularProgressIndicator())
                  : Consumer<ChatProvider>(
                      builder: (context, provider, _) {
                        final rawMessages = provider.getMessages(_chatRoomId!);

                        if (rawMessages.isEmpty) {
                          return const Center(child: Text("No messages yet"));
                        }

                        final messages = rawMessages
                            .map((m) => MessageModel.fromMap(m))
                            .toList();

                        // Unread info (still based on flat messages)
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

                        // Group into logical bubbles
                        final groups = _buildMessageGroups(messages);

                        // Map message index -> group index (for unread separator)
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

                        // Auto-scroll still based on message length
                        if (messages.length != _lastMessageCount) {
                          if (_isNearBottom()) {
                            _scrollDown();
                          }
                          _lastMessageCount = messages.length;
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            // Convert builder index → group index (reverse)
                            final groupIndex = groups.length - 1 - index;
                            final group = groups[groupIndex];

                            final firstMsg = group.first;
                            final lastMsg = group.last;

                            final isCurrentUser =
                                firstMsg.senderId == currentUserId;

                            // Collect all image URLs for this group
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

                            // Use last message for ticks/likes
                            final likedBy = lastMsg.likedBy;
                            final isLikedByMe =
                                currentUserId != null &&
                                likedBy.contains(currentUserId);
                            final likeCount = likedBy.length;

                            // Day divider
                            final msgDate = firstMsg.createdAt;
                            DateTime? prevDate;
                            if (groupIndex > 0) {
                              prevDate = groups[groupIndex - 1].first.createdAt;
                            }
                            final showDayDivider =
                                prevDate == null ||
                                !isSameDay(msgDate, prevDate);

                            // Unread separator
                            final showUnreadSeparator =
                                unreadCount > 0 &&
                                firstUnreadGroupIndex != null &&
                                groupIndex == firstUnreadGroupIndex;

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
                                      senderName: isCurrentUser
                                          ? 'You'
                                          : widget.friendName,
                                      onDoubleTap: () async {
                                        final String uid = _authService
                                            .getCurrentUserId();
                                        if (uid.isEmpty) return;

                                        await _chatService.toggleLikeMessage(
                                          messageId: lastMsg.id,
                                          userId: uid,
                                        );
                                      },
                                      onLongPress:
                                          isCurrentUser && !lastMsg.isDeleted
                                          ? () => _confirmDeleteMessage(
                                              lastMsg.id,
                                            )
                                          : null,
                                      // 🆕
                                      onLikeTap: likedBy.isEmpty
                                          ? null
                                          : () {
                                              final ids = likedBy
                                                  .map((e) => e.toString())
                                                  .toList();
                                              _showLikesBottomSheet(ids);
                                            },
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
                    if (_chatRoomId == null) return;
                    final currentUserId = _authService.getCurrentUserId();
                    if (currentUserId == null || currentUserId.isEmpty) return;

                    await ChatMediaHelper.openAttachmentSheetForDM(
                      context: context,
                      chatRoomId: _chatRoomId!,
                      currentUserId: currentUserId,
                      otherUserId: widget.friendId,
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
