import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MyProfileStats extends StatelessWidget {
  final int postCount;
  final int followerCount;
  final int followingCount;

  /// Old fallback callback (kept for compatibility)
  final VoidCallback? onTap;

  /// New individual callbacks
  final VoidCallback? onPostsTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const MyProfileStats({
    super.key,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    this.onTap,
    this.onPostsTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _ProfileStatTile(
            value: postCount.toString(),
            label: 'Posts'.tr(),
            onTap: onPostsTap ?? onTap,
          ),
        ),
        Expanded(
          child: _ProfileStatTile(
            value: followerCount.toString(),
            label: 'Followers'.tr(),
            onTap: onFollowersTap ?? onTap,
          ),
        ),
        Expanded(
          child: _ProfileStatTile(
            value: followingCount.toString(),
            label: 'Following'.tr(),
            onTap: onFollowingTap ?? onTap,
          ),
        ),
      ],
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _ProfileStatTile({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: content,
    );
  }
}