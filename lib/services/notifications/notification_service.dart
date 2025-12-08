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
      final unread = rows.where(
            (r) => r['is_read'] == false || r['is_read'] == 0,
      ).length;

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
      rows.sort((a, b) =>
          DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

      return rows.map((data) => models.Notification.fromMap(data)).toList();
    });
  }

  // -------------------------
  // MUTATIONS
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

  /// Create an in-app notification, optionally also send a push
  Future<void> createNotificationForUser({
    required String targetUserId,
    required String title,
    String? body,
    Map<String, String>? data,
    bool sendPush = true,
  }) async {
    // 1) Store notification in DB (for in-app bell list)
    await _db.from('notifications').insert({
      'user_id': targetUserId,
      'title': title,
      'body': body,
    });

    // 2) Optionally send push to device
    if (sendPush) {
      await _sendPushToUserId(
        targetUserId: targetUserId,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  /// 🔔 Internal helper: look up user's FCM token and call Edge Function
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
    //
    // We keep the original `body` in the DB (for app logic),
    // but for the push notification we want something human-readable.
    String pushBody;

    if (body == null || body.isEmpty) {
      // If nothing special, just reuse the title
      pushBody = title;
    } else if (body.startsWith('FOLLOW_USER:')) {
      // e.g. "Someone started following you"
      pushBody = title; // title already is "X started following you"
    } else if (body.startsWith('FRIEND_REQUEST:')) {
      pushBody = 'You received a new friend request.';
    } else if (body.startsWith('FRIEND_ACCEPTED:')) {
      pushBody = 'Your friend request was accepted.';
    } else if (body.startsWith('LIKE_POST:')) {
      // Format: LIKE_POST:<postId>::<preview>
      final parts = body.split('::');
      final preview = parts.length == 2 ? parts[1].trim() : '';
      if (preview.isNotEmpty) {
        pushBody = '“$preview”';
      } else {
        pushBody = 'Someone liked your post.';
      }
    } else if (body.startsWith('COMMENT_POST:')) {
      // Format: COMMENT_POST:<postId>::<preview>
      final parts = body.split('::');
      final preview = parts.length == 2 ? parts[1].trim() : '';
      if (preview.isNotEmpty) {
        pushBody = '“$preview”';
      } else {
        pushBody = 'Someone commented on your post.';
      }
    } else {
      // Fallback: use the existing body as-is
      pushBody = body;
    }

    try {
      // 3) Call your send_push Edge Function with the CLEAN pushBody
      final response = await _db.functions.invoke(
        'send_push',
        body: {
          'fcm_token': fcmToken,
          'title': title,
          'body': pushBody, // 👈 use the nice text here
          'data': data ?? {},
        },
      );

      debugPrint('✅ send_push response: ${response.data}');
    } catch (e) {
      debugPrint('❌ send_push error: $e');
    }
  }


  // 🔻 delete friend-request notification when cancelled
  Future<void> deleteFriendRequestNotification({
    required String targetUserId, // the person who received the request
    required String requesterId,  // the person who sent/cancels it
  }) async {
    if (targetUserId.isEmpty || requesterId.isEmpty) return;

    await _db
        .from('notifications')
        .delete()
        .eq('user_id', targetUserId)
        .eq('body', 'FRIEND_REQUEST:$requesterId');
  }

  // 🔻 delete follow notification when unfollowing
  Future<void> deleteFollowNotification({
    required String targetUserId, // the person who was followed
    required String followerId,   // the one who is unfollowing
  }) async {
    if (targetUserId.isEmpty || followerId.isEmpty) return;

    await _db
        .from('notifications')
        .delete()
        .eq('user_id', targetUserId)
        .eq('body', 'FOLLOW_USER:$followerId');
  }

  /// Delete all relationship-related notifications between two users.
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

  /// 🧪 Dev-only helper: send a test push to the *current* logged-in user
  /// (also creates an in-app notification)
  Future<void> sendTestPushToUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No logged-in user, cannot send test push.');
      return;
    }

    await createNotificationForUser(
      targetUserId: user.id,
      title: 'Test from settings',
      body: 'This is a test push from Settings page',
      data: {'screen': 'notifications'},
      sendPush: true,
    );
  }
}
