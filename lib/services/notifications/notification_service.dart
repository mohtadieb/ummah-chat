// lib/services/notifications/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ummah_chat/models/notification.dart' as models;

class NotificationService {
  // -------------------------
  // 🔥 SINGLETON IMPLEMENTATION
  // -------------------------
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // -------------------------
  // Dependencies
  // -------------------------
  final _db = Supabase.instance.client;
  final _auth = Supabase.instance.client.auth;

  String get _currentUserId => _auth.currentUser?.id ?? '';

  // -------------------------
  // ACTIVE CHAT ROOM (UI-ONLY)
  // -------------------------

  /// Currently open chat room id (DM or group)
  String? _activeChatRoomId;

  /// 🆕 Currently open DM friend (for the FriendsPage unread dot)
  String? _activeDmFriendId;

  void setActiveChatRoomId(String? chatRoomId) {
    _activeChatRoomId = chatRoomId;
    debugPrint('🔔 NotificationService activeChatRoomId=$_activeChatRoomId');
  }

  /// 🆕 Set the active DM friend id (only used for DM list unread badge)
  void setActiveDmFriendId(String? friendId) {
    _activeDmFriendId = friendId;
    debugPrint('🔔 NotificationService activeDmFriendId=$_activeDmFriendId');
  }

  /// 🆕 Expose read-only getters for UI
  String? get activeChatRoomId => _activeChatRoomId;
  String? get activeDmFriendId => _activeDmFriendId;

  // -------------------------
  // STREAMS
  // -------------------------

  /// 🔔 Unread count stream for bell badge
  Stream<int> unreadCountStream() {
    final userId = _currentUserId;
    if (userId.isEmpty) return Stream.value(0);

    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
      final unread = rows.where((r) {
        final isUnread = r['is_read'] == false || r['is_read'] == 0;
        if (!isUnread) return false;

        // 🆕 If user is currently viewing this chat (DM or group),
        // hide its chat notifications from the bell badge
        if (_activeChatRoomId != null &&
            _activeChatRoomId!.isNotEmpty &&
            (r['type'] == 'chat') &&
            r['chat_room_id'] == _activeChatRoomId) {
          return false;
        }

        return true;
      }).length;

      debugPrint('🔔 unreadCountStream rows=${rows.length}, unread=$unread');
      return unread;
    });
  }

  /// 📄 Full notifications list
  Stream<List<models.Notification>> notificationsStream() {
    if (_currentUserId.isEmpty) return Stream.value([]);

    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _currentUserId)
        .map((rows) {
      // 🆕 Filter out chat notifications for the currently open chat
      final filtered = rows.where((r) {
        if (_activeChatRoomId != null &&
            _activeChatRoomId!.isNotEmpty &&
            (r['type'] == 'chat') &&
            r['chat_room_id'] == _activeChatRoomId) {
          return false;
        }
        return true;
      }).toList();

      filtered.sort(
            (a, b) => DateTime.parse(b['created_at']).compareTo(
          DateTime.parse(a['created_at']),
        ),
      );

      return filtered
          .map((data) => models.Notification.fromMap(data))
          .toList();
    });
  }

  // -------------------------
  // MUTATIONS – GENERIC
  // -------------------------

  Future<void> markAsRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    if (_currentUserId.isEmpty) return;
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _currentUserId)
        .eq('is_read', false);
  }

  /// Create an in-app notification, optionally also send a localized push.
  ///
  /// ✅ Keeps your DB `body` formats as-is (NotificationPage parsing unchanged).
  /// ✅ Push localization is handled in the Edge Function via:
  ///     target_user_id + notif_type + args
  Future<void> createNotificationForUser({
    required String targetUserId,
    required String title,
    String? body,
    Map<String, String>? data,
    bool sendPush = true,
    String? pushBody,
  }) async {
    // 1️⃣ Store notification in DB (for in-app list)
    await _db.from('notifications').insert({
      'user_id': targetUserId,
      'title': title,
      'body': body,
    });

    // 2️⃣ Optionally send push to device (localized by Edge Function)
    if (sendPush) {
      // We try to infer the notif type from the stored body OR from data['type']
      final inferredType = _inferNotifType(
        body: body,
        data: data,
      );

      final preview = (pushBody ?? _extractPreviewFromBody(body) ?? '').trim();

      await _sendLocalizedPushToUserId(
        targetUserId: targetUserId,
        notifType: inferredType,
        args: {
          'senderName': (data?['senderName'] ?? '').trim(),
          'groupName': (data?['groupName'] ?? '').trim(),
          'preview': preview,
        },
        data: data,
      );
    }
  }

  // -------------------------
  // MUTATIONS – CHAT-SPECIFIC (DM)
  // -------------------------

  Future<void> createOrUpdateChatNotification({
    required String targetUserId,
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String messagePreview,
  }) async {
    if (targetUserId.isEmpty) return;

    // 🆕 0) Check presence: if user is already in this chat, DO NOT notify
    try {
      final presence = await _db
          .from('user_chat_presence')
          .select('active_chat_room_id')
          .eq('user_id', targetUserId)
          .maybeSingle();

      final String? activeRoomId =
      presence == null ? null : presence['active_chat_room_id'] as String?;

      if (activeRoomId != null && activeRoomId == chatRoomId) {
        debugPrint(
          'ℹ️ Skipping chat notification: user $targetUserId is currently in $chatRoomId',
        );
        return;
      }
    } catch (e) {
      // Fail CLOSED: if we can't confirm presence, don't send a notification
      debugPrint(
        '⚠️ Presence lookup failed in createOrUpdateChatNotification, skipping notification: $e',
      );
      return;
    }

    final trimmed = messagePreview.trim();
    final truncatedPreview =
    trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;

    final title = '$senderName sent you a message';

    // ✅ IMPORTANT: use :: delimiter because NotificationPage splits by '::'
    final bodyCode = 'CHAT_MESSAGE:$senderId::${senderName}';

    // 1️⃣ See if there is already an unread chat notification for this room
    final existingRows = await _db
        .from('notifications')
        .select('id, unread_count')
        .eq('user_id', targetUserId)
        .eq('type', 'chat')
        .eq('chat_room_id', chatRoomId)
        .eq('is_read', false)
        .order('created_at', ascending: false); // newest first

    if (existingRows.isNotEmpty) {
      // 🔄 Update the newest existing notification, don't send another push
      final existing = existingRows.first;
      final id = existing['id'] as int;
      final currentCount = (existing['unread_count'] as int?) ?? 1;

      await _db.from('notifications').update({
        'title': title,
        'body': bodyCode,
        'unread_count': currentCount + 1,
        'from_user_id': senderId,
      }).eq('id', id);

      return;
    }

    // 2️⃣ No unread chat notification yet → create one & send push
    await _db.from('notifications').insert({
      'user_id': targetUserId,
      'title': title,
      'body': bodyCode,
      'type': 'chat',
      'chat_room_id': chatRoomId,
      'from_user_id': senderId,
      'unread_count': 1,
    });

    // Push uses preview if available
    final pushPreview = truncatedPreview.isEmpty ? '' : truncatedPreview;

    await _sendLocalizedPushToUserId(
      targetUserId: targetUserId,
      notifType: 'CHAT_MESSAGE',
      args: {
        'senderName': senderName,
        'preview': pushPreview,
      },
      data: {
        'type': 'CHAT_MESSAGE',
        'chatId': chatRoomId,
        'fromUserId': senderId,
        'senderName': senderName,
      },
    );
  }

  // -------------------------
  // MUTATIONS – GROUP CHAT-SPECIFIC
  // -------------------------

  Future<void> createOrUpdateGroupChatNotification({
    required String targetUserId,
    required String chatRoomId,
    required String groupName,
    required String senderId,
    required String senderName,
    required String messagePreview,
  }) async {
    if (targetUserId.isEmpty) return;

    // 0️⃣ Presence check: if user is already in this group chat, skip notification
    try {
      final presence = await _db
          .from('user_chat_presence')
          .select('active_chat_room_id')
          .eq('user_id', targetUserId)
          .maybeSingle();

      final String? activeRoomId =
      presence == null ? null : presence['active_chat_room_id'] as String?;

      if (activeRoomId != null && activeRoomId == chatRoomId) {
        debugPrint(
          'ℹ️ Skipping group chat notification: user $targetUserId is currently in $chatRoomId',
        );
        return;
      }
    } catch (e) {
      debugPrint(
        '⚠️ Presence lookup failed in createOrUpdateGroupChatNotification, skipping notification: $e',
      );
      return;
    }

    final trimmed = messagePreview.trim();
    final truncatedPreview =
    trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;

    // Example: "Ummah Sisters – Tas"
    final title = '$groupName – $senderName';

    // 👇 This is what NotificationPage parses:
    // GROUP_MESSAGE:<chatRoomId>::<groupName>
    // ✅ IMPORTANT: use :: delimiter
    final bodyCode = 'GROUP_MESSAGE:$chatRoomId::${groupName}';

    // 1️⃣ See if there is already an unread chat notification for this group room
    final existingRows = await _db
        .from('notifications')
        .select('id, unread_count')
        .eq('user_id', targetUserId)
        .eq('type', 'chat')
        .eq('chat_room_id', chatRoomId)
        .eq('is_read', false)
        .order('created_at', ascending: false);

    if (existingRows.isNotEmpty) {
      final existing = existingRows.first;
      final id = existing['id'] as int;
      final currentCount = (existing['unread_count'] as int?) ?? 1;

      await _db.from('notifications').update({
        'title': title,
        'body': bodyCode,
        'unread_count': currentCount + 1,
        'from_user_id': senderId,
      }).eq('id', id);

      return;
    }

    // 2️⃣ No unread group notification yet → create one & send push
    await _db.from('notifications').insert({
      'user_id': targetUserId,
      'title': title,
      'body': bodyCode,
      'type': 'chat',
      'chat_room_id': chatRoomId,
      'from_user_id': senderId,
      'unread_count': 1,
    });

    final pushPreview = truncatedPreview.isEmpty ? '' : truncatedPreview;

    await _sendLocalizedPushToUserId(
      targetUserId: targetUserId,
      notifType: 'GROUP_MESSAGE',
      args: {
        'senderName': senderName,
        'groupName': groupName,
        'preview': pushPreview,
      },
      data: {
        'type': 'GROUP_MESSAGE',
        'chatId': chatRoomId,
        'groupName': groupName,
        'fromUserId': senderId,
        'senderName': senderName,
      },
    );
  }

  Future<void> markChatNotificationsAsRead({
    required String chatRoomId,
    required String userId,
  }) async {
    if (userId.isEmpty) return;

    await _db
        .from('notifications')
        .update({
      'is_read': true,
      'unread_count': 0,
    })
        .eq('user_id', userId)
        .eq('type', 'chat')
        .eq('chat_room_id', chatRoomId)
        .eq('is_read', false);
  }

  // -------------------------
  // MUTATIONS – GROUP ADDED
  // -------------------------

  Future<void> createGroupAddedNotification({
    required String targetUserId,
    required String chatRoomId,
    required String groupName,
    required String addedByUserId,
    required String addedByName,
  }) async {
    if (targetUserId.isEmpty) return;
    if (chatRoomId.isEmpty) return;

    // Don’t notify yourself
    if (targetUserId == addedByUserId) return;

    // Body format NotificationPage can parse:
    // GROUP_ADDED:<chatRoomId>::<groupName>::<addedByName>
    // ✅ IMPORTANT: use :: delimiter
    final bodyCode = 'GROUP_ADDED:$chatRoomId::${groupName}::${addedByName}';

    // Stored in DB as readable fallback
    final title = '$addedByName added you to $groupName';

    // Store as a normal in-app notification (NOT type=chat)
    await _db.from('notifications').insert({
      'user_id': targetUserId,
      'title': title,
      'body': bodyCode,
      'type': 'group', // 👈 important so it won’t be filtered as "active chat"
      'chat_room_id': chatRoomId,
      'from_user_id': addedByUserId,
      'unread_count': 1,
      'is_read': false,
    });

    // Localized push (Edge uses receiver locale)
    await _sendLocalizedPushToUserId(
      targetUserId: targetUserId,
      notifType: 'GROUP_ADDED',
      args: {
        'senderName': addedByName,
        'groupName': groupName,
        'preview': '',
      },
      data: {
        'type': 'GROUP_ADDED',
        'chatId': chatRoomId,
        'groupName': groupName,
        'fromUserId': addedByUserId,
        'senderName': addedByName,
      },
    );
  }

  // -------------------------
  // PUSH SENDER (NEW MODE)
  // -------------------------

  Future<void> _sendLocalizedPushToUserId({
    required String targetUserId,
    required String notifType,
    required Map<String, String> args,
    Map<String, String>? data,
  }) async {
    if (targetUserId.isEmpty) return;
    if (notifType.trim().isEmpty) return;

    // Clean args: remove empty keys
    final cleanArgs = <String, String>{};
    args.forEach((k, v) {
      final vv = v.trim();
      if (vv.isNotEmpty) cleanArgs[k] = vv;
    });

    try {
      final response = await _db.functions.invoke(
        'send_push',
        body: {
          'target_user_id': targetUserId,
          'notif_type': notifType,
          'args': cleanArgs,
          'data': data ?? <String, String>{},
        },
      );

      debugPrint('✅ send_push response: ${response.data}');
    } catch (e, st) {
      debugPrint('❌ send_push error: $e\n$st');
    }
  }

  // -------------------------
  // Helpers: infer type + preview from your existing DB body formats
  // -------------------------

  String _inferNotifType({
    String? body,
    Map<String, String>? data,
  }) {
    final t = (data?['type'] ?? '').trim();
    if (t.isNotEmpty) return t;

    final b = (body ?? '').trim();
    if (b.startsWith('FOLLOW_USER:')) return 'FOLLOW_USER';
    if (b.startsWith('FRIEND_REQUEST:')) return 'FRIEND_REQUEST';
    if (b.startsWith('FRIEND_ACCEPTED:')) return 'FRIEND_ACCEPTED';
    if (b.startsWith('LIKE_POST:')) return 'LIKE_POST';
    if (b.startsWith('COMMENT_POST:')) return 'COMMENT_POST';
    if (b.startsWith('COMMENT_REPLY:')) return 'COMMENT_REPLY'; // ✅ NEW
    if (b.startsWith('CHAT_MESSAGE:')) return 'CHAT_MESSAGE';
    if (b.startsWith('GROUP_MESSAGE:')) return 'GROUP_MESSAGE';
    if (b.startsWith('GROUP_ADDED:')) return 'GROUP_ADDED';

    // safe fallback
    return 'FOLLOW_USER';
  }

  /// Extract preview from DB body formats that embed "::<preview>"
  /// Examples:
  /// - LIKE_POST:<postId>::<preview>
  /// - COMMENT_POST:<postId>::<preview>
  /// - COMMENT_REPLY:<postId>::<commentId>::<preview>
  String? _extractPreviewFromBody(String? body) {
    final b = (body ?? '').trim();
    if (b.isEmpty) return null;

    if (b.startsWith('LIKE_POST:') || b.startsWith('COMMENT_POST:')) {
      final parts = b.split('::');
      // expected: [LIKE_POST:<id>, <preview>]
      if (parts.length >= 2) return parts[1].trim();
    }

    if (b.startsWith('COMMENT_REPLY:')) {
      final parts = b.split('::');
      // expected: [COMMENT_REPLY:<postId>, <commentId>, <preview>]
      if (parts.length >= 3) return parts[2].trim();
    }

    return null;
  }

  // -------------------------
  // RELATIONSHIP HELPERS
  // -------------------------

  Future<void> deleteFriendRequestNotification({
    required String targetUserId,
    required String requesterId,
  }) async {
    if (targetUserId.isEmpty || requesterId.isEmpty) return;

    await _db
        .from('notifications')
        .delete()
        .eq('user_id', targetUserId)
        .eq('body', 'FRIEND_REQUEST:$requesterId');
  }

  Future<void> deleteFollowNotification({
    required String targetUserId,
    required String followerId,
  }) async {
    if (targetUserId.isEmpty || followerId.isEmpty) return;

    await _db
        .from('notifications')
        .delete()
        .eq('user_id', targetUserId)
        .eq('body', 'FOLLOW_USER:$followerId');
  }

  Future<void> deleteAllRelationshipNotificationsBetween({
    required String userAId,
    required String userBId,
  }) async {
    if (userAId.isEmpty || userBId.isEmpty) return;

    // For userA, delete any notifications about userB
    await _db.from('notifications').delete().eq('user_id', userAId).inFilter(
      'body',
      [
        'FRIEND_REQUEST:$userBId',
        'FRIEND_ACCEPTED:$userBId',
        'FOLLOW_USER:$userBId',
      ],
    );

    // For userB, delete any notifications about userA
    await _db.from('notifications').delete().eq('user_id', userBId).inFilter(
      'body',
      [
        'FRIEND_REQUEST:$userAId',
        'FRIEND_ACCEPTED:$userAId',
        'FOLLOW_USER:$userAId',
      ],
    );
  }
}
