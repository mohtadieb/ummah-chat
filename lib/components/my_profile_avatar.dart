import 'package:flutter/material.dart';

class MyProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final bool isOnline;
  final bool isMahram;
  final VoidCallback? onTap;
  final IconData fallbackIcon;
  final Widget? fallbackChild;

  const MyProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.isOnline = false,
    this.isMahram = false,
    this.onTap,
    this.fallbackIcon = Icons.person,
    this.fallbackChild,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.secondary,
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty
          ? Icon(
        fallbackIcon,
        color: colorScheme.primary,
        size: radius,
      )
          : null,
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,

          // ✅ online dot
          if (isOnline)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: radius * 0.36,
                height: radius * 0.36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 1.4,
                  ),
                ),
              ),
            ),

          // ✅ mahram badge
          if (isMahram)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: radius * 0.72,
                height: radius * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F8254),
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: radius * 0.42,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}