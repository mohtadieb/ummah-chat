import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_service.dart';

/// ChatProvider
///
/// - Keeps messages in memory per chat room (DM + group)
/// - Listens to realtime changes (INSERT + UPDATE) from Supabase
/// - Exposes a simple `getMessages(roomId)` API used by:
///     - ChatPage (DM)
///     - GroupChatPage
///
/// Messages are stored as raw maps; the UI converts them to MessageModel.
class ChatProvider with ChangeNotifier {
  // Store messages per room as raw maps from Supabase
  final Map<String, List<Map<String, dynamic>>> _messagesByRoom = {};

  // Store realtime subscriptions per room
  final Map<String, StreamSubscription<Map<String, dynamic>>> _subscriptions =
  {};

  // Backend / Supabase helper
  final ChatService _chatService = ChatService();

  /// Public getter used by ChatPage / GroupChatPage:
  /// returns the list of raw message maps for a given room.
  List<Map<String, dynamic>> getMessages(String roomId) {
    return _messagesByRoom[roomId] ?? const [];
  }

  /// Fetch existing messages + subscribe to realtime updates (insert + update)
  ///
  /// - Cancels any previous subscription for this room
  /// - Loads all past messages from Supabase
  /// - Subscribes to ChatService.streamMessages(roomId)
  /// - For each incoming payload:
  ///   - if new → append
  ///   - if existing → replace
  ///   - then sort by created_at ascending and notifyListeners()
  Future<void> listenToRoom(String roomId) async {
    // Avoid double listeners: cancel previous sub if any
    await _subscriptions[roomId]?.cancel();
    _subscriptions.remove(roomId);

    // 1️⃣ Fetch old messages ONCE
    final pastMessages = await _chatService.fetchMessages(roomId);

    _messagesByRoom[roomId] = List<Map<String, dynamic>>.from(pastMessages);
    _sortMessages(roomId);
    notifyListeners();

    // 2️⃣ Listen to realtime changes (insert + update)
    final stream = _chatService.streamMessages(roomId);

    final sub = stream.listen((payload) {
      final current = _messagesByRoom[roomId] ?? <Map<String, dynamic>>[];

      final dynamic id = payload['id'];
      final int existingIndex = current.indexWhere((m) => m['id'] == id);

      if (existingIndex == -1) {
        // New message (INSERT)
        current.add(payload);
      } else {
        // Updated message (UPDATE, e.g. is_read / liked_by / image_url / video_url changed)
        current[existingIndex] = payload;
      }

      _messagesByRoom[roomId] = current;
      _sortMessages(roomId);
      notifyListeners();
    });

    _subscriptions[roomId] = sub;
  }

  /// Helper to keep messages sorted by created_at ascending.
  /// (ChatPage / GroupChatPage use reverse: true so newest appears at the bottom.)
  void _sortMessages(String roomId) {
    final msgs = _messagesByRoom[roomId];
    if (msgs == null) return;

    msgs.sort((a, b) {
      final aTs = a['created_at']?.toString() ?? '';
      final bTs = b['created_at']?.toString() ?? '';
      return aTs.compareTo(bTs);
    });
  }

  /// Send a 1-on-1 text message via ChatService
  Future<void> sendMessage(
      String roomId,
      String senderId,
      String receiverId,
      String text,
      ) async {
    await _chatService.sendMessage(roomId, senderId, receiverId, text);
  }

  /// Send a GROUP text message via ChatService
  ///
  /// - `roomId` is the group chat_room_id
  /// - `senderId` is the current user
  /// - `text` is the content
  Future<void> sendGroupMessage(
      String roomId,
      String senderId,
      String text,
      ) async {
    await _chatService.sendGroupMessage(roomId, senderId, text);
  }

  @override
  void dispose() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
