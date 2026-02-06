// lib/components/my_user_tile.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../pages/profile_page.dart';
import 'my_card_tile.dart';

class MyUserTile extends StatelessWidget {
  final UserProfile user;
  final String? customTitle;

  /// ✅ NEW: optional custom tap handler
  /// If null, defaults to opening ProfilePage(userId: user.id)
  final VoidCallback? onTap;

  const MyUserTile({
    super.key,
    required this.user,
    this.customTitle,
    this.onTap,
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

    void goToProfile() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePage(userId: user.id),
        ),
      );
    }

    return MyCardTile(
      // ✅ if provided, use custom onTap, otherwise default to goToProfile
      onTap: onTap ?? goToProfile,
      child: Row(
        children: [
          // 👤 Avatar — tap handled by MyCardTile.onTap
          user.profilePhotoUrl.isNotEmpty
              ? CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(user.profilePhotoUrl),
          )
              : CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              _getInitials(),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 📝 Name + username
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
                Text(
                  '@${user.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
