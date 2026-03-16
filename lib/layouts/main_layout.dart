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
import '../services/navigation/bottom_nav_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final _auth = AuthService();
  final NotificationService _notificationService = NotificationService();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    final currentUserId = _auth.getCurrentUserId();

    _pages = [
      const HomePage(),
      const ChatTabsPage(),
      SelectStoriesPage(),
      const DuaWallPage(),
      ProfilePage(userId: currentUserId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomNav = Provider.of<BottomNavProvider>(context);
    final selectedIndex = bottomNav.currentIndex;
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = colorScheme.surface;

    final navBg = isDark
        ? const Color(0xFF12201A)
        : const Color(0xFFFFFFFF);

    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : colorScheme.outline.withValues(alpha: 0.10);

    final selectedItemColor = colorScheme.primary;
    final unselectedItemColor =
    colorScheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      backgroundColor: scaffoldBg,

      appBar: AppBar(
        toolbarHeight: 54,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBg,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: null,
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.unreadCountStream(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;

              return _TopActionButton(
                icon: unread > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                hasBadge: unread > 0,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationPage(),
                    ),
                  );
                },
              );
            },
          ),
          _TopActionButton(
            icon: Icons.settings_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),

      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: navBorderColor),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              bottomNav.setIndex(index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: navBg,
            elevation: 0,
            selectedItemColor: selectedItemColor,
            unselectedItemColor: unselectedItemColor,
            selectedFontSize: 11.5,
            unselectedFontSize: 11.5,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            items: [
              BottomNavigationBarItem(
                icon: _NavIcon(
                  icon: Icons.home_rounded,
                  selected: selectedIndex == 0,
                ),
                label: 'Home'.tr(),
              ),
              BottomNavigationBarItem(
                icon: _NavIcon(
                  icon: Icons.groups_rounded,
                  selected: selectedIndex == 1,
                ),
                label: 'Social'.tr(),
              ),
              BottomNavigationBarItem(
                icon: _NavIcon(
                  icon: Icons.menu_book_rounded,
                  selected: selectedIndex == 2,
                ),
                label: 'Stories'.tr(),
              ),
              BottomNavigationBarItem(
                icon: _NavIcon(
                  icon: Icons.view_list_rounded,
                  selected: selectedIndex == 3,
                ),
                label: 'Dua Wall'.tr(),
              ),
              BottomNavigationBarItem(
                icon: _NavIcon(
                  icon: Icons.person_rounded,
                  selected: selectedIndex == 4,
                ),
                label: 'Profile'.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasBadge;

  const _TopActionButton({
    required this.icon,
    required this.onTap,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : colorScheme.primary.withValues(alpha: 0.06),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  icon,
                  size: 21,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (hasBadge)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _NavIcon({
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        size: 22,
      ),
    );
  }
}