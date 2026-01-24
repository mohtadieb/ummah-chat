// lib/services/chat/chat_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'chat_service.dart';
import '../../models/message.dart';

/// ChatProvider
///
/// - Keeps messages in memory per chat room (DM + group)
/// - Listens to realtime changes (INSERT + UPDATE) from Supabase
/// - Exposes a simple API for the rest of the app:
///     - listenToRoom / getMessages
///     - getOrCreateChatRoomId
///     - markRoomMessagesAsRead / markGroupMessagesAsRead
///     - updateLastSeen / setActiveChatRoom
///     - typing (setTypingStatus / friendTypingStream / groupTypingStream)
///     - sendMessage / sendGroupMessage
///     - sendImageMessageDM / sendGroupImageMessage
///     - createPendingVideoMessageDM / createPendingGroupVideoMessage
///     - uploadVoiceFile / sendVoiceMessageDM / sendVoiceMessageGroup
///     - markVideoMessageUploaded
///     - addUsersToGroup / fetchGroupMemberLinks
///     - unreadCountsPollingStream / lastMessagesByFriendPollingStream
///     - groupRoomsForUserPollingStream / lastGroupMessagesPollingStream
///     - groupUnreadCountsPollingStream
///     - leaveGroup / deleteGroupAsAdmin
///     - toggleLikeMessage
///     - deleteMessageForEveryone
///     - createGroupRoom
///
/// Only this provider talks to ChatService; UI & helpers use ChatProvider.
class ChatProvider with ChangeNotifier {
  // Store messages per room as raw maps from Supabase
  final Map<String, List<Map<String, dynamic>>> _messagesByRoom = {};

  // Store realtime subscriptions per room
  final Map<String, StreamSubscription<Map<String, dynamic>>> _subscriptions =
  {};

  // Backend / Supabase helper (internal only)
  final ChatService _chatService = ChatService();

  /// Public getter used by ChatPage / GroupChatPage:
  /// returns the list of raw message maps for a given room.
  List<Map<String, dynamic>> getMessages(String roomId) {
    return _messagesByRoom[roomId] ?? const [];
  }

  // ---------------------------------------------------------------------------
  // LISTEN TO ROOM (DM + GROUP)
  // ---------------------------------------------------------------------------

  /// Fetch existing messages + subscribe to realtime updates (insert + update)
  Future<void> listenToRoom(String roomId) async {
    // Avoid double listeners: cancel previous sub if any
    await _subscriptions[roomId]?.cancel();
    _subscriptions.remove(roomId);

    // 1️⃣ Fetch old messages ONCE
    final pastMessages = await _chatService.fetchMessagesFromDatabase(roomId);

    _messagesByRoom[roomId] = List<Map<String, dynamic>>.from(pastMessages);
    _sortMessages(roomId);
    notifyListeners();

    // 2️⃣ Listen to realtime changes (insert + update)
    final stream = _chatService.streamMessagesFromDatabase(roomId);

    final sub = stream.listen((payload) {
      final current = _messagesByRoom[roomId] ?? <Map<String, dynamic>>[];

      final dynamic id = payload['id'];
      final int existingIndex = current.indexWhere((m) => m['id'] == id);

      if (existingIndex == -1) {
        // New message (INSERT)
        current.add(payload);
      } else {
        // Updated message (UPDATE)
        current[existingIndex] = payload;
      }

      _messagesByRoom[roomId] = current;
      _sortMessages(roomId);
      notifyListeners();
    });

    _subscriptions[roomId] = sub;
  }

  /// Helper to keep messages sorted by created_at ascending.
  void _sortMessages(String roomId) {
    final msgs = _messagesByRoom[roomId];
    if (msgs == null) return;

    msgs.sort((a, b) {
      final aTs = a['created_at']?.toString() ?? '';
      final bTs = b['created_at']?.toString() ?? '';
      return aTs.compareTo(bTs);
    });
  }

  // ---------------------------------------------------------------------------
  // ROOM / PRESENCE / TYPING
  // ---------------------------------------------------------------------------

  Future<String> getOrCreateChatRoomId(
      String currentUserId,
      String friendId,
      ) {
    return _chatService.getOrCreateChatRoomIdFromDatabase(
      currentUserId,
      friendId,
    );
  }

  Future<void> markRoomMessagesAsRead(
      String chatRoomId,
      String currentUserId,
      ) {
    return _chatService.markRoomMessagesAsReadInDatabase(
      chatRoomId,
      currentUserId,
    );
  }

  Future<void> markGroupMessagesAsRead(
      String chatRoomId,
      String currentUserId,
      ) {
    return _chatService.markGroupMessagesAsReadInDatabase(
      chatRoomId,
      currentUserId,
    );
  }

  Future<void> updateLastSeen(String userId) {
    return _chatService.updateLastSeenInDatabase(userId);
  }

  /// Set active chat room presence (DM + group)
  Future<void> setActiveChatRoom({
    required String userId,
    String? chatRoomId,
  }) {
    return _chatService.setActiveChatRoomForUserInDatabase(
      userId: userId,
      chatRoomId: chatRoomId,
    );
  }

  // ---------------------------------------------------------------------------
  // 🟢 TYPING INDICATOR
  // ---------------------------------------------------------------------------

  /// Typing stream for 1-on-1 chats: `true` if friend is typing.
  Stream<bool> friendTypingStream({
    required String chatRoomId,
    required String friendId,
  }) {
    return _chatService.friendTypingStreamFromDatabase(
      chatRoomId: chatRoomId,
      friendId: friendId,
    );
  }

  /// Typing stream for group chats:
  /// emits a list of userIds that are currently typing in this room.
  ///
  /// `currentUserId` is passed so the backend *can* exclude the caller if you
  /// want, but in the UI we also filter it out just in case.
  Stream<List<String>> groupTypingStream({
    required String chatRoomId,
    required String currentUserId,
  }) {
    return _chatService.groupTypingStreamFromDatabase(
      chatRoomId: chatRoomId,
      currentUserId: currentUserId,
    );
  }

  Future<void> setTypingStatus({
    required String chatRoomId,
    required String userId,
    required bool isTyping,
  }) {
    return _chatService.setTypingStatusInDatabase(
      chatRoomId: chatRoomId,
      userId: userId,
      isTyping: isTyping,
    );
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API – DIRECT MESSAGES
  // ---------------------------------------------------------------------------

  Future<void> sendMessage(
      String roomId,
      String senderId,
      String receiverId,
      String text, {
        String? replyToMessageId,
      }) async {
    await _chatService.sendMessageInDatabase(
      roomId,
      senderId,
      receiverId,
      text,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> sendImageMessageDM({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    await _chatService.sendImageMessageInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      imageUrl: imageUrl,
      message: message,
      createdAtOverride: createdAtOverride,
    );
  }

  Future<String> createPendingVideoMessageDM({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    return _chatService.createPendingVideoMessageDMInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      videoUrl: videoUrl,
      message: message,
      createdAtOverride: createdAtOverride,
    );
  }

  Future<String> uploadVoiceFile({
    required String chatRoomId,
    required String messageId,
    required String filePath,
  }) {
    return _chatService.uploadVoiceFileToDatabase(
      chatRoomId: chatRoomId,
      messageId: messageId,
      filePath: filePath,
    );
  }

  Future<void> sendVoiceMessageDM({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String audioUrl,
    required int durationSeconds,
    String? replyToMessageId,
  }) {
    return _chatService.sendVoiceMessageDMInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> markVideoMessageUploaded(String messageId) async {
    await _chatService.markVideoMessageUploadedInDatabase(messageId);
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API – GROUP CHATS
  // ---------------------------------------------------------------------------

  Future<void> sendGroupMessage(
      String roomId,
      String senderId,
      String text, {
        String? replyToMessageId,
      }) async {
    await _chatService.sendGroupMessageInDatabase(
      roomId,
      senderId,
      text,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> sendGroupImageMessage({
    required String chatRoomId,
    required String senderId,
    required String imageUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    await _chatService.sendGroupImageMessageInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      imageUrl: imageUrl,
      message: message,
      createdAtOverride: createdAtOverride,
    );
  }

  Future<String> createPendingGroupVideoMessage({
    required String chatRoomId,
    required String senderId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    return _chatService.createPendingGroupVideoMessageInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      videoUrl: videoUrl,
      message: message,
      createdAtOverride: createdAtOverride,
    );
  }

  Future<void> sendVoiceMessageGroup({
    required String chatRoomId,
    required String senderId,
    required String audioUrl,
    required int durationSeconds,
    String? replyToMessageId,
  }) {
    return _chatService.sendVoiceMessageGroupInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> addUsersToGroup({
    required String chatRoomId,
    required List<String> userIds,
  }) async {
    await _chatService.addUsersToGroupInDatabase(
      chatRoomId: chatRoomId,
      userIds: userIds,
    );
  }

  Future<List<Map<String, dynamic>>> fetchGroupMemberLinks(
      String chatRoomId,
      ) {
    return _chatService.fetchGroupMemberLinksFromDatabase(chatRoomId);
  }

  // ---------------------------------------------------------------------------
// 🆕 CHAT ROOM CONTEXT (exposed to UI)
// ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchChatRoomContext(String chatRoomId) {
    return _chatService.fetchChatRoomContextByIdFromDatabase(chatRoomId);
  }


  Future<String> createGroupRoom({
    required String name,
    required String creatorId,
    List<String> initialMemberIds = const [],
    String? avatarUrl,
  }) {
    return _chatService.createGroupRoomInDatabase(
      name: name,
      creatorId: creatorId,
      initialMemberIds: initialMemberIds,
      avatarUrl: avatarUrl,
    );
  }

  Future<void> leaveGroup({
    required String chatRoomId,
    required String userId,
  }) {
    return _chatService.leaveGroupInDatabase(
      chatRoomId: chatRoomId,
      userId: userId,
    );
  }

  Future<void> deleteGroupAsAdmin({
    required String chatRoomId,
  }) {
    return _chatService.deleteGroupAsAdminInDatabase(
      chatRoomId: chatRoomId,
    );
  }

  // ---------------------------------------------------------------------------
  // LIST DATA – DM + GROUP OVERVIEWS
  // ---------------------------------------------------------------------------

  /// DM unread counts per friend
  Stream<Map<String, int>> unreadCountsPollingStream(
      String currentUserId, {
        Duration interval = const Duration(seconds: 3),
      }) {
    return _chatService.unreadCountsPollingStreamFromDatabase(
      currentUserId,
      interval: interval,
    );
  }

  /// DM last message per friend
  Stream<Map<String, LastMessageInfo>> lastMessagesByFriendPollingStream(
      String currentUserId, {
        Duration interval = const Duration(seconds: 6),
      }) {
    return _chatService.lastMessagesByFriendPollingStreamFromDatabase(
      currentUserId,
      interval: interval,
    );
  }

  /// Group rooms where user is member
  Stream<List<Map<String, dynamic>>> groupRoomsForUserPollingStream(
      String userId, {
        Duration interval = const Duration(seconds: 20),
      }) {
    return _chatService.groupRoomsForUserPollingStreamFromDatabase(
      userId,
      interval: interval,
    );
  }

  /// Last message per group
  Stream<Map<String, MessageModel>> lastGroupMessagesPollingStream({
    Duration interval = const Duration(seconds: 3),
  }) {
    return _chatService.lastGroupMessagesPollingStreamFromDatabase(
      interval: interval,
    );
  }

  /// Unread counts per group
  Stream<Map<String, int>> groupUnreadCountsPollingStream(
      String currentUserId, {
        Duration interval = const Duration(seconds: 3),
      }) {
    return _chatService.groupUnreadCountsPollingStreamFromDatabase(
      currentUserId,
      interval: interval,
    );
  }

  // ---------------------------------------------------------------------------
  // REACTIONS + DELETE
  // ---------------------------------------------------------------------------

  Future<void> toggleLikeMessage({
    required String messageId,
    required String userId,
  }) {
    return _chatService.toggleLikeMessageInDatabase(
      messageId: messageId,
      userId: userId,
    );
  }

  Future<void> deleteMessageForEveryone({
    required String messageId,
    required String userId,
  }) {
    return _chatService.deleteMessageForEveryoneInDatabase(
      messageId: messageId,
      userId: userId,
    );
  }

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
