import 'package:flutter/material.dart';

/*

SETTINGS LIST TILE

A reusable tile for the settings page.

Features:
- Full width tile
- Rounded corners
- Reduced padding
- Title uses theme colors
- Flexible action widget (e.g., switch, button)

- (Updated)
- Clean, modern, borderless design
- Subtle surface tint instead of borders or dividers
- Leading icon sits inside a soft container for visual balance
- Uses InkWell for modern touch feedback
- Optimized spacing & typography for settings-style UX
- Whole tile is tappable (optional)

*/

class MySettingsTile extends StatelessWidget {
  final String title;

  /// Callback when the tile (or trailing button) is tapped
  /// Use this for navigation or opening a new page
  final VoidCallback? onPressed;

  /// Trailing widget (e.g. Switch, Icon)
  /// NOTE: Kept flexible on purpose
  final Widget? trailing;

  /// Optional leading icon to visually distinguish setting types
  final IconData? leadingIcon;

  /// Whether the whole tile should be tappable
  /// Useful to disable for Switch-only rows
  final bool enabled;

  const MySettingsTile({
    super.key,
    required this.title,
    this.onPressed,
    this.trailing,
    this.leadingIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      // Vertical spacing between tiles (instead of dividers)
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),

          // ✅ Whole tile is now tappable
          onTap: enabled ? onPressed : null,

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                // Optional leading icon with soft container
                if (leadingIcon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      leadingIcon,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (trailing != null) ...[
                  const SizedBox(width: 8),

                  // Trailing control (Switch, Arrow, etc.)
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
