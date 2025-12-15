/*
FOLLOW BUTTON

This is a follow / unfollow button, depending on whose profile page we are
currently viewing.

--------------------------------------------------------------------------------

To use this widget, you need:

- a function (e.g. toggleFollow() when the button is pressed)
- isFollowing (e.g. false -> then we will show follow button instead of unfollow button)
*/

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

  // BUILD UI
  @override
  Widget build(BuildContext context) {

    // Padding outside
    return Padding(
      padding: const EdgeInsets.all(7),

      // Curve corners
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // rounded button corners

        // Material Button
        child: MaterialButton(

          // Padding inside
          padding: const EdgeInsets.all(7),
          onPressed: onPressed,

          // Button color changes based on follow state
          color:
          isFollowing
              ?
          Theme.of(context).colorScheme.primary // already following
              :
          Colors.blue, // not following yet

          // Text
          child: Text(
            isFollowing ? "Unfollow".tr() : "Follow".tr(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.tertiary, // text color
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}