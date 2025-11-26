// lib/helper/message_grouping.dart
import '../models/message.dart';

/// Public helper to group multiple DB rows into one logical bubble.
/// Used by both ChatPage (DM) and GroupChatPage.
class MessageGroup {
  final List<MessageModel> messages;
  final int firstIndex;

  MessageGroup({required this.messages, required this.firstIndex});

  MessageModel get first => messages.first;
  MessageModel get last => messages.last;
}

class MessageGrouping {
  /// Groups messages that share:
  /// - same sender
  /// - same text caption
  /// - same createdAt
  /// - and both have media (image or video)
  static List<MessageGroup> build(List<MessageModel> messages) {
    final List<MessageGroup> groups = [];
    if (messages.isEmpty) return groups;

    MessageGroup? currentGroup;

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      if (currentGroup == null) {
        currentGroup = MessageGroup(messages: [msg], firstIndex: i);
        groups.add(currentGroup);
        continue;
      }

      final base = currentGroup.messages.first;

      final sameSender = msg.senderId == base.senderId;
      final sameCaption = msg.message == base.message;
      final sameCreatedAt = msg.createdAt.isAtSameMomentAs(base.createdAt);

      final baseHasMedia =
          (base.imageUrl?.trim().isNotEmpty ?? false) ||
              (base.videoUrl?.trim().isNotEmpty ?? false);
      final msgHasMedia =
          (msg.imageUrl?.trim().isNotEmpty ?? false) ||
              (msg.videoUrl?.trim().isNotEmpty ?? false);
      final bothHaveMedia = baseHasMedia && msgHasMedia;

      final canGroup =
          sameSender && sameCaption && bothHaveMedia && sameCreatedAt;

      if (canGroup) {
        currentGroup.messages.add(msg);
      } else {
        currentGroup = MessageGroup(messages: [msg], firstIndex: i);
        groups.add(currentGroup);
      }
    }

    return groups;
  }
}
