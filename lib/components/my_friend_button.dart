import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MyFriendButton extends StatelessWidget {
  final String friendStatus; // none, pending_sent, pending_received, accepted, blocked
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onAcceptRequest;
  final VoidCallback? onDeclineRequest;

  // 👇 NEW: used when already friends
  final VoidCallback? onUnfriend;

  const MyFriendButton({
    super.key,
    required this.friendStatus,
    required this.onAddFriend,
    required this.onCancelRequest,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    this.onUnfriend, // 👈 optional
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Special view for requests received → Accept + Decline
    if (friendStatus == 'pending_received') {
      return SizedBox(
        height: 36,
        child: Row(
          children: [
            // ACCEPT
            Expanded(
              child: TextButton(
                onPressed: onAcceptRequest,
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                // ✅ Fix: make long translations fit inside the button
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    'Accept'.tr(),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // DECLINE
            Expanded(
              child: TextButton(
                onPressed: onDeclineRequest,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                // ✅ Fix: make long translations fit inside the button
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    'Decline'.tr(),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Everything else → single button
    Color bg;
    Color fg;
    BorderSide? side;
    VoidCallback? onTap;

    switch (friendStatus) {
      case 'pending_sent':
        bg = Colors.transparent;
        fg = colorScheme.primary;
        side = BorderSide(color: colorScheme.primary);
        onTap = onCancelRequest;
        break;

      case 'accepted':
        bg = colorScheme.tertiary;
        fg = colorScheme.primary;
        onTap = onUnfriend; // 👈 now clickable
        break;

      case 'blocked':
        bg = Colors.grey.shade400;
        fg = Colors.white;
        onTap = null; // disabled
        break;

      case 'none':
      default:
        bg = colorScheme.secondary;
        fg = colorScheme.primary;
        onTap = onAddFriend;
    }

    // Determine button text
    String label;
    switch (friendStatus) {
      case 'pending_sent':
        label = 'Cancel request';
        break;
      case 'accepted':
        label = 'Unfriend'; // 👈 changed
        break;
      case 'blocked':
        label = 'Blocked';
        break;
      case 'none':
      default:
        label = 'Add friend';
    }

    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        // ✅ Fix: this is the main one — "Vriendschap beëindigen" will now scale down to fit
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            label.tr(),
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
