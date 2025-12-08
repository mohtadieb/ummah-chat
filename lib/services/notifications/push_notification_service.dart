// lib/services/notifications/push_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

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
