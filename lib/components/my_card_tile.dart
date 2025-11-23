import 'package:flutter/material.dart';

/// Generic rounded card used across the app for list items / tiles.
///
/// Features:
/// - Surface background
/// - Subtle border using secondary color
/// - Optional InkWell ripple with onTap
/// - Configurable padding, margin and borderRadius
class MyCardTile extends StatelessWidget {
  /// The content of the tile (usually a Row / Column).
  final Widget child;

  /// Optional tap handler for the entire tile.
  final VoidCallback? onTap;

  /// Inner padding of the card around [child].
  final EdgeInsetsGeometry padding;

  /// Outer margin around the whole card.
  final EdgeInsetsGeometry margin;

  /// Border radius of the card.
  final BorderRadius borderRadius;

  const MyCardTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final card = Ink(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return Padding(
        padding: margin,
        child: card,
      );
    }

    return Padding(
      padding: margin,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: card,
      ),
    );
  }
}
