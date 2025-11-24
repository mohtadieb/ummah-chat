// lib/services/chat/chat_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/message.dart';

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

  // ---------------------------------------------------------------------------
  // ✉️ DIRECT MESSAGE (1-ON-1) BASICS
  // ---------------------------------------------------------------------------

  /// Send a 1-on-1 *text* message to a chat room
  ///
  /// - `chat_room_id` = room id (DM)
  /// - `sender_id`    = current user
  /// - `receiver_id`  = friend
  /// - `message`      = text
  Future<void> sendMessage(
      String chatRoomId,
      String senderId,
      String receiverId,
      String message, {
        String? replyToMessageId, // 🆕 named
      }) async {
    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
      'reply_to_message_id': replyToMessageId, // 🆕
      // `is_delivered`, `is_read`, `liked_by` use DB defaults
    });
  }

  /// 🖼 Send a 1-on-1 *image* message
  ///
  /// - `createdAtOverride` lets us force the same timestamp for batched media
  ///   (multi-image WhatsApp-style grouping)
  Future<void> sendImageMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt =
    (createdAtOverride ?? DateTime.now().toUtc()).toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'image_url': imageUrl,
      'created_at': createdAt,
    });
  }

  /// 🎥 Send a 1-on-1 *video* message
  ///
  /// - `video_url` points to Supabase Storage (chat_uploads bucket)
  /// - `message` can be a caption (or empty)
  Future<void> sendVideoMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt =
    (createdAtOverride ?? DateTime.now().toUtc()).toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'video_url': videoUrl,
      'created_at': createdAt,
    });
  }

  /// 🆕 Create a pending 1-on-1 video message (is_uploading = true)
  Future<String> createPendingVideoMessageDM({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt =
    (createdAtOverride ?? DateTime.now().toUtc()).toIso8601String();

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

  /// Get or create a 1-on-1 chat room ID
  ///
  /// Uses `chat_rooms` with:
  /// - user1_id, user2_id
  /// - is_group = false (DM)
  Future<String> getOrCreateChatRoomId(
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

  /// Fetch all messages for a room (DM or group),
  /// sorted oldest → newest.
  ///
  /// We select everything so MessageModel.fromMap can use:
  /// - text, image_url, video_url, liked_by, is_read, etc.
  Future<List<Map<String, dynamic>>> fetchMessages(String chatRoomId) async {
    final data = await _supabase
        .from('messages')
        .select()
        .eq('chat_room_id', chatRoomId)
        .order('created_at', ascending: true);

    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Realtime listener for messages in a room.
  ///
  /// Emits both INSERTs (new messages) and UPDATEs
  /// (e.g. is_read, liked_by, image_url, video_url).
  Stream<Map<String, dynamic>> streamMessages(String chatRoomId) {
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

  /// Get all users for FriendsPage (optional)
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id']).map(
          (rows) => rows.map((r) => r as Map<String, dynamic>).toList(),
    );
  }

  /// Mark all messages in a DM chat room as read for the current user
  ///
  /// Only applies to 1-on-1 messages, because group messages have receiver_id = NULL.
  Future<void> markRoomMessagesAsRead(
      String chatRoomId,
      String currentUserId,
      ) async {
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('chat_room_id', chatRoomId)
        .eq('receiver_id', currentUserId)
        .eq('is_read', false);
  }

  /// Get unread message counts per friend for the current user (DM only).
  ///
  /// Returns a map: { senderId: unreadCount }
  Future<Map<String, int>> fetchUnreadCountsByFriend(
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

  /// Update the user's last_seen_at to "now" (UTC)
  Future<void> updateLastSeen(String userId) async {
    await _supabase.from('profiles').update({
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  /// 🔁 Polling stream of unread counts per friend.
  ///
  /// Uses your existing fetchUnreadCountsByFriend() under the hood,
  /// but exposes it as a Stream that updates every [interval].
  Stream<Map<String, int>> unreadCountsPollingStream(
      String currentUserId, {
        Duration interval = const Duration(seconds: 12),
      }) async* {
    // Initial value immediately
    yield await fetchUnreadCountsByFriend(currentUserId);

    // Then periodically
    yield* Stream.periodic(interval)
        .asyncMap((_) => fetchUnreadCountsByFriend(currentUserId));
  }

  // ---------------------------------------------------------------------------
  // 🕒 LAST MESSAGE INFO PER FRIEND (DM ONLY)
  // ---------------------------------------------------------------------------

  /// Fetch the latest message (text + time) per friend for this user.
  ///
  /// Only considers 1-on-1 messages (both sender_id and receiver_id non-null).
  ///
  /// Returns a map: { friendId: LastMessageInfo }
  Future<Map<String, LastMessageInfo>> fetchLastMessagesByFriend(
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
      final String friendId =
      senderId == currentUserId ? receiverId : senderId;

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

  /// Polling stream of "last message info" per friend for this user.
  ///
  /// Returns a map: { friendId: LastMessageInfo }
  Stream<Map<String, LastMessageInfo>> lastMessagesByFriendPollingStream(
      String currentUserId, {
        Duration interval = const Duration(seconds: 18),
      }) async* {
    // Initial value immediately
    yield await fetchLastMessagesByFriend(currentUserId);

    // Then periodically
    yield* Stream.periodic(interval)
        .asyncMap((_) => fetchLastMessagesByFriend(currentUserId));
  }

  // ---------------------------------------------------------------------------
  // 🟢 TYPING INDICATOR
  // ---------------------------------------------------------------------------

  /// Set current user's typing status in a chat room
  Future<void> setTypingStatus({
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

  /// Stream that tells whether [friendId] is currently typing in [chatRoomId].
  ///
  /// NOTE: We only filter by chat_room_id in the stream, and filter user_id in Dart
  /// to avoid the multiple `.eq(...)` error you had.
  Stream<bool> friendTypingStream({
    required String chatRoomId,
    required String friendId,
  }) {
    return _supabase
        .from('typing_status')
        .stream(primaryKey: ['user_id', 'chat_room_id'])
        .eq('chat_room_id', chatRoomId)
        .map((rows) {
      if (rows.isEmpty) return false;

      // Filter rows in this room for that specific friend
      final matching =
      rows.where((row) => row['user_id'] == friendId).toList();
      if (matching.isEmpty) return false;

      final row = matching.first;
      final isTyping = row['is_typing'] == true;

      // Optional timeout: if updated_at is older than X seconds → consider not typing
      final rawUpdated = row['updated_at'];
      if (rawUpdated is String) {
        final updatedAt = DateTime.tryParse(rawUpdated)?.toUtc();
        if (updatedAt != null &&
            DateTime.now().toUtc().difference(updatedAt).inSeconds > 10) {
          return false;
        }
      }

      return isTyping;
    });
  }

  // ---------------------------------------------------------------------------
  // ❤️ MESSAGE REACTIONS (LIKE)
  // ---------------------------------------------------------------------------

  /// Toggle "like" for a message by a given user.
  ///
  /// Uses the `liked_by` text[] column on messages.
  /// If userId is in liked_by → remove it (unlike).
  /// If not → add it.
  Future<void> toggleLikeMessage({
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

  /// Create a new group chat room.
  ///
  /// - is_group   = true
  /// - name       = group name
  /// - created_by = creatorId
  /// - members    = [creatorId, ...initialMemberIds]
  ///
  /// Returns the new chat_room_id.
  Future<String> createGroupRoom({
    required String name,
    required String creatorId,
    List<String> initialMemberIds = const [],
    String? avatarUrl,
  }) async {
    // 1) Insert row in chat_rooms
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

    if (createdRoom == null) {
      throw Exception('Failed to create group room');
    }

    final String roomId = createdRoom['id'] as String;

    // 2) Insert members: creator + optional others
    final members = <String>{creatorId, ...initialMemberIds}.toList();

    if (members.isNotEmpty) {
      final rows = members
          .map(
            (uid) => {
          'chat_room_id': roomId,
          'user_id': uid,
          // role: creator = 'admin', others = 'member'
          'role': uid == creatorId ? 'admin' : 'member',
        },
      )
          .toList();

      await _supabase.from('chat_room_members').insert(rows);
    }

    return roomId;
  }

  /// Add one or more users to an existing group chat.
  ///
  /// - Uses `upsert` so we don't crash on duplicates
  ///   (because of UNIQUE(chat_room_id, user_id)).
  Future<void> addUsersToGroup({
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

  /// Send a message to a GROUP chat.
  ///
  /// - Uses the same `messages` table
  /// - `chat_room_id` = group room id
  /// - `sender_id`    = current user
  /// - `receiver_id`  = NULL (because many recipients)
  Future<void> sendGroupMessage(
      String chatRoomId,
      String senderId,
      String message, {
        String? replyToMessageId, // 🆕
      }) async {
    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null, // group message has no single receiver
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
      'reply_to_message_id': replyToMessageId,
      // other fields use DB defaults
    });
  }

  /// 🖼 Send an *image* message to a GROUP chat
  ///
  /// - `receiver_id` = NULL for group messages
  /// - `createdAtOverride` allows grouping multiple images into one logical batch
  Future<void> sendGroupImageMessage({
    required String chatRoomId,
    required String senderId,
    required String imageUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt =
    (createdAtOverride ?? DateTime.now().toUtc()).toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null,
      'message': message,
      'image_url': imageUrl,
      'created_at': createdAt,
    });
  }

  /// 🎥 Send a *video* message to a GROUP chat
  Future<void> sendGroupVideoMessage({
    required String chatRoomId,
    required String senderId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt =
    (createdAtOverride ?? DateTime.now().toUtc()).toIso8601String();

    await _supabase.from('messages').insert({
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'receiver_id': null,
      'message': message,
      'video_url': videoUrl,
      'created_at': createdAt,
    });
  }

  /// 🆕 Create a pending GROUP video message (is_uploading = true)
  Future<String> createPendingGroupVideoMessage({
    required String chatRoomId,
    required String senderId,
    required String videoUrl,
    String message = '',
    DateTime? createdAtOverride,
  }) async {
    final createdAt =
    (createdAtOverride ?? DateTime.now().toUtc()).toIso8601String();

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

  /// Mark all CURRENTLY unread messages in a group as read for this user.
  ///
  /// Simplified semantics:
  /// - Only messages in this [chatRoomId]
  /// - Only messages not sent by [currentUserId]
  /// - Only rows where `is_read = false`
  ///
  /// This makes the unread badge on GroupsPage go back to 0
  /// the moment the user opens the group chat.
  Future<void> markGroupMessagesAsRead(
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
    } catch (e) {
      debugPrint('❌ markGroupMessagesAsRead error: $e');
    }
  }

  /// 🆕 Mark a video message as fully uploaded (remove uploading badge)
  Future<void> markVideoMessageUploaded(String messageId) async {
    await _supabase
        .from('messages')
        .update({'is_uploading': false})
        .eq('id', messageId);
  }

  // ---------------------------------------------------------------------------
  // 📋 GROUP LIST FOR CURRENT USER
  // ---------------------------------------------------------------------------

  /// Fetch all GROUP chat rooms where this user is a member.
  ///
  /// Uses:
  /// - chat_room_members (user_id, chat_room_id)
  /// - join to chat_rooms (is_group = true)
  ///
  /// Returns a list of simple maps:
  ///   {
  ///     'id': <room_id>,
  ///     'name': <group name or 'Group'>,
  ///     'avatar_url': <nullable>,
  ///     'created_at': <DateTime or String>,
  ///   }
  Future<List<Map<String, dynamic>>> fetchGroupRoomsForUser(
      String userId,
      ) async {
    final data = await _supabase
        .from('chat_room_members')
        .select(
      'chat_room_id, chat_rooms!inner (id, name, avatar_url, created_at, is_group)',
    )
        .eq('user_id', userId)
        .eq('chat_rooms.is_group', true)
        .order(
      'created_at',
      ascending: false,
      referencedTable: 'chat_rooms',
    );

    final List<Map<String, dynamic>> groups = [];

    for (final row in data) {
      final room = row['chat_rooms'];
      if (room == null) continue;

      final map = <String, dynamic>{
        'id': room['id'],
        'name': room['name'] ?? 'Group',
        'avatar_url': room['avatar_url'],
        'created_at': room['created_at'],
      };

      groups.add(map);
    }

    return groups;
  }

  /// Polling stream of group rooms for the current user.
  ///
  /// Very similar to your unread counts poller:
  ///   - immediately emits current list
  ///   - then refreshes every [interval]
  Stream<List<Map<String, dynamic>>> groupRoomsForUserPollingStream(
      String userId, {
        Duration interval = const Duration(seconds: 20),
      }) async* {
    // Initial value
    yield await fetchGroupRoomsForUser(userId);

    // Periodic updates
    yield* Stream.periodic(interval)
        .asyncMap((_) => fetchGroupRoomsForUser(userId));
  }

  // ---------------------------------------------------------------------------
  // 👥 GROUP MEMBERS
  // ---------------------------------------------------------------------------

  /// Fetch raw group member links (user_id + role) for a given chat room.
  ///
  /// We keep this low-level and let the UI fetch full profiles via DatabaseService.
  Future<List<Map<String, dynamic>>> fetchGroupMemberLinks(
      String chatRoomId,
      ) async {
    final data = await _supabase
        .from('chat_room_members')
        .select('user_id, role')
        .eq('chat_room_id', chatRoomId);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Remove the current user from a group chat via RPC.
  ///
  /// The RPC will also delete the room (and cascade-delete messages +
  /// memberships + typing_status rows) when the last member leaves.
  ///
  /// [userId] is kept for call-site compatibility, but the RPC reads auth.uid().
  Future<void> leaveGroup({
    required String chatRoomId,
    required String userId, // not used inside; kept for signature compatibility
  }) async {
    try {
      debugPrint('🚪 leaveGroup (RPC): user=$userId leaving room=$chatRoomId');

      // Call the Supabase RPC; user is taken from auth.uid() inside the function
      final result = await _supabase.rpc(
        'leave_group_and_cleanup',
        params: {
          'p_chat_room_id': chatRoomId,
        },
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

  /// Fetch last message per GROUP chat that this user can see.
  ///
  /// - We only consider group messages: receiver_id IS NULL (filter).
  /// - RLS on `messages` ensures we only see rooms where the user is a member.
  ///
  /// Returns a Map keyed by chatRoomId.
  Future<Map<String, MessageModel>> fetchLastGroupMessages() async {
    final data = await _supabase
        .from('messages')
        .select(
      'id, chat_room_id, sender_id, receiver_id, message, image_url, video_url, reply_to_message_id, created_at, is_read, is_delivered, liked_by',
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

  /// Polling stream for last group messages (similar to lastMessagesByFriend).
  ///
  /// You can tweak [interval] to match your DM polling setup.
  Stream<Map<String, MessageModel>> lastGroupMessagesPollingStream({
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      try {
        final data = await fetchLastGroupMessages();
        yield data;
      } catch (_) {
        // swallow errors so the stream keeps going
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Fetch unread counts per group chat for the current user.
  ///
  /// Logic:
  /// - only group messages: receiver_id IS NULL
  /// - only not read: is_read = false
  /// - only messages NOT sent by the current user
  ///
  /// Returns a Map<chatRoomId, unreadCount>.
  Future<Map<String, int>> fetchUnreadCountsByGroup(
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

  /// Polling stream for unread counts per group (similar to fetchUnreadCountsByFriend).
  Stream<Map<String, int>> groupUnreadCountsPollingStream(
      String currentUserId, {
        Duration interval = const Duration(seconds: 3),
      }) async* {
    while (true) {
      try {
        final data = await fetchUnreadCountsByGroup(currentUserId);
        debugPrint('📡 groupUnreadCountsPollingStream tick → $data');
        yield data;
      } catch (e) {
        debugPrint('❌ groupUnreadCountsPollingStream error: $e');
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Delete group as admin via RPC.
  ///
  /// RPC is responsible for:
  /// - deleting the chat_rooms row
  /// - cascading to messages, memberships, typing_status, etc.
  Future<void> deleteGroupAsAdmin({
    required String chatRoomId,
  }) async {
    try {
      debugPrint('🗑 deleteGroupAsAdmin: room=$chatRoomId');
      final result = await _supabase.rpc(
        'delete_group_as_admin',
        params: {
          'p_chat_room_id': chatRoomId,
        },
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

  Future<void> deleteMessageForEveryone({
    required String messageId,
    required String userId,
  }) async {
    // Only allow sender to delete
    await _supabase.from('messages').update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'message': '',
      'image_url': null,
      'video_url': null,
    }).match({
      'id': messageId,
      'sender_id': userId,
    });
  }
}
