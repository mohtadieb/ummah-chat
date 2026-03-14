import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MyFollowButton extends StatelessWidget {
  final void Function()? onPressed;
  final bool isFollowing;

  const MyFollowButton({
    super.key,
    required this.onPressed,
    required this.isFollowing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = isFollowing ? cs.primary.withValues(alpha: 0.08) : cs.primary;
    final fg = isFollowing ? cs.primary : cs.onPrimary;
    final border = isFollowing ? BorderSide(color: cs.primary.withValues(alpha: 0.20)) : null;

    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          isFollowing ? "Unfollow".tr() : "Follow".tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}