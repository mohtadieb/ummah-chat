// lib/components/my_user_tile.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../pages/profile_page.dart';
import 'my_card_tile.dart';

class MyUserTile extends StatelessWidget {
  final UserProfile user;
  final String? customTitle;

  /// optional custom tap handler
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
    final displayName = (customTitle ?? user.name).trim();
    final isOnline = user.isOnline;

    void goToProfile() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePage(userId: user.id),
        ),
      );
    }

    return MyCardTile(
      onTap: onTap ?? goToProfile,

      // wider tile + less gap between tiles
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      borderRadius: const BorderRadius.all(Radius.circular(22)),

      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              user.profilePhotoUrl.isNotEmpty
                  ? CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(user.profilePhotoUrl),
              )
                  : CircleAvatar(
                radius: 24,
                backgroundColor:
                colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  _getInitials(),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF22C55E),
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary.withValues(alpha: 0.74),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.primary.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}