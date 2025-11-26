// lib/components/selectable_bubble.dart
import 'package:flutter/material.dart';

/// Wraps a chat bubble to provide:
/// - selection highlight
/// - border
/// - checkmark badge
/// - tap + long press callbacks
class MySelectableBubble extends StatelessWidget {
  final bool isSelected;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MySelectableBubble({
    super.key,
    required this.isSelected,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: isSelected ? const EdgeInsets.all(4) : EdgeInsets.zero,
        decoration: isSelected
            ? BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.primary,
            width: 1.6,
          ),
        )
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (isSelected)
              Positioned(
                top: -8,
                right: -8,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: colorScheme.primary,
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
