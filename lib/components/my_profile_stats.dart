/*

PROFILE STATS

This will be displayed on the profile page

--------------------------------------------------------------------------------

Number of

- posts
- followers
- following

 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MyProfileStats extends StatelessWidget {
  final int postCount;
  final int followerCount;
  final int followingCount;
  final void Function()? onTap;

  const MyProfileStats({
    super.key,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // style for count
    var textStyleForCount = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.inversePrimary,
    );

    // style for text
    var textStyleForText = TextStyle(
      fontSize: 14,
      color: Theme.of(context).colorScheme.primary,
    );

    // Proper pluralization
    final postsLabel =
    postCount == 1 ? "Post".tr() : "Posts".tr();
    final followersLabel =
    followerCount == 1 ? "Follower".tr() : "Followers".tr();
    final followingLabel =
    followingCount == 1 ? "Following".tr() : "Following".tr();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Posts
            SizedBox(
              width: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(postCount.toString(), style: textStyleForCount),
                  const SizedBox(height: 3),
                  Text(postsLabel, style: textStyleForText),
                ],
              ),
            ),

            // Followers
            SizedBox(
              width: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(followerCount.toString(), style: textStyleForCount),
                  const SizedBox(height: 3),
                  Text(followersLabel, style: textStyleForText),
                ],
              ),
            ),

            // Following
            SizedBox(
              width: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(followingCount.toString(), style: textStyleForCount),
                  const SizedBox(height: 3),
                  Text(followingLabel, style: textStyleForText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
