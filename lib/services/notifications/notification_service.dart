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
    // React to auth changes, so cold-start from push works
    return _auth.onAuthStateChange.asyncExpand((_) {
      final userId = _currentUserId;
      if (userId.isEmpty) return Stream.value(0);

      return _db
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .map((rows) {
        final unread = rows.where((r) {
          final isUnread = r['is_read'] == false || r['is_read'] == 0;
          return isUnread;
        }).length;

        debugPrint('🔔 unreadCountStream rows=${rows.length}, unread=$unread');
        return unread;
      });
    }).distinct();
  }



  /// 📄 Full notifications list
  Stream<List<models.Notification>> notificationsStream() {
    return _auth.onAuthStateChange.asyncExpand((_) {
      final userId = _currentUserId;
      if (userId.isEmpty) return Stream.value([]);

      return _db
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .map((rows) {
        final sorted = [...rows];
        sorted.sort((a, b) => DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at'])));

        return sorted.map((data) => models.Notification.fromMap(data)).toList();
      });
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

    // ✅ NEW (so RLS can allow sender delete)
    String? fromUserId,
    String? type,
    String? chatRoomId,
    int? unreadCount,
    bool? isRead,

    Map<String, String>? pushArgs,
  }) async {
    // 1️⃣ Store notification in DB (for in-app list)
    final insertMap = <String, dynamic>{
      'user_id': targetUserId,
      'title': title,
      'body': body,
    };

    if (fromUserId != null && fromUserId.trim().isNotEmpty) {
      insertMap['from_user_id'] = fromUserId.trim();
    }
    if (type != null && type.trim().isNotEmpty) {
      insertMap['type'] = type.trim();
    }
    if (chatRoomId != null && chatRoomId.trim().isNotEmpty) {
      insertMap['chat_room_id'] = chatRoomId.trim();
    }
    if (unreadCount != null) insertMap['unread_count'] = unreadCount;
    if (isRead != null) insertMap['is_read'] = isRead;

    await _db.from('notifications').insert(insertMap);

    // 2️⃣ Optionally send push
    if (sendPush) {
      final inferredType = _inferNotifType(body: body, data: data);
      final preview = (pushBody ?? _extractPreviewFromBody(body) ?? '').trim();

      await _sendLocalizedPushToUserId(
        targetUserId: targetUserId,
        notifType: inferredType,
        args: {
          'senderName': (data?['senderName'] ?? '').trim(),
          'groupName': (data?['groupName'] ?? '').trim(),
          'preview': preview,

          // ✅ NEW: allow custom args like { "name": "..." }
          ...?pushArgs,
        },
        // ✅ your _sendLocalizedPushToUserId likely expects Map<String,String>,
        // so make sure it's never null
        data: data ?? const {},
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
    if (chatRoomId.isEmpty) return;
    if (senderId.isEmpty) return;

    final trimmed = messagePreview.trim();
    final truncatedPreview = trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;

    final title = '$senderName sent you a message';

    // NotificationPage expects: CHAT_MESSAGE:<senderId>::<senderName>
    final bodyCode = 'CHAT_MESSAGE:$senderId::$senderName';

    bool shouldSendPush = false;

    try {
      final res = await _db.rpc(
        'upsert_room_chat_notification_checked',
        params: {
          'p_user_id': targetUserId,
          'p_chat_room_id': chatRoomId,
          'p_from_user_id': senderId,
          'p_title': title,
          'p_body': bodyCode,
        },
      );

      shouldSendPush = (res is bool) ? res : (res == true);
    } catch (e, st) {
      debugPrint('❌ upsert_room_chat_notification_checked failed (DM): $e\n$st');
      return;
    }

    // If receiver is active, DB returned false -> no DB notif + no push
    if (!shouldSendPush) {
      debugPrint('ℹ️ Skipped DM notif+push: receiver active in $chatRoomId');
      return;
    }

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
    if (chatRoomId.isEmpty) return;
    if (senderId.isEmpty) return;

    final trimmed = messagePreview.trim();
    final truncatedPreview = trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;

    final title = '$groupName – $senderName';

    // NotificationPage expects: GROUP_MESSAGE:<chatRoomId>::<groupName>
    final bodyCode = 'GROUP_MESSAGE:$chatRoomId::$groupName';

    bool shouldSendPush = false;

    try {
      final res = await _db.rpc(
        'upsert_room_chat_notification_checked',
        params: {
          'p_user_id': targetUserId,
          'p_chat_room_id': chatRoomId,
          'p_from_user_id': senderId, // store last sender
          'p_title': title,
          'p_body': bodyCode,
        },
      );

      shouldSendPush = (res is bool) ? res : (res == true);
    } catch (e, st) {
      debugPrint('❌ upsert_room_chat_notification_checked failed (GROUP): $e\n$st');
      return;
    }

    if (!shouldSendPush) {
      debugPrint('ℹ️ Skipped GROUP notif+push: receiver active in $chatRoomId');
      return;
    }

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
    final bodyCode = 'GROUP_ADDED:$chatRoomId::$groupName::$addedByName';

    // Stored in DB as readable fallback
    final title = '$addedByName added you to $groupName';

    // Store as a normal in-app notification (NOT type=chat)
    await _db.from('notifications').upsert(
      {
        'user_id': targetUserId,
        'title': title,
        'body': bodyCode,
        'type': 'group',
        'chat_room_id': chatRoomId,
        'from_user_id': addedByUserId,
        'unread_count': 1,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,chat_room_id,body',
    );


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

  // -----------------------------
  // MUTATIONS – COMMUNITY INVITE
  // -----------------------------

  Future<void> createCommunityInviteNotification({
    required String targetUserId,
    required String communityId,
    required String communityName,
    required String inviterId,
    required String inviterName,
  }) async {
    if (targetUserId.trim().isEmpty || communityId.trim().isEmpty) return;
    if (targetUserId == inviterId) return;

    final safeName = communityName.replaceAll('::', ' ').trim();

    await createNotificationForUser(
      targetUserId: targetUserId,

      // ✅ Uniform fallback title (human readable)
      title: '$inviterName invited you to $safeName',

      // ✅ Uniform body format (ID at the end)
      body: 'COMMUNITY_INVITE:$communityId::$safeName::$inviterId',

      fromUserId: inviterId,
      type: 'community',
      isRead: false,
      unreadCount: 1,
      sendPush: true,
      pushArgs: {
        'name': safeName,
        'senderName': inviterName,
      },
      data: {
        'type': 'COMMUNITY_INVITE',
        'communityId': communityId,
        'communityName': safeName,
        'fromUserId': inviterId,
        'senderName': inviterName,
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

    // Clean args: remove empty values
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
          'notif_type': notifType.trim(),
          'args': cleanArgs,
          'data': data ?? <String, String>{},
        },
      );

      debugPrint('✅ send_push response: ${response.data}');
    } on FunctionException catch (e, st) {
      // ✅ If function returns our "skipped" payload or old 400 message, treat as normal.
      final details = e.details?.toString() ?? '';

      // Old behavior (400)
      final isMissingToken400 =
          e.status == 400 && details.contains('Missing fcm_token');

      if (isMissingToken400) {
        debugPrint('ℹ️ send_push skipped (no token for $targetUserId)');
        return;
      }

      debugPrint('❌ send_push FunctionException: $e\n$st');
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
    if (b.startsWith('MAHRAM_REQUEST:')) return 'MAHRAM_REQUEST';
    if (b.startsWith('MAHRAM_ACCEPTED:')) return 'MAHRAM_ACCEPTED';
    if (b.startsWith('COMMUNITY_INVITE:')) return 'COMMUNITY_INVITE';
    if (b.startsWith('LIKE_POST:')) return 'LIKE_POST';
    if (b.startsWith('COMMENT_POST:')) return 'COMMENT_POST';
    if (b.startsWith('COMMENT_REPLY:')) return 'COMMENT_REPLY'; // ✅ NEW
    if (b.startsWith('CHAT_MESSAGE:')) return 'CHAT_MESSAGE';
    if (b.startsWith('GROUP_MESSAGE:')) return 'GROUP_MESSAGE';
    if (b.startsWith('GROUP_ADDED:')) return 'GROUP_ADDED';
    if (b.startsWith('MARRIAGE_INQUIRY_REQUEST:')) return 'MARRIAGE_INQUIRY_REQUEST';
    if (b.startsWith('MARRIAGE_INQUIRY_MAHRAM:')) return 'MARRIAGE_INQUIRY_MAHRAM';
    if (b.startsWith('MARRIAGE_INQUIRY_MAN_DECISION:')) return 'MARRIAGE_INQUIRY_MAN_DECISION';
    if (b.startsWith('MARRIAGE_INQUIRY_GROUP_CREATED:')) return 'MARRIAGE_INQUIRY_GROUP_CREATED';
    if (b.startsWith('MARRIAGE_INQUIRY_MAHRAM_ACCEPTED:')) {
      return 'MARRIAGE_INQUIRY_MAHRAM_ACCEPTED';
    }



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

    // Minimal + robust: same style as your old working flow
    await _db
        .from('notifications')
        .delete()
        .eq('user_id', targetUserId)
        .eq('body', 'FRIEND_REQUEST:$requesterId');
  }

  Future<void> deleteMahramRequestNotification({
    required String targetUserId,
    required String requesterId,
  }) async {
    if (targetUserId.isEmpty || requesterId.isEmpty) return;

    await _db
        .from('notifications')
        .delete()
        .eq('user_id', targetUserId)
        .eq('body', 'MAHRAM_REQUEST:$requesterId');
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
        .eq('type', 'social')
        .eq('from_user_id', followerId)
        .like('body', 'FOLLOW_USER:%');
  }

  Future<void> deleteMarriageInquiryNotifications(String inquiryId) async {
    final id = inquiryId.trim();
    if (id.isEmpty) return;

    // ✅ Delete directly; let DELETE RLS filter what’s allowed.
    await _db
        .from('notifications')
        .delete()
        .ilike('body', 'MARRIAGE_INQUIRY_%:$id%');
  }

  // Future<void> deleteCommunityInviteNotification({
  //   required String targetUserId,
  //   required String communityId,
  // }) async {
  //   if (targetUserId.isEmpty || communityId.isEmpty) return;
  //
  //   await _db
  //       .from('notifications')
  //       .delete()
  //       .eq('user_id', targetUserId)
  //       .eq('body', 'COMMUNITY_INVITE:$communityId');
  // }




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
