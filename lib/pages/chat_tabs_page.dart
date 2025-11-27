import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'friends_page.dart';
import 'groups_page.dart';
import 'create_group_page.dart';
import 'communities_page.dart';
import 'search_page.dart'; // for "Find people" page
import '../services/database/database_provider.dart';

class ChatTabsPage extends StatefulWidget {
  const ChatTabsPage({super.key});

  @override
  State<ChatTabsPage> createState() => _ChatTabsPageState();
}

class _ChatTabsPageState extends State<ChatTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 3 tabs: Friends, Groups, Communities
    _tabController = TabController(length: 3, vsync: this);
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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "Chats",
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,

                  // remove default underline / divider
                  indicatorColor: Colors.transparent,
                  dividerColor: Colors.transparent,

                  // no splash / overlay highlight
                  splashFactory: NoSplash.splashFactory,
                  overlayColor:
                  MaterialStateProperty.all(Colors.transparent),

                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.primary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: "Friends"),
                    Tab(text: "Groups"),
                    Tab(text: "Communities"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: const [
          FriendsPage(),
          GroupsPage(),
          CommunitiesPage(), // content-only version
        ],
      ),

      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          final colorScheme = Theme.of(context).colorScheme;

          // Friends tab → Find people (open SearchPage as full screen)
          if (_tabController.index == 0) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchPage(),
                  ),
                );
              },
              icon: const Icon(Icons.person_search),
              label: const Text("Find people"),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          }

          // Groups tab → New group
          if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupPage(),
                  ),
                );
              },
              icon: const Icon(Icons.group_add),
              label: const Text("New group"),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          }

          // Communities tab → Add community
          if (_tabController.index == 2) {
            return FloatingActionButton.extended(
              onPressed: () async {
                await _showAddCommunityDialog(context);
              },
              icon: const Icon(Icons.group_add),
              label: const Text("Add community"),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Create community dialog (used by Communities FAB)
  // ---------------------------------------------------------------------------
  Future<void> _showAddCommunityDialog(BuildContext context) async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final countryController = TextEditingController();

    final colorScheme = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Create community',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              final country = countryController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter a name for your community.',
                    ),
                  ),
                );
                return;
              }

              // Create on backend
              await db.createCommunity(name, desc, country);

              // Refresh local list
              await db.getAllCommunities();

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
