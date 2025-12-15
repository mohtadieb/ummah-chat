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

  Future<void> markAsRead(int id) async {
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

  /// Create an in-app notification, optionally also send a push.
  /// ...
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

    // 2️⃣ Optionally send push to device
    if (sendPush) {
      await _sendPushToUserId(
        targetUserId: targetUserId,
        title: title,
        body: pushBody ?? body ?? '',
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
    final bodyCode = 'CHAT_MESSAGE:$senderId::$senderName';

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

    // Push shows only the nice preview text
    final pushText = truncatedPreview.isEmpty ? title : truncatedPreview;

    await _sendPushToUserId(
      targetUserId: targetUserId,
      title: title,
      body: pushText,
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

    // Example: "New message in Ummah Sisters" or "Ummah Sisters – Tas"
    final title = '$groupName – $senderName';

    // 👇 This is what NotificationPage parses:
    // GROUP_MESSAGE:<chatRoomId>::<groupName>
    final bodyCode = 'GROUP_MESSAGE:$chatRoomId::$groupName';

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

    final pushText =
    truncatedPreview.isEmpty ? 'New message in $groupName' : truncatedPreview;

    await _sendPushToUserId(
      targetUserId: targetUserId,
      title: groupName,
      body: pushText,
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
  // PUSH SENDER
  // -------------------------

  Future<void> _sendPushToUserId({
    required String targetUserId,
    required String title,
    String? body,
    Map<String, String>? data,
  }) async {
    // 1) Look up FCM token from profiles
    final profile = await _db
        .from('profiles')
        .select('fcm_token')
        .eq('id', targetUserId)
        .maybeSingle();

    final fcmToken = profile?['fcm_token'] as String?;
    debugPrint('🔎 Target profile for $targetUserId: $profile');

    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint('⚠️ No fcm_token stored on profile for user $targetUserId');
      return;
    }

    // 2) Decide what text the PUSH should show
    String pushBody;

    if (body == null || body.isEmpty) {
      pushBody = title;
    } else if (body.startsWith('FOLLOW_USER:')) {
      pushBody = title;
    } else if (body.startsWith('FRIEND_REQUEST:')) {
      pushBody = 'You received a new friend request.';
    } else if (body.startsWith('FRIEND_ACCEPTED:')) {
      pushBody = 'Your friend request was accepted.';
    } else if (body.startsWith('LIKE_POST:')) {
      final parts = body.split('::');
      final preview = parts.length == 2 ? parts[1].trim() : '';
      if (preview.isNotEmpty) {
        pushBody = '“$preview”';
      } else {
        pushBody = 'Someone liked your post.';
      }
    } else if (body.startsWith('COMMENT_POST:')) {
      final parts = body.split('::');
      final preview = parts.length == 2 ? parts[1].trim() : '';
      if (preview.isNotEmpty) {
        pushBody = '“$preview”';
      } else {
        pushBody = 'Someone commented on your post.';
      }
    } else {
      pushBody = body;
    }

    try {
      final response = await _db.functions.invoke(
        'send_push',
        body: {
          'fcm_token': fcmToken,
          'title': title,
          'body': pushBody,
          'data': data ?? {},
        },
      );

      debugPrint('✅ send_push response: ${response.data}');
    } catch (e) {
      debugPrint('❌ send_push error: $e');
    }
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
    await _db
        .from('notifications')
        .delete()
        .eq('user_id', userAId)
        .inFilter('body', [
      'FRIEND_REQUEST:$userBId',
      'FRIEND_ACCEPTED:$userBId',
      'FOLLOW_USER:$userBId',
    ]);

    // For userB, delete any notifications about userA
    await _db
        .from('notifications')
        .delete()
        .eq('user_id', userBId)
        .inFilter('body', [
      'FRIEND_REQUEST:$userAId',
      'FRIEND_ACCEPTED:$userAId',
      'FOLLOW_USER:$userAId',
    ]);
  }

// Future<void> sendTestPushToUser() async {
//   final user = _auth.currentUser;
//   if (user == null) {
//     debugPrint('⚠️ No logged-in user, cannot send test push.');
//     return;
//   }
//
//   await createNotificationForUser(
//     targetUserId: user.id,
//     title: 'Test from settings',
//     body: 'This is a test push from Settings page',
//     data: {'screen': 'notifications'},
//     sendPush: true,
//   );
// }
}
