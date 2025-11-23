import 'package:flutter/material.dart';

/*

SETTINGS LIST TILE

A reusable tile for the settings page.

Features:
- Full width tile
- Rounded corners
- Reduced padding
- Title uses theme primary color
- Flexible action widget (e.g., switch, button)

- (Updated)
- Uses surface color + subtle border for a more "card-like" professional look
- Optional leading icon for consistent settings UX

*/

class MySettingsTile extends StatelessWidget {
  final String title;

  /// Trailing widget (e.g. Switch, IconButton)
  /// NOTE: Kept the original name `onTap` for backwards compatibility.
  final Widget onTap;

  /// Optional leading icon to visually distinguish setting types.
  final IconData? leadingIcon;

  const MySettingsTile({
    super.key,
    required this.title,
    required this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        // Use surface color for a clean, modern card look
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          // Subtle border to separate from background
          color: colorScheme.secondary.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        // Slightly tighter, but balanced padding
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            // Optional leading icon
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
            ],

            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 12),

            // Trailing control (Switch, Arrow, etc.)
            onTap,
          ],
        ),
      ),
    );
  }
}
