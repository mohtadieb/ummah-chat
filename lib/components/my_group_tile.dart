import 'package:flutter/material.dart';
import 'my_card_tile.dart';

class MyGroupTile extends StatelessWidget {
  /// Display name of the group
  final String groupName;

  /// Optional avatar URL for the group
  final String? avatarUrl;

  /// Optional: last message preview text
  final String? lastMessagePreview;

  /// Optional: last message time label (e.g. "14:32", "Mon", "19/11")
  final String? lastMessageTimeLabel;

  /// Number of unread messages in this group
  final int unreadCount;

  /// Tap handler to open the group chat
  final VoidCallback? onTap;

  const MyGroupTile({
    super.key,
    required this.groupName,
    this.avatarUrl,
    this.lastMessagePreview,
    this.lastMessageTimeLabel,
    this.unreadCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MyCardTile(
      onTap: onTap,
      child: Row(
        children: [
          // 👥 Group avatar
          _buildGroupAvatar(colorScheme),

          const SizedBox(width: 12),

          // 📝 Group name + last message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (lastMessagePreview != null &&
                    lastMessagePreview!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    lastMessagePreview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.primary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 🕒 Time + unread badge
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lastMessageTimeLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    lastMessageTimeLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),

              if (unreadCount > 0)
                _UnreadBadge(
                  count: unreadCount,
                  colorScheme: colorScheme,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Simple avatar for group
  Widget _buildGroupAvatar(ColorScheme colorScheme) {
    const radius = 22.0;

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    final initial =
    groupName.trim().isNotEmpty ? groupName.trim()[0].toUpperCase() : 'G';

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;

  const _UnreadBadge({
    required this.count,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
