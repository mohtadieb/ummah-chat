// lib/services/notifications/push_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

  /// ✅ Used to navigate from push callbacks
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  /// Call this once after app startup.
  static Future<void> initPushTapHandlers() async {
    // Terminated -> Opened by tapping notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📬 Opened from terminated via push: ${initialMessage.data}');
      _handleNotificationOpen(initialMessage);
    }

    // Background -> Opened by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('📬 Opened from background via push: ${message.data}');
      _handleNotificationOpen(message);
    });
  }

  static void _handleNotificationOpen(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString().trim();

    if (type.isEmpty) {
      debugPrint('⚠️ Push opened but no data.type found.');
      return;
    }

    // ✅ COMMENT_REPLY -> open post and scroll to that comment
    if (type == 'COMMENT_REPLY') {
      final postId = (data['postId'] ?? '').toString().trim();
      final commentId = (data['commentId'] ?? '').toString().trim();

      if (postId.isEmpty) {
        debugPrint('⚠️ COMMENT_REPLY push missing postId.');
        return;
      }

      navigatorKey.currentState?.pushNamed(
        '/post',
        arguments: {
          'postId': postId,
          'highlightCommentId': commentId,
        },
      );
      return;
    }

    // ✅ COMMENT_POST -> open post and scroll to comments
    if (type == 'COMMENT_POST') {
      final postId = (data['postId'] ?? '').toString().trim();
      if (postId.isEmpty) return;

      navigatorKey.currentState?.pushNamed(
        '/post',
        arguments: {
          'postId': postId,
          'highlightCommentId': '',
        },
      );
      return;
    }

    // ✅ LIKE_POST -> open post
    if (type == 'LIKE_POST') {
      final postId = (data['postId'] ?? '').toString().trim();
      if (postId.isEmpty) return;

      navigatorKey.currentState?.pushNamed(
        '/post',
        arguments: {'postId': postId},
      );
      return;
    }

    debugPrint('ℹ️ Unhandled push type: $type | data=$data');
  }

  /// Sync FCM token from device → Supabase DB
  static Future<void> syncFcmTokenWithSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No logged-in user, skip FCM token sync.');
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ No FCM token available.');
      return;
    }

    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);

      debugPrint('✅ Synced FCM token to Supabase for user ${user.id}');
    } catch (e) {
      debugPrint('❌ Failed to sync FCM token to Supabase: $e');
    }
  }

  /// Register listener for automatic token refresh
  static void registerTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('profiles')
          .update({'fcm_token': newToken})
          .eq('id', user.id);

      debugPrint('🔄 FCM token automatically refreshed & synced.');
    });
  }
}
