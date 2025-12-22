import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Pages
import 'package:ummah_chat/pages/chat_tabs_page.dart';
import 'package:ummah_chat/pages/dua_wall_page.dart';
import '../pages/home_page.dart';
import '../pages/notification_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';

// Services
import '../services/auth/auth_service.dart';
import '../services/notifications/notification_service.dart';

// Providers
import 'package:provider/provider.dart';
import '../pages/select_stories_page.dart';
import '../services/navigation/bottom_nav_provider.dart'; // 👈 ADD THIS

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // index of the Chats tab in bottom navigation (still 1)
  static const int _chatsIndex = 1;
  static const int _profileTabIndex = 4;

  // Auth service to get current user id for ProfilePage
  final _auth = AuthService();

  // 👉 Singleton instance for in-app notifications
  final NotificationService _notificationService = NotificationService();

  // All main pages (for IndexedStack)
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Make sure user is loaded; we reuse this id below for ProfilePage
    final currentUserId = _auth.getCurrentUserId();

    // Order must match BottomNavigationBar items
    _pages = [
      const HomePage(), // 0
      const ChatTabsPage(), // 1
      SelectStoriesPage(), // 2
      const DuaWallPage(), // 3
      ProfilePage(userId: currentUserId), // 4
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 👇 Listen to our global bottom nav provider
    final bottomNav = Provider.of<BottomNavProvider>(context);
    final selectedIndex = bottomNav.currentIndex;

    // ✅ Previously we only showed actions on Profile tab.
    // ✅ Now: show Notification + Settings actions ALWAYS.
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        foregroundColor: colorScheme.primary,
        toolbarHeight: kToolbarHeight / 1.3,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,

        // 🔥 Show actions on ALL tabs
        actions: [
          // 🔔 Notification bell with unread badge
          StreamBuilder<int>(
            stream: _notificationService.unreadCountStream(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      unread > 0
                          ? Icons.notifications_active
                          : Icons.notifications_none_rounded,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationPage(),
                        ),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // ⚙️ Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),

          const SizedBox(width: 7),
        ],
      ),

      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          bottomNav.setIndex(index);
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'Home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.groups),
            label: 'Social'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_rounded),
            label: 'Stories'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.view_list),
            label: 'Dua Wall'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'Profile'.tr(),
          ),
        ],
      ),
    );
  }
}
