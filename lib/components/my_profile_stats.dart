/*

PROFILE STATS

This will be displayed on the profile page

--------------------------------------------------------------------------------

Number of

- posts
- followers
- following

 */

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
                  Text("Posts", style: textStyleForText),
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
                  Text("Followers", style: textStyleForText),
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
                  Text("Following", style: textStyleForText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}