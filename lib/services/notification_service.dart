// lib/services/notification/notification_service.dart

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

  Future<void> createNotificationForUser({
    required String targetUserId,
    required String title,
    String? body,
  }) async {
    await _db.from('notifications').insert({
      'user_id': targetUserId,
      'title': title,
      'body': body,
    });
  }
}
