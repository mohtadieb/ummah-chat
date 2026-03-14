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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isTwoButtonReceived = friendStatus == 'pending_received' ||
        friendStatus == 'pending_mahram_received' ||
        _isInquiryReceived;

    if (isTwoButtonReceived) {
      return SizedBox(
        height: 40,
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Color bg;
    Color fg;
    BorderSide? side;
    VoidCallback? onTap;

    switch (friendStatus) {
      case 'pending_sent':
      case 'pending_mahram_sent':
      case 'inquiry_pending_sent':
        bg = Colors.transparent;
        fg = colorScheme.primary;
        side = BorderSide(color: colorScheme.primary);
        onTap = onCancelRequest;
        break;

      case 'inquiry_cancel_inquiry':
      case 'accepted':
      case 'mahram':
        bg = colorScheme.primary.withValues(alpha: 0.08);
        fg = colorScheme.primary;
        onTap = friendStatus == 'accepted'
            ? onUnfriend
            : friendStatus == 'mahram'
            ? onDeleteMahram
            : onCancelRequest;
        break;

      case 'blocked':
        bg = Colors.grey.shade400;
        fg = Colors.white;
        onTap = null;
        break;

      case 'request':
      case 'none':
      default:
        bg = colorScheme.primary;
        fg = colorScheme.onPrimary;
        onTap = friendStatus == 'request' ? onOpenRequestSheet : onAddFriend;
        break;
    }

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
      height: 40,
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
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

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
            ? SizedBox(
          key: const ValueKey('busy'),
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
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