import 'package:flutter/material.dart';
import 'my_card_tile.dart';

class MyCommunityTile extends StatelessWidget {
  final String name;
  final String? description;
  final String? country;

  /// Tap handler → open community posts page
  final VoidCallback onTap;

  const MyCommunityTile({
    super.key,
    required this.name,
    this.description,
    this.country,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MyCardTile(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 👥 Avatar / icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.secondary.withValues(alpha: 0.5),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.groups_2,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),

          // 📄 Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),

                // Description (if present)
                if ((description ?? '').trim().isNotEmpty)
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),

                // Country chip (optional)
                if ((country ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: colorScheme.secondary.withValues(alpha: 0.4),
                    ),
                    child: Text(
                      country!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 4),

          // ➜ small arrow to indicate navigation
          Icon(
            Icons.chevron_right,
            color: colorScheme.primary.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}
