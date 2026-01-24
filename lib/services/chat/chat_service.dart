// lib/services/chat/chat_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/message.dart';
import '../database/database_service.dart';
import '../notifications/notification_service.dart';

/// Info about the last message exchanged with a friend (DM only)
class LastMessageInfo {
  final String friendId;
  final String? text;
  final DateTime? createdAt;
  final bool sentByCurrentUser;

  LastMessageInfo({
    required this.friendId,
    required this.text,
    required this.createdAt,
    required this.sentByCurrentUser,
  });
}

/// ChatService
///
/// Handles all DB + realtime logic for:
/// - 1-on-1 DMs
/// - Group chats
/// - Typing status
/// - Likes (reactions)
/// - Last message summaries
/// - Unread counters
class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notifications = NotificationService();
  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // ✉️ DIRECT MESSAGE (1-ON-1) BASICS
  // ---------------------------------------------------------------------------

  /// Send a 1-on-1 *text* message (DATABASE)
  ///
  /// - `chat_room_id` = room id (DM)
  /// - `sender_id`    = current user
  /// - `receiver_id`  = friend
  /// - `message`      = text
  Future<void> sendMessageInDatabase(
      String chatRoomId,
      String senderId,
      String receiverId,
      String message, {
        String? replyToMessageId,
      }) async {
    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'reply_to_message_id': replyToMessageId,
      // `is_delivered`, `is_read`, `liked_by` use DB defaults
    });

    // 🔔 After insert → send in-app + push notification to receiver
    await notifyUserOfNewMessageInDatabase(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      textPreview: message,
    );
  }

  /// 🖼 Send a 1-on-1 *image* message (DATABASE)
  ///
  /// - `createdAtOverride` lets us force the same timestamp for batched media
  ///   (multi-image WhatsApp-style grouping)
  Future<void> sendImageMessageInDatabase({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt = (createdAtOverride ?? DateTime.now().toUtc())
        .toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'image_url': imageUrl,
      'created_at': createdAt,
    });

    final preview = message.trim().isNotEmpty
        ? message.trim()
        : 'Sent you a photo';

    await notifyUserOfNewMessageInDatabase(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      textPreview: preview,
    );
  }

  /// 🎥 Send a 1-on-1 *video* message (DATABASE)
  ///
  /// - `video_url` points to Supabase Storage (chat_uploads bucket)
  /// - `message` can be a caption (or empty)
  Future<void> sendVideoMessageInDatabase({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt = (createdAtOverride ?? DateTime.now().toUtc())
        .toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'video_url': videoUrl,
      'created_at': createdAt,
    });

    final preview = message.trim().isNotEmpty
        ? message.trim()
        : 'Sent you a video';

    await notifyUserOfNewMessageInDatabase(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      textPreview: preview,
    );
  }

  /// 🆕 Create a pending 1-on-1 video message (is_uploading = true) (DATABASE)
  Future<String> createPendingVideoMessageDMInDatabase({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt = (createdAtOverride ?? DateTime.now().toUtc())
        .toIso8601String();

    final inserted = await _supabase
        .from('messages')
        .insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'video_url': videoUrl,
      'created_at': createdAt,
      'is_uploading': true,
    })
        .select('id')
        .maybeSingle();

    if (inserted == null || inserted['id'] == null) {
      throw Exception('Failed to create pending video message (DM)');
    }

    return inserted['id'].toString();
  }

  /// Get or create a 1-on-1 chat room ID (DATABASE)
  ///
  /// Uses `chat_rooms` with:
  /// - user1_id, user2_id
  /// - is_group = false (DM)
  Future<String> getOrCreateChatRoomIdFromDatabase(
      String currentUserId,
      String friendId,
      ) async {
    final room = await _supabase
        .from('chat_rooms')
        .select('id')
        .or(
      'and(user1_id.eq.$currentUserId,user2_id.eq.$friendId),'
          'and(user1_id.eq.$friendId,user2_id.eq.$currentUserId)',
    )
        .maybeSingle();

    if (room != null) return room['id'] as String;

    final newRoom = await _supabase
        .from('chat_rooms')
        .insert({
      'user1_id': currentUserId,
      'user2_id': friendId,
      'is_group': false,
    })
        .select()
        .maybeSingle();

    return newRoom!['id'] as String;
  }

  /// Fetch all messages for a room (DM or group) FROM DATABASE,
  /// sorted oldest → newest.
  Future<List<Map<String, dynamic>>> fetchMessagesFromDatabase(
      String chatRoomId,
      ) async {
    final data = await _supabase
        .from('messages')
        .select()
        .eq('chat_room_id', chatRoomId)
        .order('created_at', ascending: true);

    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Realtime listener for messages in a room FROM DATABASE.
  ///
  /// Emits both INSERTs (new messages) and UPDATEs
  /// (e.g. is_read, liked_by, image_url, video_url).
  Stream<Map<String, dynamic>> streamMessagesFromDatabase(String chatRoomId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channel = _supabase
        .channel('public:messages-room-$chatRoomId')
    // INSERT (new messages)
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_room_id',
        value: chatRoomId,
      ),
      callback: (payload) {
        if (payload.newRecord != null) {
          controller.add(payload.newRecord);
        }
      },
    )
    // UPDATE (e.g. is_read / liked_by / image_url / video_url updated)
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_room_id',
        value: chatRoomId,
      ),
      callback: (payload) {
        if (payload.newRecord != null) {
          controller.add(payload.newRecord);
        }
      },
    );

    channel.subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Get all users for FriendsPage (optional) FROM DATABASE
  Stream<List<Map<String, dynamic>>> getUserStreamFromDatabase() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map((r) => r as Map<String, dynamic>).toList());
  }

  /// Mark all messages in a DM chat room as read for the current user (DATABASE)
  ///
  /// Only applies to 1-on-1 messages, because group messages have receiver_id = NULL.
  Future<void> markRoomMessagesAsReadInDatabase(
      String chatRoomId,
      String currentUserId,
      ) async {
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('chat_room_id', chatRoomId)
        .eq('receiver_id', currentUserId)
        .eq('is_read', false);

    // Also clear the chat notification for this room so a new push can be sent next time.
    await _notifications.markChatNotificationsAsRead(
      chatRoomId: chatRoomId,
      userId: currentUserId,
    );
  }

  /// Get unread message counts per friend for the current user (DM only) FROM DATABASE.
  ///
  /// Returns a map: { senderId: unreadCount }
  Future<Map<String, int>> fetchUnreadCountsByFriendFromDatabase(
      String currentUserId,
      ) async {
    final data = await _supabase
        .from('messages')
        .select('sender_id')
        .eq('receiver_id', currentUserId)
        .eq('is_read', false);

    final Map<String, int> counts = {};

    for (final row in data) {
      final senderId = row['sender_id'] as String;
      counts[senderId] = (counts[senderId] ?? 0) + 1;
    }

    return counts;
  }

  /// Update the user's last_seen_at to "now" (UTC) IN DATABASE
  Future<void> updateLastSeenInDatabase(String userId) async {
    await _supabase
        .from('profiles')
        .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId);
  }

  /// 🆕 Set / clear which chat room the user is actively viewing (DM + group)
  Future<void> setActiveChatRoomForUserInDatabase({
    required String userId,
    String? chatRoomId,
  }) async {
    if (userId.isEmpty) return;

    try {
      await _supabase.from('user_chat_presence').upsert({
        'user_id': userId,
        'active_chat_room_id': chatRoomId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ Error setting active chat room presence: $e');
    }
  }

  /// 🔁 Polling stream of unread counts per friend (FROM DATABASE).
  ///
  /// Uses your existing fetchUnreadCountsByFriendFromDatabase() under the hood,
  /// but exposes it as a Stream that updates every [interval].
  Stream<Map<String, int>> unreadCountsPollingStreamFromDatabase(
      String currentUserId, {
        Duration interval = const Duration(seconds: 12),
      }) async* {
    // Initial value immediately
    yield await fetchUnreadCountsByFriendFromDatabase(currentUserId);

    // Then periodically
    yield* Stream.periodic(
      interval,
    ).asyncMap((_) => fetchUnreadCountsByFriendFromDatabase(currentUserId));
  }

  /// Notify a user that they received a new chat message (IN DATABASE + push).
  ///
  /// Called RIGHT AFTER inserting the message into your messages table.
  Future<void> notifyUserOfNewMessageInDatabase({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String textPreview,
  }) async {
    if (receiverId.isEmpty || senderId.isEmpty) return;
    if (receiverId == senderId) return; // don't notify yourself

    try {
      // 1️⃣ Skip notification if receiver is currently viewing this chat
      try {
        final presence = await _supabase
            .from('user_chat_presence')
            .select('active_chat_room_id')
            .eq('user_id', receiverId)
            .maybeSingle();

        final String? activeRoomId = presence == null
            ? null
            : presence['active_chat_room_id'] as String?;

        if (activeRoomId != null && activeRoomId == chatId) {
          debugPrint(
            'ℹ️ Skipping notification: receiver is currently in chat $chatId',
          );
          return;
        }
      } catch (e) {
        debugPrint(
          '⚠️ Presence lookup failed, continuing with notification: $e',
        );
      }

      // 2️⃣ Build sender display name
      final senderProfile = await _db.getUserFromDatabase(senderId);
      final displayName = (senderProfile?.username.isNotEmpty ?? false)
          ? senderProfile!.username
          : (senderProfile?.name ?? 'Someone');

      final preview = textPreview.trim();
      final truncatedPreview = preview.length > 60
          ? '${preview.substring(0, 60)}…'
          : preview;

      // 3️⃣ Use chat-specific notification helper
      await _notifications.createOrUpdateChatNotification(
        targetUserId: receiverId,
        chatRoomId: chatId,
        senderId: senderId,
        senderName: displayName,
        messagePreview: truncatedPreview.isEmpty
            ? '$displayName sent you a message'
            : truncatedPreview,
      );
    } catch (e) {
      debugPrint('⚠️ Error creating chat message notification: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 🕒 LAST MESSAGE INFO PER FRIEND (DM ONLY)
  // ---------------------------------------------------------------------------

  /// Fetch the latest message (text + time) per friend for this user FROM DATABASE.
  ///
  /// Only considers 1-on-1 messages (both sender_id and receiver_id non-null).
  ///
  /// Returns a map: { friendId: LastMessageInfo }
  Future<Map<String, LastMessageInfo>> fetchLastMessagesByFriendFromDatabase(
      String currentUserId,
      ) async {
    // Get all messages where currentUser is either sender OR receiver.
    // We intentionally ignore group messages (receiver_id is NULL there).
    final data = await _supabase
        .from('messages')
        .select('sender_id, receiver_id, message, created_at')
        .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
        .order('created_at', ascending: false);

    final Map<String, LastMessageInfo> lastMessages = {};

    for (final row in data) {
      final String? senderId = row['sender_id']?.toString();
      final String? receiverId = row['receiver_id']?.toString();
      final String? messageText = row['message'] as String?;

      // Skip any rows where we cannot determine a "friend"
      // (e.g. group messages with receiver_id = NULL)
      if (senderId == null || receiverId == null) continue;

      // Determine the "other" person in this message
      final String friendId = senderId == currentUserId ? receiverId : senderId;

      // We ordered DESC by created_at, so first time we see this friend
      // is already the newest message → keep it and skip older ones.
      if (lastMessages.containsKey(friendId)) continue;

      final rawCreatedAt = row['created_at'];
      DateTime? createdAt;

      if (rawCreatedAt is String) {
        createdAt = DateTime.tryParse(rawCreatedAt);
      } else if (rawCreatedAt is DateTime) {
        createdAt = rawCreatedAt;
      }

      lastMessages[friendId] = LastMessageInfo(
        friendId: friendId,
        text: messageText,
        createdAt: createdAt,
        sentByCurrentUser: senderId == currentUserId,
      );
    }

    return lastMessages;
  }

  /// Polling stream of "last message info" per friend for this user (FROM DATABASE).
  ///
  /// Returns a map: { friendId: LastMessageInfo }
  Stream<Map<String, LastMessageInfo>>
  lastMessagesByFriendPollingStreamFromDatabase(
      String currentUserId, {
        Duration interval = const Duration(seconds: 18),
      }) async* {
    // Initial value immediately
    yield await fetchLastMessagesByFriendFromDatabase(currentUserId);

    // Then periodically
    yield* Stream.periodic(
      interval,
    ).asyncMap((_) => fetchLastMessagesByFriendFromDatabase(currentUserId));
  }

  // ---------------------------------------------------------------------------
  // 🟢 TYPING INDICATOR
  // ---------------------------------------------------------------------------

  /// Set current user's typing status in a chat room (IN DATABASE)
  Future<void> setTypingStatusInDatabase({
    required String chatRoomId,
    required String userId,
    required bool isTyping,
  }) async {
    await _supabase.from('typing_status').upsert({
      'user_id': userId,
      'chat_room_id': chatRoomId,
      'is_typing': isTyping,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Stream that tells whether [friendId] is currently typing in [chatRoomId] (FROM DATABASE).
  ///
  /// NOTE: We only filter by chat_room_id in the stream, and filter user_id in Dart
  /// to avoid the multiple `.eq(...)` error you had.
  Stream<bool> friendTypingStreamFromDatabase({
    required String chatRoomId,
    required String friendId,
  }) {
    return _supabase
        .from('typing_status')
        .stream(
      // must be columns that uniquely identify a row
      primaryKey: ['user_id', 'chat_room_id'],
    )
    // Only rows for this room
        .eq('chat_room_id', chatRoomId)
        .map((rows) {
      debugPrint('🔁 typing_status rows for room $chatRoomId: $rows');

      if (rows.isEmpty) {
        return false;
      }

      // Find the row for THIS friend
      final matching = rows.where(
            (row) => row['user_id']?.toString() == friendId,
      );

      if (matching.isEmpty) {
        return false;
      }

      final row = matching.first;

      final isTyping = (row['is_typing'] as bool?) ?? false;

      final rawUpdated = row['updated_at'];
      DateTime? updatedAt;

      if (rawUpdated is String) {
        updatedAt = DateTime.tryParse(rawUpdated);
      } else if (rawUpdated is DateTime) {
        updatedAt = rawUpdated;
      }

      if (updatedAt != null) {
        final diff = DateTime.now().toUtc().difference(updatedAt.toUtc());
        if (diff.inSeconds > 10) {
          // too old = no longer typing
          return false;
        }
      }

      return isTyping;
    });
  }

  /// 🆕 Stream of *all other users* currently typing in a GROUP chat.
  ///
  /// - Returns a `List<String>` of userIds.
  /// - Excludes [currentUserId] from the list.
  /// - Ignores rows where `is_typing = false` or where `updated_at` is stale
  ///   (older than ~10 seconds).
  Stream<List<String>> groupTypingStreamFromDatabase({
    required String chatRoomId,
    required String currentUserId,
  }) {
    return _supabase
        .from('typing_status')
        .stream(
      primaryKey: ['user_id', 'chat_room_id'],
    )
        .eq('chat_room_id', chatRoomId)
        .map((rows) {
      debugPrint('🔁 group typing rows for room $chatRoomId: $rows');

      final now = DateTime.now().toUtc();
      final List<String> typingUserIds = [];

      for (final row in rows) {
        final String? userId = row['user_id']?.toString();
        if (userId == null || userId == currentUserId) continue;

        final bool isTyping = (row['is_typing'] as bool?) ?? false;
        if (!isTyping) continue;

        final rawUpdated = row['updated_at'];
        DateTime? updatedAt;

        if (rawUpdated is String) {
          updatedAt = DateTime.tryParse(rawUpdated);
        } else if (rawUpdated is DateTime) {
          updatedAt = rawUpdated;
        }

        if (updatedAt == null) continue;

        final diff = now.difference(updatedAt.toUtc());
        if (diff.inSeconds > 10) {
          // too old → treat as not typing
          continue;
        }

        typingUserIds.add(userId);
      }

      return typingUserIds;
    });
  }

  // ---------------------------------------------------------------------------
  // ❤️ MESSAGE REACTIONS (LIKE)
  // ---------------------------------------------------------------------------

  /// Toggle "like" for a message by a given user (IN DATABASE).
  ///
  /// Uses the `liked_by` text[] column on messages.
  /// If userId is in liked_by → remove it (unlike).
  /// If not → add it.
  Future<void> toggleLikeMessageInDatabase({
    required String messageId,
    required String userId,
  }) async {
    // 1) Get current liked_by for this message
    final row = await _supabase
        .from('messages')
        .select('liked_by')
        .eq('id', messageId)
        .maybeSingle();

    if (row == null) return;

    final current =
        (row['liked_by'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];

    // 2) Add or remove userId
    if (current.contains(userId)) {
      current.remove(userId);
    } else {
      current.add(userId);
    }

    // 3) Update row
    await _supabase
        .from('messages')
        .update({'liked_by': current})
        .eq('id', messageId);
  }

  // ---------------------------------------------------------------------------
  // 🧑‍🤝‍🧑 GROUP CHATS – CREATION & SENDING
  // ---------------------------------------------------------------------------

  /// Create a new group chat room IN DATABASE.
  ///
  /// - is_group   = true
  /// - name       = group name
  /// - created_by = creatorId
  /// - members    = [creatorId, ...initialMemberIds]
  ///
  /// Returns the new chat_room_id.
  Future<String> createGroupRoomInDatabase({
    required String name,
    required String creatorId,
    List<String> initialMemberIds = const [],
    String? avatarUrl,
  }) async {
    // 0) Enforce creatorId == auth.uid()
    final currentUid = _supabase.auth.currentUser?.id;
    if (currentUid == null || currentUid != creatorId) {
      throw Exception('creatorId must be the authenticated user (auth.uid()).');
    }

    // 1) Create group room
    final createdRoom = await _supabase
        .from('chat_rooms')
        .insert({
      'is_group': true,
      'name': name,
      'avatar_url': avatarUrl,
      'created_by': creatorId,
      // For groups we don't use user1_id / user2_id.
      'user1_id': null,
      'user2_id': null,
    })
        .select('id')
        .maybeSingle();

    if (createdRoom == null || createdRoom['id'] == null) {
      throw Exception('Failed to create group room');
    }

    final String roomId = createdRoom['id'] as String;

    // 2) Add creator as admin
    await _supabase.from('chat_room_members').insert({
      'chat_room_id': roomId,
      'user_id': creatorId,
      'role': 'admin',
    });

    // 3) Add remaining members (deduped, excluding creator)
    final otherMembers = initialMemberIds
        .where((id) => id.trim().isNotEmpty && id != creatorId)
        .toSet()
        .toList();

    if (otherMembers.isNotEmpty) {
      final rows = otherMembers
          .map(
            (uid) => {
          'chat_room_id': roomId,
          'user_id': uid,
          'role': 'member',
        },
      )
          .toList();

      await _supabase.from('chat_room_members').insert(rows);

      // 4) Notify each added member (DO NOT break normal group creation if notif fails)
      try {
        final creatorProfile = await _db.getUserFromDatabase(creatorId);
        final addedByName = ((creatorProfile?.username ?? '').trim().isNotEmpty)
            ? creatorProfile!.username.trim()
            : ((creatorProfile?.name ?? '').trim().isNotEmpty)
            ? creatorProfile!.name.trim()
            : 'Someone';

        for (final targetUserId in otherMembers) {
          // Skip notifying yourself (already excluded, but just in case)
          if (targetUserId == creatorId) continue;

          await _notifications.createGroupAddedNotification(
            targetUserId: targetUserId,
            chatRoomId: roomId,
            groupName: name,
            addedByUserId: creatorId,
            addedByName: addedByName,
          );
        }
      } catch (e) {
        debugPrint(
          '⚠️ createGroupRoomInDatabase: failed to send group-added notifications: $e',
        );
        // Intentionally swallow — group creation must still succeed.
      }
    }

    return roomId;
  }


  /// Add one or more users to an existing group chat IN DATABASE.
  ///
  /// - Uses `upsert` so we don't crash on duplicates
  ///   (because of UNIQUE(chat_room_id, user_id)).
  Future<void> addUsersToGroupInDatabase({
    required String chatRoomId,
    required List<String> userIds,
  }) async {
    if (userIds.isEmpty) return;

    final rows = userIds
        .map(
          (uid) => {
        'chat_room_id': chatRoomId,
        'user_id': uid,
        'role': 'member',
      },
    )
        .toList();

    await _supabase
        .from('chat_room_members')
        .upsert(rows, onConflict: 'chat_room_id,user_id');
  }

  /// Send a message to a GROUP chat (IN DATABASE).
  ///
  /// - Uses the same `messages` table
  /// - `chat_room_id` = group room id
  /// - `sender_id`    = current user
  /// - `receiver_id`  = NULL (because many recipients)
  Future<void> sendGroupMessageInDatabase(
      String chatRoomId,
      String senderId,
      String message, {
        String? replyToMessageId,
      }) async {
    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null,
      'message': message,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'reply_to_message_id': replyToMessageId,
    });

    // Notify group members
    await notifyGroupMembersOfNewMessageInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      textPreview: message.trim().isEmpty ? 'Sent a message' : message,
    );
  }

  /// 🖼 Send an *image* message to a GROUP chat (IN DATABASE)
  Future<void> sendGroupImageMessageInDatabase({
    required String chatRoomId,
    required String senderId,
    required String imageUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt = (createdAtOverride ?? DateTime.now().toUtc())
        .toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null,
      'message': message,
      'image_url': imageUrl,
      'created_at': createdAt,
    });

    final preview = message.trim().isNotEmpty ? message.trim() : 'Sent a photo';

    await notifyGroupMembersOfNewMessageInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      textPreview: preview,
    );
  }

  /// 🎥 Send a *video* message to a GROUP chat (IN DATABASE)
  Future<void> sendGroupVideoMessageInDatabase({
    required String chatRoomId,
    required String senderId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt = (createdAtOverride ?? DateTime.now().toUtc())
        .toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null,
      'message': message,
      'video_url': videoUrl,
      'created_at': createdAt,
    });

    final preview = message.trim().isNotEmpty ? message.trim() : 'Sent a video';

    await notifyGroupMembersOfNewMessageInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      textPreview: preview,
    );
  }

  /// 🆕 Create a pending GROUP video message (is_uploading = true) (IN DATABASE)
  Future<String> createPendingGroupVideoMessageInDatabase({
    required String chatRoomId,
    required String senderId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt = (createdAtOverride ?? DateTime.now().toUtc())
        .toIso8601String();

    final inserted = await _supabase
        .from('messages')
        .insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null,
      'message': message,
      'video_url': videoUrl,
      'created_at': createdAt,
      'is_uploading': true,
    })
        .select('id')
        .maybeSingle();

    if (inserted == null || inserted['id'] == null) {
      throw Exception('Failed to create pending video message (group)');
    }

    return inserted['id'].toString();
  }

  /// Mark all CURRENTLY unread messages in a group as read for this user (IN DATABASE).
  Future<void> markGroupMessagesAsReadInDatabase(
      String chatRoomId,
      String currentUserId,
      ) async {
    try {
      debugPrint(
        '📬 markGroupMessagesAsRead(room=$chatRoomId, user=$currentUserId)',
      );

      final updated = await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('chat_room_id', chatRoomId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId)
          .select('id'); // returns updated rows

      final count = (updated as List).length;
      debugPrint('✅ markGroupMessagesAsRead updated $count rows');

      // 🧹 Also clear any chat notifications for this group for this user
      await _notifications.markChatNotificationsAsRead(
        chatRoomId: chatRoomId,
        userId: currentUserId,
      );
    } catch (e) {
      debugPrint('❌ markGroupMessagesAsRead error: $e');
    }
  }

  /// 🆕 Mark a video message as fully uploaded (remove uploading badge) IN DATABASE
  Future<void> markVideoMessageUploadedInDatabase(String messageId) async {
    await _supabase
        .from('messages')
        .update({'is_uploading': false})
        .eq('id', messageId);
  }

  // ---------------------------------------------------------------------------
  // 📋 GROUP LIST FOR CURRENT USER
  // ---------------------------------------------------------------------------

  /// Fetch all GROUP chat rooms where this user is a member FROM DATABASE.
  ///
  /// Returns a list of simple maps:
  ///   {
  ///     'id': <room_id>,
  ///     'name': <group name or 'Group'>,
  ///     'avatar_url': <nullable>,
  ///     'created_at': <DateTime or String>,
  ///   }
  Future<List<Map<String, dynamic>>> fetchGroupRoomsForUserFromDatabase(String userId) async {
    final data = await _supabase
        .from('chat_room_members')
        .select(
      'chat_room_id, chat_rooms!inner ('
          'id, name, avatar_url, created_at, is_group, '
          'context_type, context_id, '
          'man_id, woman_id, mahram_id, '
          'man_name, woman_name'
          ')',
    )
        .eq('user_id', userId)
        .eq('chat_rooms.is_group', true)
        .order('created_at', ascending: false, referencedTable: 'chat_rooms');

    final List<Map<String, dynamic>> groups = [];

    for (final row in data) {
      final room = row['chat_rooms'];
      if (room == null) continue;

      final map = <String, dynamic>{
        'id': room['id'],
        'name': room['name'] ?? 'Group',
        'avatar_url': room['avatar_url'],
        'created_at': room['created_at'],

        // ✅ NEW: keep extra fields so UI can localize + detect marriage inquiry
        'context_type': room['context_type'],
        'context_id': room['context_id'],
        'man_id': room['man_id'],
        'woman_id': room['woman_id'],
        'mahram_id': room['mahram_id'],
        'man_name': room['man_name'],
        'woman_name': room['woman_name'],
      };

      groups.add(map);
    }

    return groups;
  }


  /// Polling stream of group rooms for the current user FROM DATABASE.
  Stream<List<Map<String, dynamic>>> groupRoomsForUserPollingStreamFromDatabase(
      String userId, {
        Duration interval = const Duration(seconds: 20),
      }) async* {
    // Initial value
    yield await fetchGroupRoomsForUserFromDatabase(userId);

    // Periodic updates
    yield* Stream.periodic(
      interval,
    ).asyncMap((_) => fetchGroupRoomsForUserFromDatabase(userId));
  }

  Future<bool> groupRoomExistsInDatabase(String chatRoomId) async {
    if (chatRoomId.trim().isEmpty) return false;

    final row = await _supabase
        .from('chat_rooms')
        .select('id')
        .eq('id', chatRoomId)
        .maybeSingle();

    return row != null;
  }

  // ---------------------------------------------------------------------------
// 🆕 CHAT ROOM CONTEXT (for marriage inquiry groups)
// ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchChatRoomContextByIdFromDatabase(String chatRoomId) async {
    final id = chatRoomId.trim();
    if (id.isEmpty) return null;

    final row = await _supabase
        .from('chat_rooms')
        .select(
      'id, name, context_type, context_id, '
          'man_id, woman_id, mahram_id, '
          'man_name, woman_name',
    )
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }



  // ---------------------------------------------------------------------------
  // 👥 GROUP MEMBERS
  // ---------------------------------------------------------------------------

  /// Fetch raw group member links (user_id + role) for a given chat room FROM DATABASE.
  ///
  /// We keep this low-level and let the UI fetch full profiles via DatabaseService.
  Future<List<Map<String, dynamic>>> fetchGroupMemberLinksFromDatabase(
      String chatRoomId,
      ) async {
    final data = await _supabase
        .from('chat_room_members')
        .select('user_id, role')
        .eq('chat_room_id', chatRoomId);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Remove the current user from a group chat via RPC (IN DATABASE).
  ///
  /// The RPC will also delete the room (and cascade-delete messages +
  /// memberships + typing_status rows) when the last member leaves.
  Future<void> leaveGroupInDatabase({
    required String chatRoomId,
    required String userId, // not used inside; kept for signature compatibility
  }) async {
    try {
      debugPrint('🚪 leaveGroup (RPC): user=$userId leaving room=$chatRoomId');

      // Call the Supabase RPC; user is taken from auth.uid() inside the function
      final result = await _supabase.rpc(
        'leave_group_and_cleanup',
        params: {'p_chat_room_id': chatRoomId},
      );

      debugPrint('✅ leave_group_and_cleanup result: $result');
    } catch (e) {
      debugPrint('❌ leaveGroup RPC error: $e');
      rethrow;
    }
  }

  // =======================================================================
  // NEW: Group last messages + unread counts (for GroupsPage) - NO RPC
  // =======================================================================

  /// Fetch last message per GROUP chat that this user can see FROM DATABASE.
  ///
  /// - We only consider group messages: receiver_id IS NULL (filter).
  /// - RLS on `messages` ensures we only see rooms where the user is a member.
  ///
  /// Returns a Map keyed by chatRoomId.
  Future<Map<String, MessageModel>> fetchLastGroupMessagesFromDatabase() async {
    final data = await _supabase
        .from('messages')
        .select(
      'id, chat_room_id, sender_id, receiver_id, message, '
          'image_url, video_url, audio_url, audio_duration_seconds, '
          'reply_to_message_id, created_at, is_read, is_delivered, liked_by',
    )
        .filter('receiver_id', 'is', null)
        .order('created_at', ascending: false);

    final Map<String, MessageModel> result = {};

    for (final row in data) {
      final map = Map<String, dynamic>.from(row as Map);
      final message = MessageModel.fromMap(map);

      final String roomId =
          message.chatRoomId ?? map['chat_room_id']?.toString() ?? '';
      if (roomId.isEmpty) continue;

      // We ordered by created_at DESC, so the first time we see this room
      // is already the newest message → keep it and skip older ones.
      if (result.containsKey(roomId)) continue;

      result[roomId] = message;
    }

    return result;
  }

  /// Polling stream for last group messages (similar to lastMessagesByFriend) FROM DATABASE.
  ///
  /// You can tweak [interval] to match your DM polling setup.
  Stream<Map<String, MessageModel>> lastGroupMessagesPollingStreamFromDatabase({
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      try {
        final data = await fetchLastGroupMessagesFromDatabase();
        yield data;
      } catch (_) {
        // swallow errors so the stream keeps going
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Fetch unread counts per group chat for the current user FROM DATABASE.
  ///
  /// Logic:
  /// - only group messages: receiver_id IS NULL
  /// - only not read: is_read = false
  /// - only messages NOT sent by the current user
  ///
  /// Returns a Map<chatRoomId, unreadCount>.
  Future<Map<String, int>> fetchUnreadCountsByGroupFromDatabase(
      String currentUserId,
      ) async {
    debugPrint('🔢 fetchUnreadCountsByGroup for user $currentUserId');

    final data = await _supabase
        .from('messages')
        .select('chat_room_id, sender_id, is_read, receiver_id')
        .filter('receiver_id', 'is', null) // group messages only
        .eq('is_read', false);

    debugPrint('   raw unread rows from DB: ${data.length}');

    final Map<String, int> result = {};

    for (final row in data) {
      final String? senderId = row['sender_id']?.toString();
      final String roomId = row['chat_room_id']?.toString() ?? '';
      final bool isRead = row['is_read'] == true;

      debugPrint(
        '   row: room=$roomId sender=$senderId isRead=$isRead (should be false here)',
      );

      if (roomId.isEmpty) continue;
      if (senderId == null) continue;

      // Don't count messages sent by yourself
      if (senderId == currentUserId) continue;

      result[roomId] = (result[roomId] ?? 0) + 1;
    }

    debugPrint('➡️ unread map (per group): $result');
    return result;
  }

  /// Polling stream for unread counts per group (FROM DATABASE).
  Stream<Map<String, int>> groupUnreadCountsPollingStreamFromDatabase(
      String currentUserId, {
        Duration interval = const Duration(seconds: 3),
      }) async* {
    while (true) {
      try {
        final data = await fetchUnreadCountsByGroupFromDatabase(currentUserId);
        debugPrint('📡 groupUnreadCountsPollingStream tick → $data');
        yield data;
      } catch (e) {
        debugPrint('❌ groupUnreadCountsPollingStream error: $e');
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Delete group as admin via RPC (IN DATABASE).
  ///
  /// RPC is responsible for:
  /// - deleting the chat_rooms row
  /// - cascading to messages, memberships, typing_status, etc.
  Future<void> deleteGroupAsAdminInDatabase({
    required String chatRoomId,
  }) async {
    try {
      debugPrint('🗑 deleteGroupAsAdmin: room=$chatRoomId');
      final result = await _supabase.rpc(
        'delete_group_as_admin',
        params: {'p_chat_room_id': chatRoomId},
      );
      debugPrint('✅ delete_group_as_admin result: $result');
    } catch (e) {
      debugPrint('❌ deleteGroupAsAdmin error: $e');
      rethrow;
    }
  }

  // =======================================================================
  //                              DELETE MESSAGES
  // =======================================================================

  Future<void> deleteMessageForEveryoneInDatabase({
    required String messageId,
    required String userId,
  }) async {
    // Only allow sender to delete
    await _supabase
        .from('messages')
        .update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'message': '',
      'image_url': null,
      'video_url': null,
      'audio_url': null,
      'audio_duration_seconds': null,
    })
        .match({'id': messageId, 'sender_id': userId});
  }

  // ---------------------------------------------------------------------------
  // 🎙 VOICE MESSAGES (DM + GROUP)
  // ---------------------------------------------------------------------------

  /// 🆕 Upload raw audio file to 'voice_messages' bucket in Supabase Storage (DATABASE)
  Future<String> uploadVoiceFileToDatabase({
    required String chatRoomId,
    required String messageId,
    required String filePath,
  }) async {
    final fileBytes = await File(filePath).readAsBytes();
    final storagePath =
        '$chatRoomId/voice_${DateTime.now().microsecondsSinceEpoch}_${const Uuid().v4()}.m4a';

    await _supabase.storage
        .from('chat_voice')
        .uploadBinary(storagePath, fileBytes);

    final publicUrl = _supabase.storage
        .from('chat_voice')
        .getPublicUrl(storagePath);

    return publicUrl;
  }

  /// 🆕 Send a voice message in a 1-on-1 DM (IN DATABASE)
  Future<void> sendVoiceMessageDMInDatabase({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String audioUrl,
    required int durationSeconds,
    String? replyToMessageId,
  }) async {
    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': '', // no text (optional)
      'audio_url': audioUrl,
      'audio_duration_seconds': durationSeconds,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'reply_to_message_id': replyToMessageId,
    });

    await notifyUserOfNewMessageInDatabase(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      textPreview: 'Sent you a voice message',
    );
  }

  /// Group notification helper (DMs use notifyUserOfNewMessageInDatabase)
  Future<void> notifyGroupMembersOfNewMessageInDatabase({
    required String chatRoomId,
    required String senderId,
    required String textPreview,
  }) async {
    try {
      // 1️⃣ Get all member IDs for this group
      final membersData = await _supabase
          .from('chat_room_members')
          .select('user_id')
          .eq('chat_room_id', chatRoomId);

      final memberIds = membersData
          .map<String?>((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (memberIds.isEmpty) return;

      // 2️⃣ Fetch presence for these users in one query
      final presenceData = await _supabase
          .from('user_chat_presence')
          .select('user_id, active_chat_room_id')
          .inFilter('user_id', memberIds);

      final Map<String, String?> activeByUser = {};
      for (final row in presenceData) {
        final uid = row['user_id']?.toString();
        if (uid == null) continue;
        activeByUser[uid] = row['active_chat_room_id']?.toString();
      }

      // 3️⃣ Build sender display name
      final senderProfile = await _db.getUserFromDatabase(senderId);
      final displayName = (senderProfile?.username.isNotEmpty ?? false)
          ? senderProfile!.username
          : (senderProfile?.name ?? 'Someone');

      // Optional: include group name
      final roomRow = await _supabase
          .from('chat_rooms')
          .select('name')
          .eq('id', chatRoomId)
          .maybeSingle();

      final groupNameRaw = (roomRow?['name'] as String?)?.trim();
      final safeGroupName = (groupNameRaw == null || groupNameRaw.isEmpty)
          ? 'Group'
          : groupNameRaw;

      final previewRaw = textPreview.trim();
      final truncatedPreview = previewRaw.length > 60
          ? '${previewRaw.substring(0, 60)}…'
          : previewRaw;

      final basePreview = truncatedPreview.isEmpty
          ? '$displayName sent a message'
          : truncatedPreview;

      // This is just for the push / UI preview text
      final messagePreview = '[$safeGroupName] $basePreview';

      // 4️⃣ Create / update notifications per target user
      for (final targetUserId in memberIds) {
        if (targetUserId == senderId) continue; // don't notify yourself

        final activeRoomId = activeByUser[targetUserId];
        if (activeRoomId != null && activeRoomId == chatRoomId) {
          debugPrint(
            'ℹ️ Skipping group notification for $targetUserId: currently in room $chatRoomId',
          );
          continue;
        }

        await _notifications.createOrUpdateGroupChatNotification(
          targetUserId: targetUserId,
          chatRoomId: chatRoomId,
          groupName: safeGroupName,
          senderId: senderId,
          senderName: displayName,
          messagePreview: messagePreview,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error creating group chat notifications: $e');
    }
  }

  /// 🆕 Send a voice message in a GROUP chat (receiver_id = NULL) (IN DATABASE)
  Future<void> sendVoiceMessageGroupInDatabase({
    required String chatRoomId,
    required String senderId,
    required String audioUrl,
    required int durationSeconds,
    String? replyToMessageId,
  }) async {
    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null,
      'message': '',
      'audio_url': audioUrl,
      'audio_duration_seconds': durationSeconds,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'reply_to_message_id': replyToMessageId,
    });

    await notifyGroupMembersOfNewMessageInDatabase(
      chatRoomId: chatRoomId,
      senderId: senderId,
      textPreview: 'Sent a voice message',
    );
  }
}
