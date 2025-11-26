import 'package:flutter/material.dart';
import 'friends_page.dart';
import 'groups_page.dart';

class ChatTabsPage extends StatefulWidget {
  final VoidCallback onGoToSearch;

  const ChatTabsPage({
    super.key,
    required this.onGoToSearch,
  });

  @override
  State<ChatTabsPage> createState() => _ChatTabsPageState();
}

class _ChatTabsPageState extends State<ChatTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Chats",
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: colorScheme.onPrimary,
                unselectedLabelColor: colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: "Friends"),
                  Tab(text: "Groups"),
                ],
              ),
            ),
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          FriendsPage(onGoToSearch: widget.onGoToSearch),
          const GroupsPage(),
        ],
      ),

      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          // FAB for Friends page
          if (_tabController.index == 0) {
            return FloatingActionButton.extended(
              onPressed: widget.onGoToSearch,
              icon: const Icon(Icons.person_search),
              label: const Text("Find people"),
              backgroundColor: const Color(0xFF0D6746),
              foregroundColor: colorScheme.onPrimary,
            );
          }

          // FAB for Groups page
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/create-group');
            },
            icon: const Icon(Icons.group_add),
            label: const Text("New group"),
            backgroundColor: const Color(0xFF0D6746),
            foregroundColor: colorScheme.onPrimary,
          );
        },
      ),
    );
  }
}
