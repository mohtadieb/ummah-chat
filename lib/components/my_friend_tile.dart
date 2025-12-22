import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import 'my_card_tile.dart';

class MyFriendTile extends StatelessWidget {
  final UserProfile user;
  final String? customTitle;

  /// 👉 Tap on the content area (everything except avatar)
  final VoidCallback onTap;

  /// 👉 Tap on avatar only (optional)
  final VoidCallback? onAvatarTap;

  /// Whether the friend is currently online
  final bool isOnline;

  /// Number of unread messages from this friend
  final int unreadCount;

  /// Optional: last message preview text
  final String? lastMessagePreview;

  /// Optional: last message time label (e.g. "14:32", "Mon", "19/11")
  final String? lastMessageTimeLabel;

  const MyFriendTile({
    super.key,
    required this.user,
    this.customTitle,
    required this.onTap,
    this.onAvatarTap,
    this.isOnline = false,
    this.unreadCount = 0,
    this.lastMessagePreview,
    this.lastMessageTimeLabel,
  });

  String _getInitials() {
    if (user.name.trim().isEmpty) return '';
    final parts = user.name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MyCardTile(
      // ✅ Important: keep this null so only our inner InkWells handle taps
      onTap: null,
      child: Row(
        children: [
          // 👤 Avatar + online dot (tap -> profile)
          InkWell(
            onTap: onAvatarTap,
            borderRadius: BorderRadius.circular(999),
            splashColor: colorScheme.primary.withValues(alpha: 0.10),
            highlightColor: colorScheme.primary.withValues(alpha: 0.05),
            child: Stack(
              children: [
                user.profilePhotoUrl.isNotEmpty
                    ? CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(user.profilePhotoUrl),
                )
                    : CircleAvatar(
                  radius: 22,
                  backgroundColor:
                  colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF12B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ✅ Everything except avatar is tappable -> onTap (chat or profile depending on page)
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: colorScheme.primary.withValues(alpha: 0.10),
              highlightColor: colorScheme.primary.withValues(alpha: 0.05),
              child: Padding(
                // 👇 makes the tap target comfy without changing layout visually
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    // 📝 Name + username + last message
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customTitle ?? user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),

                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@${user.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (isOnline) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF12B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Online'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFF12B981),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          if (lastMessagePreview != null &&
                              lastMessagePreview!.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              lastMessagePreview!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // 🕒 Time + unread badge (also part of "rest tap")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (lastMessageTimeLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              lastMessageTimeLabel!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
