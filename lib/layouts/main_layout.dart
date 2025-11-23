import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ummah_chat/pages/groups_page.dart';

// Pages
import '../pages/community/communities_page.dart';
import '../pages/friends_page.dart';
import '../pages/home_page.dart';
import '../pages/notification_page.dart';
import '../pages/profile_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';

// Services
import '../services/auth/auth_service.dart';
import '../services/notification_service.dart';

// Providers (not used here directly, but ok to keep if used elsewhere)
import 'package:provider/provider.dart';
import '../services/database/database_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Which bottom nav item is active
  int _selectedIndex = 0;

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
      const HomePage(),
      CommunitiesPage(),
      const SearchPage(),
      // 👇 Pass a callback into FriendsPage so it can switch to Search tab
      FriendsPage(
        onGoToSearch: () {
          _onItemTapped(2); // index 2 = Search
        },
      ),
      const GroupsPage(),
      ProfilePage(userId: _auth.getCurrentUserId()),
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

                  // Small red dot when there are unread notifications
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

      // Keep all pages alive and just switch index
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
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_2), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
