import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Pages
import 'package:ummah_chat/pages/chat_tabs_page.dart';
import '../pages/home_page.dart';
import '../pages/notification_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';

// Services
import '../services/auth/auth_service.dart';
import '../services/notification_service.dart';

// Providers (not used here directly, but ok to keep if used elsewhere)
import 'package:provider/provider.dart';
import '../services/database/database_provider.dart';
import '../stories/select_stories_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Which bottom nav item is active
  int _selectedIndex = 0;

  // index of the Chats tab in bottom navigation (still 1)
  static const int _chatsIndex = 1;

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
    _auth.getCurrentUserId();

    // Order must match BottomNavigationBar items
    _pages = [
      const HomePage(), // 0
      const ChatTabsPage(), // 1
      SelectStoriesPage(), // 2 👈 New Story selection hub
      ProfilePage(userId: _auth.getCurrentUserId()), // 3
    ];
  }

  /// Handle bottom navigation taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        foregroundColor: colorScheme.primary,
        toolbarHeight: kToolbarHeight / 1.3,

        // 🚫 Prevent grey-out on scroll
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,

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
        index: _selectedIndex,
        children: _pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Social'),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Stories', // 👈 Now opens SelectStoriesPage
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
