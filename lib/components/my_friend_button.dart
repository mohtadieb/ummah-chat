import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MyFriendButton extends StatelessWidget {
  final String friendStatus;

  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onAcceptRequest;
  final VoidCallback? onDeclineRequest;

  final VoidCallback? onUnfriend;
  final VoidCallback? onOpenRequestSheet;
  final VoidCallback? onDeleteMahram;

  /// ✅ NEW: disables all taps + shows a small spinner
  final bool isBusy;

  const MyFriendButton({
    super.key,
    required this.friendStatus,
    required this.onAddFriend,
    required this.onCancelRequest,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    this.onUnfriend,
    this.onOpenRequestSheet,
    this.onDeleteMahram,
    this.isBusy = false,
  });

  bool get _isInquiryReceived =>
      friendStatus == 'inquiry_pending_received_woman' ||
          friendStatus == 'inquiry_pending_received_mahram' ||
          friendStatus == 'inquiry_pending_received_man';

  bool get _isInquirySentOrCancelable =>
      friendStatus == 'inquiry_pending_sent' ||
          friendStatus == 'inquiry_cancel_inquiry';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ✅ Treat inquiry "received" role-specific statuses same as pending_received UI (Accept + Decline)
    final isTwoButtonReceived = friendStatus == 'pending_received' ||
        friendStatus == 'pending_mahram_received' ||
        _isInquiryReceived;

    // ---- TWO BUTTON ROW (Accept / Decline) ----
    if (isTwoButtonReceived) {
      return SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: isBusy ? null : onAcceptRequest,
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _ButtonChild(
                  isBusy: isBusy,
                  label: 'Accept'.tr(),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                onPressed: isBusy ? null : onDeclineRequest,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _ButtonChild(
                  isBusy: isBusy,
                  label: 'Decline'.tr(),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ---- SINGLE BUTTON ----
    Color bg;
    Color fg;
    BorderSide? side;
    VoidCallback? onTap;

    switch (friendStatus) {
    // ✅ Friend & mahram pending (cancel)
      case 'pending_sent':
      case 'pending_mahram_sent':
        bg = Colors.transparent;
        fg = colorScheme.primary;
        side = BorderSide(color: colorScheme.primary);
        onTap = onCancelRequest;
        break;

    // ✅ Inquiry states
      case 'inquiry_pending_sent':
        bg = Colors.transparent;
        fg = colorScheme.primary;
        side = BorderSide(color: colorScheme.primary);
        onTap = onCancelRequest;
        break;

      case 'inquiry_cancel_inquiry':
        bg = colorScheme.tertiary;
        fg = colorScheme.primary;
        onTap = onCancelRequest; // end inquiry
        break;

      case 'accepted':
        bg = colorScheme.tertiary;
        fg = colorScheme.primary;
        onTap = onUnfriend;
        break;

      case 'mahram':
        bg = colorScheme.tertiary;
        fg = colorScheme.primary;
        onTap = onDeleteMahram;
        break;

      case 'blocked':
        bg = Colors.grey.shade400;
        fg = Colors.white;
        onTap = null;
        break;

      case 'request':
        bg = colorScheme.secondary;
        fg = colorScheme.primary;
        onTap = onOpenRequestSheet;
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
      case 'pending_mahram_sent':
        label = 'cancel_request';
        break;

      case 'inquiry_pending_sent':
        label = 'cancel_inquiry';
        break;

      case 'inquiry_cancel_inquiry':
        label = 'end_inquiry';
        break;

      case 'accepted':
        label = 'Unfriend';
        break;

      case 'mahram':
        label = 'Mahram';
        break;

      case 'request':
        label = 'Request';
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
        onPressed: isBusy ? null : onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _ButtonChild(
          isBusy: isBusy,
          label: label.tr(),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Small helper so we keep your FittedBox behavior, but can show a spinner when busy.
class _ButtonChild extends StatelessWidget {
  final bool isBusy;
  final String label;
  final TextStyle textStyle;

  const _ButtonChild({
    required this.isBusy,
    required this.label,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: isBusy
            ? const SizedBox(
          key: ValueKey('busy'),
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(
          key: const ValueKey('label'),
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      ),
    );
  }
}
