// Navigation helper functions
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/layouts/main_layout.dart';
import '../pages/home_page.dart';
import '../pages/account_settings_page.dart';
import '../pages/blocked_users_page.dart';
import '../pages/post_page.dart';
import '../pages/profile_page.dart';
import '../models/post.dart';
import '../services/navigation/bottom_nav_provider.dart';

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
    }) async {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => PostPage(
        post: post,
        scrollToComments: scrollToComments,
        highlightPost: highlightPost,
        highlightComments: highlightComments,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // ✅ One tween, used forward and reverse:
        // - push:  value 0→1 → moves from bottom (0,1) to center (0,0)
        // - pop:   value 1→0 → moves from center (0,0) to bottom (0,1)
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        );

        return SlideTransition(
          position: animation.drive(offsetTween),
          child: child,
        );
      },
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

void goToOwnProfileTab(BuildContext context) {
  // Pop back to the root of the whole app (MainLayout / BottomNav host)
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

  // Switch to your Profile tab
  final bottomNav = Provider.of<BottomNavProvider>(context, listen: false);
  bottomNav.setIndex(4);
}
