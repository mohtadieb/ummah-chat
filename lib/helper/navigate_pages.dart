// Navigation helper functions
import 'package:flutter/material.dart';
import 'package:ummah_chat/layouts/main_layout.dart';
import '../pages/home_page.dart';
import '../pages/account_settings_page.dart';
import '../pages/blocked_users_page.dart';
import '../pages/post_page.dart';
import '../pages/profile_page.dart';
import '../models/post.dart';

/// Navigate to a user's profile page
void goUserPage(BuildContext context, String userId) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
  );
}

/// Navigate to a post page
Future<void> goPostPage(
    BuildContext context,
    Post post, {
      bool scrollToComments = false,
      bool highlightPost = false,
      bool highlightComments = false,
    }) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PostPage(
        post: post,
        scrollToComments: scrollToComments,
        highlightPost: highlightPost,
        highlightComments: highlightComments,
      ),
    ),
  );
}

/// Navigate to blocked users page
void goBlockedUsersPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const BlockedUsersPage()),
  );
}

/// Navigate to account settings page
void goAccountSettingsPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
  );
}

/// Navigate to home page and remove all previous routes (good for logout)
void goHomePage(BuildContext context) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
  );
}

void goMainLayout(BuildContext context) {
  Navigator.pushNamedAndRemoveUntil(
    context,
    '/',
        (route) => false, // removes everything before it
  );
}
